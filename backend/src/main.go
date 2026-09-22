package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"ft_lgtm/backend/src/internal/api"
	"ft_lgtm/backend/src/internal/compiler"
	"ft_lgtm/backend/src/internal/config"
	"ft_lgtm/backend/src/internal/ipfs"
	"ft_lgtm/backend/src/internal/sandbox"
	"ft_lgtm/backend/src/internal/telemetry"

	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
)

func main() {
	if err := run(); err != nil {
		slog.Error("server exited", "error", err)
		os.Exit(1)
	}
}

func run() error {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	cfg := config.Load()

	shutdownTelemetry, err := telemetry.Setup(ctx)
	if err != nil {
		return err
	}
	defer func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		_ = shutdownTelemetry(ctx)
	}()

	metrics, err := telemetry.NewMetrics()
	if err != nil {
		return err
	}

	srv := &api.Server{
		Compiler:       compiler.Rust{RustcPath: cfg.RustcPath},
		CompileTimeout: cfg.CompileTimeout,
		Runtime: sandbox.New(ctx, sandbox.Limits{
			Timeout:        cfg.ExecTimeout,
			MemoryBytes:    cfg.MemoryLimitBytes,
			MaxOutputBytes: cfg.MaxOutputBytes,
		}),
		IPFS:         ipfs.New(cfg.IPFSAPIURL, cfg.IPFSGatewayURL),
		Metrics:      metrics,
		MaxCodeBytes: cfg.MaxCodeBytes,
	}

	// otelhttp creates the root "HTTP request" span and continues any
	// traceparent sent by the caller.
	handler := otelhttp.NewHandler(srv.Routes(), "http.server",
		otelhttp.WithSpanNameFormatter(func(_ string, r *http.Request) string {
			return r.Method + " " + r.URL.Path
		}),
		otelhttp.WithFilter(func(r *http.Request) bool { return r.URL.Path != "/healthz" }),
	)

	httpSrv := &http.Server{
		Addr:              cfg.Addr,
		Handler:           handler,
		ReadHeaderTimeout: 5 * time.Second,
	}

	errCh := make(chan error, 1)
	go func() {
		slog.Info("backend listening", "addr", cfg.Addr)
		errCh <- httpSrv.ListenAndServe()
	}()

	select {
	case err := <-errCh:
		if !errors.Is(err, http.ErrServerClosed) {
			return err
		}
	case <-ctx.Done():
	}

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	return httpSrv.Shutdown(shutdownCtx)
}
