// Package sandbox executes WASI modules with wasmtime under strict limits:
//
//   - memory: store limiter caps linear memory (default 10MB)
//   - time:   epoch interruption traps the guest after the timeout (default 5s)
//   - network: WASI preview1 has no socket creation, and none are passed in
//   - filesystem: no preopened directories, no env vars, empty stdin
package sandbox

import (
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"time"

	"github.com/bytecodealliance/wasmtime-go/v48"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
)

const epochTick = 100 * time.Millisecond

var ErrTimeout = errors.New("execution timed out")

type Result struct {
	Stdout   string
	Stderr   string
	ExitCode int32
}

type Limits struct {
	Timeout        time.Duration
	MemoryBytes    int64
	MaxOutputBytes int64
}

type Runtime struct {
	engine *wasmtime.Engine
	limits Limits
}

// New creates a shared engine and starts the epoch ticker. Every store sets
// its own deadline in ticks, so one ticker serves all concurrent runs.
func New(ctx context.Context, limits Limits) *Runtime {
	cfg := wasmtime.NewConfig()
	cfg.SetEpochInterruption(true)
	engine := wasmtime.NewEngineWithConfig(cfg)

	go func() {
		t := time.NewTicker(epochTick)
		defer t.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-t.C:
				engine.IncrementEpoch()
			}
		}
	}()

	return &Runtime{engine: engine, limits: limits}
}

// Run executes the module's _start export. A non-zero exit code or a guest
// trap is returned as a Result plus a *RuntimeError, not as a Go failure.
func (r *Runtime) Run(ctx context.Context, wasm []byte) (res Result, err error) {
	ctx, span := otel.Tracer("ft_lgtm/backend").Start(ctx, "execute")
	defer span.End()
	span.SetAttributes(
		attribute.String("runtime", "wasmtime"),
		attribute.Int64("limit.memory_bytes", r.limits.MemoryBytes),
		attribute.String("limit.timeout", r.limits.Timeout.String()),
	)
	defer func() {
		span.SetAttributes(attribute.Int("exit_code", int(res.ExitCode)))
		if err != nil {
			span.RecordError(err)
			span.SetStatus(codes.Error, err.Error())
		}
	}()

	dir, err := os.MkdirTemp("", "run-*")
	if err != nil {
		return res, err
	}
	defer os.RemoveAll(dir)
	stdoutPath := filepath.Join(dir, "stdout")
	stderrPath := filepath.Join(dir, "stderr")

	// Epoch interruption only fires while guest code runs; a guest blocked in a
	// host call (e.g. sleep via poll_oneoff) is not interrupted. The wall-clock
	// select below guarantees the HTTP request still returns on time.
	// TODO: kill such runs harder (separate process per run) if this matters.
	type outcome struct {
		exitCode int32
		err      error
	}
	done := make(chan outcome, 1)
	go func() {
		code, err := r.run(wasm, stdoutPath, stderrPath)
		done <- outcome{code, err}
	}()

	select {
	case o := <-done:
		res.ExitCode, err = o.exitCode, o.err
	case <-time.After(r.limits.Timeout + time.Second):
		err = ErrTimeout
	case <-ctx.Done():
		err = ctx.Err()
	}

	res.Stdout = readCapped(stdoutPath, r.limits.MaxOutputBytes)
	res.Stderr = readCapped(stderrPath, r.limits.MaxOutputBytes)
	return res, err
}

type RuntimeError struct{ Msg string }

func (e *RuntimeError) Error() string { return e.Msg }

// run returns the guest's exit code. Note: when the wall-clock timeout wins
// in Run, the temp dir may be removed while this is still writing; the guest
// just loses its output, which is fine.
func (r *Runtime) run(wasm []byte, stdoutPath, stderrPath string) (int32, error) {
	module, err := wasmtime.NewModule(r.engine, wasm)
	if err != nil {
		return 0, fmt.Errorf("load module: %w", err)
	}

	wasi := wasmtime.NewWasiConfig()
	wasi.SetArgv([]string{"main"})
	if err := wasi.SetStdoutFile(stdoutPath); err != nil {
		return 0, err
	}
	if err := wasi.SetStderrFile(stderrPath); err != nil {
		return 0, err
	}
	// Intentionally no PreopenDir / InheritEnv / InheritStdin.

	store := wasmtime.NewStore(r.engine)
	defer store.Close()
	store.SetWasi(wasi)
	store.Limiter(r.limits.MemoryBytes, -1, 1, -1, 1)
	store.SetEpochDeadline(uint64(r.limits.Timeout / epochTick))

	linker := wasmtime.NewLinker(r.engine)
	defer linker.Close()
	if err := linker.DefineWasi(); err != nil {
		return 0, err
	}

	instance, err := linker.Instantiate(store, module)
	if err != nil {
		return 1, &RuntimeError{Msg: err.Error()}
	}
	start := instance.GetFunc(store, "_start")
	if start == nil {
		return 1, &RuntimeError{Msg: "module has no _start export"}
	}

	_, err = start.Call(store)
	if err == nil {
		return 0, nil
	}

	var wErr *wasmtime.Error
	if errors.As(err, &wErr) {
		if code, ok := wErr.ExitStatus(); ok {
			if code == 0 {
				return 0, nil
			}
			return code, &RuntimeError{Msg: fmt.Sprintf("process exited with code %d", code)}
		}
	}
	var trap *wasmtime.Trap
	if errors.As(err, &trap) {
		if c := trap.Code(); c != nil && *c == wasmtime.Interrupt {
			return 1, ErrTimeout
		}
	}
	return 1, &RuntimeError{Msg: err.Error()}
}

func readCapped(path string, max int64) string {
	f, err := os.Open(path)
	if err != nil {
		return ""
	}
	defer f.Close()
	b, _ := io.ReadAll(io.LimitReader(f, max))
	return string(b)
}
