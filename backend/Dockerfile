# Build stage: cgo is required (wasmtime-go links a static library).
FROM golang:1.27-bookworm AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY src ./src
RUN CGO_ENABLED=1 go build -trimpath -o /out/backend ./src

# Runtime stage: needs the Rust toolchain, since user code is compiled here.
FROM rust:1-slim-bookworm
RUN rustup target add wasm32-wasip1 \
    && useradd --uid 10001 --create-home app
COPY --from=build /out/backend /usr/local/bin/backend

USER 10001
ENV ADDR=:8080
EXPOSE 8080
# Mount an emptyDir at /tmp: compile and run scratch dirs live there,
# so the root filesystem can stay read-only.
ENTRYPOINT ["backend"]
