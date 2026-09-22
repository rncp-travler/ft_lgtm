package sandbox

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/bytecodealliance/wasmtime-go/v48"
)

func newTestRuntime(t *testing.T) *Runtime {
	ctx, cancel := context.WithCancel(context.Background())
	t.Cleanup(cancel)
	return New(ctx, Limits{
		Timeout:        500 * time.Millisecond,
		MemoryBytes:    10 << 20,
		MaxOutputBytes: 1 << 10,
	})
}

func wat(t *testing.T, src string) []byte {
	b, err := wasmtime.Wat2Wasm(src)
	if err != nil {
		t.Fatal(err)
	}
	return b
}

func TestRunStdout(t *testing.T) {
	res, err := newTestRuntime(t).Run(context.Background(), wat(t, `(module
		(import "wasi_snapshot_preview1" "fd_write" (func $fd_write (param i32 i32 i32 i32) (result i32)))
		(memory (export "memory") 1)
		(data (i32.const 8) "hello\n")
		(func (export "_start")
			(i32.store (i32.const 0) (i32.const 8))
			(i32.store (i32.const 4) (i32.const 6))
			(drop (call $fd_write (i32.const 1) (i32.const 0) (i32.const 1) (i32.const 20)))))`))
	if err != nil {
		t.Fatal(err)
	}
	if res.Stdout != "hello\n" || res.ExitCode != 0 {
		t.Fatalf("got %+v", res)
	}
}

func TestRunTimeout(t *testing.T) {
	_, err := newTestRuntime(t).Run(context.Background(), wat(t,
		`(module (func (export "_start") (loop $l (br $l))))`))
	if !errors.Is(err, ErrTimeout) {
		t.Fatalf("want ErrTimeout, got %v", err)
	}
}

func TestRunMemoryLimit(t *testing.T) {
	// 200 pages = 12.8MB > 10MB, so memory.grow must fail (-1) and we trap.
	_, err := newTestRuntime(t).Run(context.Background(), wat(t, `(module
		(memory 1)
		(func (export "_start")
			(if (i32.eq (memory.grow (i32.const 200)) (i32.const -1)) (then unreachable))))`))
	var re *RuntimeError
	if !errors.As(err, &re) {
		t.Fatalf("want RuntimeError, got %v", err)
	}
}

func TestRunExitCode(t *testing.T) {
	res, err := newTestRuntime(t).Run(context.Background(), wat(t, `(module
		(import "wasi_snapshot_preview1" "proc_exit" (func $exit (param i32)))
		(memory (export "memory") 1)
		(func (export "_start") (call $exit (i32.const 3))))`))
	var re *RuntimeError
	if !errors.As(err, &re) || res.ExitCode != 3 {
		t.Fatalf("want exit 3, got %+v / %v", res, err)
	}
}
