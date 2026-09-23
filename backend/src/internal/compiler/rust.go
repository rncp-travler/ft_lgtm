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
	"strings"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
)

const Target = "wasm32-wasip1"

// displayName is what the user's file is called in diagnostics and panics.
const displayName = "main.rs"

// ErrCompile means the user's code failed to compile; Output holds rustc's diagnostics.
type ErrCompile struct{ Output string }

func (e *ErrCompile) Error() string { return "compilation failed" }

type Rust struct {
	RustcPath string
}

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

	// The throwaway directory is an implementation detail, so keep its path out
	// of what the user sees: --remap-path-prefix rewrites the paths baked into
	// the module (panic messages), and the diagnostics are rewritten below.
	cmd := exec.CommandContext(ctx, r.RustcPath,
		"--edition", "2024",
		"--target", Target,
		"-C", "opt-level=1",
		"--remap-path-prefix", src+"="+displayName,
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
		// Deadline and client cancellation both kill rustc, and they mean
		// different things to the caller, so hand the context error through
		// unchanged rather than flattening both into one message.
		if ctx.Err() != nil {
			return nil, fmt.Errorf("compile: %w", ctx.Err())
		}
		var exitErr *exec.ExitError
		if errors.As(err, &exitErr) {
			return nil, &ErrCompile{Output: strings.ReplaceAll(stderr.String(), src, displayName)}
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
