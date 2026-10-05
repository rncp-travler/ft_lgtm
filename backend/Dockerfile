# Build stage: cgo is required (wasmtime-go links a static library).
FROM golang:1.27-bookworm AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY src ./src
RUN CGO_ENABLED=1 go build -trimpath -o /out/backend ./src

# Toolchain stage: user code is compiled at runtime, but only to
# wasm32-wasip1, so the runtime image gets just rustc, its two shared
# libraries, the wasm32-wasip1 std and the bundled rust-lld. cargo, rustdoc,
# the host std and the C toolchain (~700MB together) stay behind.
FROM rust:1-slim-bookworm AS toolchain
RUN rustup target add wasm32-wasip1 \
    && sysroot="$(rustc --print sysroot)" \
    && host="$(rustc -vV | sed -n 's/^host: //p')" \
    && mkdir -p /opt/rust/bin /opt/rust/lib/rustlib/"$host" \
    && cp -a "$sysroot"/bin/rustc /opt/rust/bin/ \
    && cp -a "$sysroot"/lib/*.so* /opt/rust/lib/ \
    && cp -a "$sysroot"/lib/rustlib/wasm32-wasip1 /opt/rust/lib/rustlib/ \
    && cp -a "$sysroot"/lib/rustlib/"$host"/bin /opt/rust/lib/rustlib/"$host"/ \
    && chmod -R go-w /opt/rust

# Runtime stage: same Debian release as the build stage, for the cgo binary.
FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --uid 10001 --create-home app
COPY --from=toolchain /opt/rust /opt/rust
COPY --from=build /out/backend /usr/local/bin/backend

USER 10001
ENV PATH=/opt/rust/bin:$PATH \
    RUSTC_PATH=/opt/rust/bin/rustc \
    ADDR=:8080
EXPOSE 8080
# Mount an emptyDir at /tmp: compile and run scratch dirs live there,
# so the root filesystem can stay read-only.
ENTRYPOINT ["backend"]
