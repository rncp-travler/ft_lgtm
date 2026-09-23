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

Traces, metrics and logs leave the backend over OTLP/gRPC, reach the
OpenTelemetry Collector, and are routed to Tempo, Mimir and Loki. Grafana ties
them together: an exemplar on a latency panel opens the trace, and a span links
to the logs carrying the same `trace_id`.

Everything runs on a local k3d cluster inside the VM — no cloud services.

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

A Debian 13.7.0 virtual machine with `sudo` and an internet connection. Nothing
else has to be installed by hand: `make up` installs Docker, k3d, kubectl and
helm itself, and the container images carry their own Go, Rust and Node.

| Tool    | Installed by     | Used for                       |
| ------- | ---------------- | ------------------------------ |
| Docker  | `make packages`  | k3d runs the cluster in it     |
| k3d     | `make packages`  | the local Kubernetes cluster   |
| kubectl | `make packages`  | applying the manifests         |
| helm    | `make packages`  | the LGTM charts                |

Every install target is idempotent and skips a tool that is already present, so
`make packages` is safe to re-run at any time. `make versions` prints what is
installed.

## Instructions

```sh
make up
```

That single command installs the tooling, creates the k3d cluster, builds and
imports the two images, installs the LGTM stack, deploys the application,
provisions the dashboards and adds the `/etc/hosts` entries. Then open:

| URL                       | What                    |
| ------------------------- | ----------------------- |
| http://lgtm.local         | playground UI           |
| http://grafana.lgtm.local | Grafana (admin / admin) |
| http://ipfs.lgtm.local    | IPFS gateway            |

Docker is installed with your user added to the `docker` group, which only
takes effect on a new login. If `make up` stops and asks you to log out and
back in, do that and run it again.

Other targets: `make status`, `make logs`, `make down`, `make clean`,
`make fclean`, `make re`. Run `make help` for the full list.

### Local development without the cluster

The services do not depend on Kubernetes — all configuration is environment
variables — so the playground can be run directly on the host while working on
it. This needs the host toolchains:

```sh
make install   # Go, Rust with the wasm32-wasip1 target, frontend dependencies
make dev       # backend on :8080 and the Vite dev server on :5173
```

Then open http://localhost:5173; the dev server proxies `/api` to the backend.
`make check-wasm` compiles a sample program to `wasm32-wasip1` to prove the Rust
toolchain is usable, and `make test` runs the backend tests and frontend checks.

Go must satisfy the `go` directive in `backend/go.mod`, and Rust must be at
least 1.85 because the compile stage passes `--edition 2024` to `rustc`. Both
versions are pinned at the top of the Makefile: `make toolchain GO_VERSION=1.27.2`.

Go lands in `/usr/local/go` and rustup in `~/.cargo`; the Makefile puts both on
`PATH` for its own recipes, but add them to your shell profile to use `go` and
`cargo` directly.

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
├── Makefile                 install / build / deploy / teardown automation
├── frontend/                Monaco-based playground UI (React + TypeScript + Vite)
│   ├── Dockerfile           built bundle served by unprivileged nginx
│   └── src/                 editor, run button, output panel, share link
├── backend/                 Go API: rustc -> wasmtime -> IPFS, instrumented with OTel
│   ├── Dockerfile           Go build stage, Rust toolchain in the runtime stage
│   └── src/internal/        compiler, sandbox, ipfs, telemetry, api
├── k8s/
│   ├── k3d-config.yaml      local cluster definition, publishes 80/443
│   ├── base/                frontend, backend, IPFS, Ingress
│   └── observability/       OTel Collector + Helm values for the LGTM stack
└── dashboards/              Grafana dashboards, provisioned by `make dashboards`
```

## Observability walkthrough

1. Run some code in the playground a few times, including something that loops
   forever so it times out.
2. Open **LGTM - Metrics Big Picture**: throughput, success rate and latency.
3. Click an exemplar dot on the latency panel → the trace opens in Tempo,
   showing which stage was slow.
4. In a span, choose **Logs for this span** → Loki shows the log lines with the
   same `trace_id`.

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
