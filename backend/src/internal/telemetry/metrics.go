package telemetry

import (
	"context"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/metric"
)

// Metrics holds the playground instruments. In Mimir they show up as
//
//	playground_executions_total{status="success|compile_error|runtime_error|timeout|internal_error"}
//	playground_execution_duration_seconds_bucket{status=...}
//
// success / failure / total counts are all derived from the one counter.
type Metrics struct {
	executions metric.Int64Counter
	duration   metric.Float64Histogram
}

func NewMetrics() (*Metrics, error) {
	meter := otel.Meter(ScopeName)

	executions, err := meter.Int64Counter("playground.executions",
		metric.WithDescription("Number of code execution requests, by result status"),
		metric.WithUnit("{execution}"),
	)
	if err != nil {
		return nil, err
	}

	duration, err := meter.Float64Histogram("playground.execution.duration",
		metric.WithDescription("End-to-end duration of the run pipeline (compile + execute + upload)"),
		metric.WithUnit("s"),
		metric.WithExplicitBucketBoundaries(0.1, 0.25, 0.5, 1, 2, 3, 5, 8, 13, 20),
	)
	if err != nil {
		return nil, err
	}

	return &Metrics{executions: executions, duration: duration}, nil
}

// Record must be called with the request context so the SDK can attach
// the current trace as an exemplar (Metric -> Trace link in Grafana).
func (m *Metrics) Record(ctx context.Context, status string, seconds float64) {
	attrs := metric.WithAttributes(attribute.String("status", status))
	m.executions.Add(ctx, 1, attrs)
	m.duration.Record(ctx, seconds, attrs)
}
