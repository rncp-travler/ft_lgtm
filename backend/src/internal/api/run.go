// Package api exposes the HTTP endpoints and runs the playground pipeline:
//
//	HTTP request -> compile (rustc) -> execute (wasmtime) -> IPFS upload -> response
//
// Each stage opens its own child span under the otelhttp server span.
package api

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"time"

	"ft_lgtm/backend/src/internal/compiler"
	"ft_lgtm/backend/src/internal/ipfs"
	"ft_lgtm/backend/src/internal/sandbox"
	"ft_lgtm/backend/src/internal/telemetry"

	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/trace"
)

// Status values, also used as the "status" metric attribute.
const (
	StatusSuccess       = "success"
	StatusCompileError  = "compile_error"
	StatusRuntimeError  = "runtime_error"
	StatusTimeout       = "timeout"
	StatusInternalError = "internal_error"
)

type RunRequest struct {
	Code string `json:"code"`
}

type RunResponse struct {
	Status     string `json:"status"`
	Stdout     string `json:"stdout"`
	Stderr     string `json:"stderr"`
	ExitCode   int32  `json:"exitCode"`
	DurationMs int64  `json:"durationMs"`
	CID        string `json:"cid,omitempty"`
	ShareURL   string `json:"shareUrl,omitempty"`
	TraceID    string `json:"traceId,omitempty"`
}

// sharedResult is what gets pinned to IPFS behind the share link.
type sharedResult struct {
	Language  string    `json:"language"`
	Code      string    `json:"code"`
	Status    string    `json:"status"`
	Stdout    string    `json:"stdout"`
	Stderr    string    `json:"stderr"`
	ExitCode  int32     `json:"exitCode"`
	CreatedAt time.Time `json:"createdAt"`
}

type Server struct {
	Compiler       compiler.Rust
	CompileTimeout time.Duration
	Runtime        *sandbox.Runtime
	IPFS           *ipfs.Client
	Metrics        *telemetry.Metrics
	MaxCodeBytes   int64
}

func (s *Server) Routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("POST /api/run", s.handleRun)
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
	return mux
}

func (s *Server) handleRun(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	start := time.Now()

	var req RunRequest
	r.Body = http.MaxBytesReader(w, r.Body, s.MaxCodeBytes)
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Code == "" {
		http.Error(w, `{"error":"body must be {\"code\": \"...\"} and within size limit"}`, http.StatusBadRequest)
		return
	}

	resp := s.run(ctx, req.Code)

	// The caller hung up (the UI's Cancel button, a closed tab). There is
	// nobody left to answer, and counting it as a failure would skew the
	// success rate on the metrics dashboard.
	if ctx.Err() != nil {
		slog.InfoContext(ctx, "run abandoned by client", "duration_ms", time.Since(start).Milliseconds())
		return
	}

	resp.DurationMs = time.Since(start).Milliseconds()
	resp.TraceID = trace.SpanContextFromContext(ctx).TraceID().String()

	s.Metrics.Record(ctx, resp.Status, time.Since(start).Seconds())
	trace.SpanFromContext(ctx).SetAttributes(attribute.String("playground.status", resp.Status))
	slog.InfoContext(ctx, "run finished",
		"status", resp.Status, "exit_code", resp.ExitCode,
		"duration_ms", resp.DurationMs, "cid", resp.CID)

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(resp)
}

func (s *Server) run(ctx context.Context, code string) RunResponse {
	var resp RunResponse

	compileCtx, cancel := context.WithTimeout(ctx, s.CompileTimeout)
	wasm, err := s.Compiler.Compile(compileCtx, code)
	cancel()

	if err != nil {
		var ce *compiler.ErrCompile
		switch {
		case errors.As(err, &ce):
			resp.Status, resp.Stderr, resp.ExitCode = StatusCompileError, ce.Output, 1
		case errors.Is(err, context.Canceled):
			return resp
		case errors.Is(err, context.DeadlineExceeded):
			resp.Status, resp.Stderr, resp.ExitCode = StatusTimeout, "compilation timed out", 1
		default:
			slog.ErrorContext(ctx, "compile failed", "error", err)
			resp.Status, resp.Stderr, resp.ExitCode = StatusInternalError, err.Error(), 1
			return resp
		}
	} else {
		res, err := s.Runtime.Run(ctx, wasm)
		resp.Stdout, resp.Stderr, resp.ExitCode = res.Stdout, res.Stderr, res.ExitCode
		var re *sandbox.RuntimeError
		switch {
		case err == nil:
			resp.Status = StatusSuccess
		case errors.Is(err, sandbox.ErrTimeout), errors.Is(err, context.DeadlineExceeded):
			resp.Status = StatusTimeout
		case errors.Is(err, context.Canceled):
			return resp
		case errors.As(err, &re):
			resp.Status = StatusRuntimeError
			if resp.Stderr == "" {
				resp.Stderr = re.Msg
			}
		default:
			slog.ErrorContext(ctx, "execute failed", "error", err)
			resp.Status = StatusInternalError
			return resp
		}
	}

	// Share even failed runs so people can link to the error. Upload is best-effort.
	payload, _ := json.Marshal(sharedResult{
		Language: "rust", Code: code, Status: resp.Status,
		Stdout: resp.Stdout, Stderr: resp.Stderr, ExitCode: resp.ExitCode,
		CreatedAt: time.Now().UTC(),
	})
	if cid, err := s.IPFS.Upload(ctx, "result.json", payload); err != nil {
		slog.WarnContext(ctx, "ipfs upload failed", "error", err)
	} else {
		resp.CID, resp.ShareURL = cid, s.IPFS.ShareURL(cid)
	}
	return resp
}
