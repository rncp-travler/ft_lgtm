import type { FC } from "react";
import { STATUS_LABEL, type RunResponse } from "../types";

interface Props {
  running: boolean;
  result: RunResponse | null;
  error: string | null;
}

const StatusBar: FC<Props> = ({ running, result, error }) => {
  if (running) {
    return (
      <div className="status status-running">
        <span className="spinner" aria-hidden="true" />
        Compiling → sandboxing → uploading to IPFS…
      </div>
    );
  }
  if (error) {
    return <div className="status status-error">{error}</div>;
  }
  if (!result) {
    return <div className="status status-idle">Ready</div>;
  }
  return (
    <div className={`status status-${result.status}`}>
      <strong>{STATUS_LABEL[result.status]}</strong>
      <span>exit {result.exitCode}</span>
      <span>{result.durationMs} ms</span>
      {result.traceId && (
        <span className="trace-id">trace {result.traceId.slice(0, 12)}…</span>
      )}
    </div>
  );
};

export default StatusBar;
