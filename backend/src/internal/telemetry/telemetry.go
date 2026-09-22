// Package telemetry wires the OpenTelemetry SDK (traces, metrics, logs)
// to an OTLP/gRPC exporter pointing at the OpenTelemetry Collector.
//
// Exporter endpoints come from the standard env vars, e.g.
//
//	OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector.observability:4317
//	OTEL_EXPORTER_OTLP_INSECURE=true
//	OTEL_SERVICE_NAME=lgtm-backend
package telemetry

import (
	"context"
	"errors"
	"log/slog"
	"os"

	"go.opentelemetry.io/contrib/bridges/otelslog"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlplog/otlploggrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/log/global"
	"go.opentelemetry.io/otel/propagation"
	sdklog "go.opentelemetry.io/otel/sdk/log"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.43.0"
)

const ScopeName = "ft_lgtm/backend"

// Setup installs global tracer/meter/logger providers and replaces the
// default slog logger so every log line is exported to Loki (with the
// active trace_id/span_id) and also printed to stdout.
// The returned function flushes and shuts everything down.
func Setup(ctx context.Context) (shutdown func(context.Context) error, err error) {
	var shutdowns []func(context.Context) error
	shutdown = func(ctx context.Context) error {
		var errs error
		for _, fn := range shutdowns {
			errs = errors.Join(errs, fn(ctx))
		}
		return errs
	}
	defer func() {
		if err != nil {
			err = errors.Join(err, shutdown(ctx))
		}
	}()

	// Later options win, so OTEL_SERVICE_NAME / OTEL_RESOURCE_ATTRIBUTES override the default.
	res, err := resource.New(ctx,
		resource.WithAttributes(semconv.ServiceName("lgtm-backend")),
		resource.WithFromEnv(),
		resource.WithTelemetrySDK(),
		resource.WithHost(),
	)
	if err != nil {
		return nil, err
	}

	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{}, propagation.Baggage{},
	))

	// Traces -> Tempo
	traceExp, err := otlptracegrpc.New(ctx)
	if err != nil {
		return nil, err
	}
	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(traceExp),
		sdktrace.WithResource(res),
	)
	otel.SetTracerProvider(tp)
	shutdowns = append(shutdowns, tp.Shutdown)

	// Metrics -> Mimir (exemplars are attached automatically for sampled spans)
	metricExp, err := otlpmetricgrpc.New(ctx)
	if err != nil {
		return nil, err
	}
	mp := sdkmetric.NewMeterProvider(
		sdkmetric.WithReader(sdkmetric.NewPeriodicReader(metricExp)),
		sdkmetric.WithResource(res),
	)
	otel.SetMeterProvider(mp)
	shutdowns = append(shutdowns, mp.Shutdown)

	// Logs -> Loki
	logExp, err := otlploggrpc.New(ctx)
	if err != nil {
		return nil, err
	}
	lp := sdklog.NewLoggerProvider(
		sdklog.WithProcessor(sdklog.NewBatchProcessor(logExp)),
		sdklog.WithResource(res),
	)
	global.SetLoggerProvider(lp)
	shutdowns = append(shutdowns, lp.Shutdown)

	slog.SetDefault(slog.New(slog.NewMultiHandler(
		otelslog.NewHandler(ScopeName, otelslog.WithLoggerProvider(lp)),
		slog.NewJSONHandler(os.Stdout, nil),
	)))

	return shutdown, nil
}
