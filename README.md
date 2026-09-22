_This project has been created as part of the 42 curriculum by taebkim and yuhyoon._

# ft_lgtm — Looks Good To Monitor

A code playground that runs untrusted Rust in a WASM/WASI sandbox, pins the
result to IPFS, and instruments every step with OpenTelemetry.

## Description

A visitor writes Rust in the browser and presses **Run**. The backend compiles
it to `wasm32-wasip1`, executes it inside wasmtime under hard limits, packages
the result, pins it to IPFS and returns a share link.

Every request produces one trace:

```
POST /api/run ──▶ compile ──▶ execute ──▶ ipfs.upload
   (otelhttp)     (rustc)     (wasmtime)   (kubo RPC)
```

Traces, metrics and logs leave the backend over OTLP/gRPC, so they can be
collected by an OpenTelemetry Collector and routed to the LGTM stack (Loki,
Grafana, Tempo, Mimir). This repository holds the two services only; the
collector, the LGTM deployment and the Grafana dashboards live outside it.
Without a collector reachable at `OTEL_EXPORTER_OTLP_ENDPOINT` the exporters
simply fail in the background and the playground keeps working.

### Sandbox limits

| Limit      | Value | Enforced by                           |
| ---------- | ----- | ------------------------------------- |
| Memory     | 10 MB | wasmtime store limiter                |
| Wall clock | 5 s   | epoch interruption + request deadline |
| Filesystem | none  | no WASI preopened directories         |
| Network    | none  | WASI preview1 exposes no sockets      |
| Output     | 64 KB | truncated when read back              |

Compilation is the weaker half of the sandbox: `rustc` runs on user input, and
macros such as `include_str!` can read files during compilation. The backend
container therefore runs as a non-root user with a read-only root filesystem
and no mounted secrets.

## Requirements

- Go 1.27+ (cgo must work: wasmtime-go links a static library)
- Rust 1.85+ with the `wasm32-wasip1` target (the compiler uses edition 2024)
- Node.js 22+
- Docker, only for `make images`

## Instructions

```sh
make install   # frontend dependencies + the Rust wasm target
make dev       # backend on :8080 and the Vite dev server on :5173
```

Then open http://localhost:5173. The dev server proxies `/api` to the backend,
so both halves work from that one URL.

`make back` and `make front` run the two services separately. Other targets:
`make build`, `make images`, `make test`, `make lint`, `make clean`,
`make fclean`, `make re`. Run `make help` for the full list.

### IPFS

The share link needs a kubo node. Without one, a run still returns its output
and the upload failure is logged as a warning — only `cid` and `shareUrl` are
left out of the response. To get share links locally:

```sh
docker run -d --name ipfs -p 5001:5001 -p 8081:8080 ipfs/kubo:latest
IPFS_API_URL=http://localhost:5001 IPFS_GATEWAY_URL=http://localhost:8081 make back
```

## API

| Endpoint        | Body / response                                                              |
| --------------- | ---------------------------------------------------------------------------- |
| `POST /api/run` | `{"code": "..."}` → `{status, stdout, stderr, exitCode, durationMs, cid, shareUrl, traceId}` |
| `GET /healthz`  | `200`, excluded from tracing                                                  |

`status` is one of `success`, `compile_error`, `runtime_error`, `timeout` or
`internal_error`.

## Configuration

The backend reads its settings from the environment; the defaults are in
`backend/src/internal/config/config.go`.

| Variable                      | Default                  | What                          |
| ----------------------------- | ------------------------ | ----------------------------- |
| `ADDR`                        | `:8080`                  | listen address                |
| `RUSTC_PATH`                  | `rustc`                  | compiler binary               |
| `COMPILE_TIMEOUT`             | `15s`                    | compile deadline              |
| `MAX_CODE_BYTES`              | `65536`                  | request body limit            |
| `EXEC_TIMEOUT`                | `5s`                     | sandbox wall clock            |
| `MEMORY_LIMIT_BYTES`          | `10485760`               | sandbox memory                |
| `MAX_OUTPUT_BYTES`            | `65536`                  | captured stdout/stderr        |
| `IPFS_API_URL`                | `http://ipfs:5001`       | kubo RPC API                  |
| `IPFS_GATEWAY_URL`            | `http://ipfs.lgtm.local` | gateway used for share links  |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | —                        | OTLP/gRPC collector           |
| `OTEL_SERVICE_NAME`           | `lgtm-backend`           | service name on the telemetry |

The compile stage deliberately runs `rustc` with a minimal environment and a
throwaway `HOME`. `RUSTUP_HOME` and `CARGO_HOME` are forwarded when set, which
is what lets a rustup-managed `rustc` find its toolchain — `make back` sets
them for you.

## Project layout

```
├── Makefile                 build / run / test automation
├── frontend/                Monaco-based playground UI (React + TypeScript + Vite)
│   ├── Dockerfile           built bundle served by unprivileged nginx
│   └── src/                 editor, run button, output panel, share link
└── backend/                 Go API: rustc -> wasmtime -> IPFS, instrumented with OTel
    ├── Dockerfile           Go build stage, Rust toolchain in the runtime stage
    └── src/internal/        compiler, sandbox, ipfs, telemetry, api
```

## Resources

- [OpenTelemetry Go](https://opentelemetry.io/docs/languages/go/)
- [wasmtime-go](https://github.com/bytecodealliance/wasmtime-go)
- [WASI preview1](https://github.com/WebAssembly/WASI)
- [kubo RPC API](https://docs.ipfs.tech/reference/kubo/rpc/)
- [Grafana LGTM stack](https://grafana.com/docs/)

### Use of AI

The initial project scaffolding (directory layout, Dockerfiles and skeleton
code) was generated with Claude Code and then reviewed and adjusted by the
team.

> AI tools were used.
