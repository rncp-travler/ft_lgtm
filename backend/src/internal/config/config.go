// Package config loads backend settings from environment variables.
// OpenTelemetry exporters read the standard OTEL_* variables directly,
// so they are not duplicated here.
package config

import (
	"os"
	"strconv"
	"time"
)

type Config struct {
	Addr string

	// Compile stage (rustc -> wasm32-wasip1)
	RustcPath      string
	CompileTimeout time.Duration
	MaxCodeBytes   int64

	// Execute stage (WASI sandbox)
	ExecTimeout      time.Duration
	MemoryLimitBytes int64
	MaxOutputBytes   int64

	// IPFS
	IPFSAPIURL     string // kubo RPC API, cluster-internal only (e.g. http://ipfs:5001)
	IPFSGatewayURL string // public gateway used to build share links
}

func Load() Config {
	return Config{
		Addr:             env("ADDR", ":8080"),
		RustcPath:        env("RUSTC_PATH", "rustc"),
		CompileTimeout:   envDuration("COMPILE_TIMEOUT", 15*time.Second),
		MaxCodeBytes:     envInt("MAX_CODE_BYTES", 64<<10),
		ExecTimeout:      envDuration("EXEC_TIMEOUT", 5*time.Second),
		MemoryLimitBytes: envInt("MEMORY_LIMIT_BYTES", 10<<20),
		MaxOutputBytes:   envInt("MAX_OUTPUT_BYTES", 64<<10),
		IPFSAPIURL:       env("IPFS_API_URL", "http://ipfs:5001"),
		IPFSGatewayURL:   env("IPFS_GATEWAY_URL", "http://ipfs.lgtm.local"),
	}
}

func env(key, def string) string {
	if v, ok := os.LookupEnv(key); ok && v != "" {
		return v
	}
	return def
}

func envInt(key string, def int64) int64 {
	if v, err := strconv.ParseInt(os.Getenv(key), 10, 64); err == nil {
		return v
	}
	return def
}

func envDuration(key string, def time.Duration) time.Duration {
	if v, err := time.ParseDuration(os.Getenv(key)); err == nil {
		return v
	}
	return def
}
