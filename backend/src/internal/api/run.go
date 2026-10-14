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

// resultMeta is result.json in the shared directory. It has no timestamp on
// purpose: the same code with the same output must give the same CID.
type resultMeta struct {
	Language string `json:"language"`
	Target   string `json:"target"`
	Status   string `json:"status"`
	ExitCode int32  `json:"exitCode"`
}

// Publisher pins a run's files and builds the link to them; *ipfs.Client in
// production, a test double in the unit tests.
type Publisher interface {
	UploadDir(ctx context.Context, files []ipfs.File) (cid string, err error)
	ShareURL(cid string) string
}

type Server struct {
	Compiler       compiler.Rust
	CompileTimeout time.Duration
	Runtime        *sandbox.Runtime
	IPFS           Publisher
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

	// Share even failed runs so people can link to the error.
	s.share(ctx, code, &resp)
	return resp
}

// share pins the run as a directory and sets resp's CID and link. It is
// best-effort: a failed upload is logged and the run result still goes out.
func (s *Server) share(ctx context.Context, code string, resp *RunResponse) {
	cid, err := s.IPFS.UploadDir(ctx, shareFiles(code, *resp))
	if err != nil {
		slog.WarnContext(ctx, "ipfs upload failed", "error", err)
		return
	}
	resp.CID, resp.ShareURL = cid, s.IPFS.ShareURL(cid)
}

// shareFiles is the directory behind the share link. Every file is always
// present, empty or not, so the layout does not depend on the result.
func shareFiles(code string, resp RunResponse) []ipfs.File {
	meta, _ := json.MarshalIndent(resultMeta{
		Language: "rust", Target: compiler.Target,
		Status: resp.Status, ExitCode: resp.ExitCode,
	}, "", "  ")
	return []ipfs.File{
		{Name: "main.rs", Data: []byte(code)},
		{Name: "stdout.txt", Data: []byte(resp.Stdout)},
		{Name: "stderr.txt", Data: []byte(resp.Stderr)},
		{Name: "result.json", Data: append(meta, '\n')},
	}
}
