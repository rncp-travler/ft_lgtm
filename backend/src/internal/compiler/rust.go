// Package compiler turns user-submitted Rust source into a WASI module.
package compiler

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
)

const Target = "wasm32-wasip1"

// ErrCompile means the user's code failed to compile; Output holds rustc's diagnostics.
type ErrCompile struct{ Output string }

func (e *ErrCompile) Error() string { return "compilation failed" }

type Rust struct {
	RustcPath string
}

// Compile runs rustc in a throwaway directory and returns the .wasm bytes.
//
// TODO(security): rustc runs untrusted input. Macros such as include_str!
// can read any file the process can see, so the container must run as
// non-root with a read-only root filesystem and no secrets mounted.
func (r Rust) Compile(ctx context.Context, source string) (wasm []byte, err error) {
	ctx, span := otel.Tracer("ft_lgtm/backend").Start(ctx, "compile")
	defer span.End()
	span.SetAttributes(
		attribute.String("compiler", "rustc"),
		attribute.String("compiler.target", Target),
		attribute.Int("source.bytes", len(source)),
	)
	defer func() {
		if err != nil {
			span.RecordError(err)
			span.SetStatus(codes.Error, err.Error())
		}
	}()

	dir, err := os.MkdirTemp("", "build-*")
	if err != nil {
		return nil, err
	}
	defer os.RemoveAll(dir)

	src := filepath.Join(dir, "main.rs")
	out := filepath.Join(dir, "main.wasm")
	if err := os.WriteFile(src, []byte(source), 0o600); err != nil {
		return nil, err
	}

	cmd := exec.CommandContext(ctx, r.RustcPath,
		"--edition", "2024",
		"--target", Target,
		"-C", "opt-level=1",
		"-o", out,
		src,
	)
	cmd.Dir = dir
	// Deliberately minimal environment. RUSTUP_HOME/CARGO_HOME must be kept:
	// the `rustc` in the image is a rustup shim that resolves its toolchain
	// through them, and without them it cannot find a default toolchain.
	cmd.Env = []string{"PATH=" + os.Getenv("PATH"), "HOME=" + dir}
	for _, key := range []string{"RUSTUP_HOME", "CARGO_HOME", "RUSTUP_TOOLCHAIN"} {
		if v, ok := os.LookupEnv(key); ok {
			cmd.Env = append(cmd.Env, key+"="+v)
		}
	}
	var stderr bytes.Buffer
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		if ctx.Err() != nil {
			return nil, fmt.Errorf("compile timed out: %w", ctx.Err())
		}
		var exitErr *exec.ExitError
		if errors.As(err, &exitErr) {
			return nil, &ErrCompile{Output: stderr.String()}
		}
		return nil, err
	}

	wasm, err = os.ReadFile(out)
	if err != nil {
		return nil, err
	}
	span.SetAttributes(attribute.Int("wasm.bytes", len(wasm)))
	return wasm, nil
}
