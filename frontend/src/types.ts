export type RunStatus =
  | "success"
  | "compile_error"
  | "runtime_error"
  | "timeout"
  | "internal_error";

export interface RunResponse {
  status: RunStatus;
  stdout: string;
  stderr: string;
  exitCode: number;
  durationMs: number;
  cid?: string;
  shareUrl?: string;
  traceId?: string;
}

export const STATUS_LABEL: Record<RunStatus, string> = {
  success: "Success",
  compile_error: "Compile error",
  runtime_error: "Runtime error",
  timeout: "Timed out",
  internal_error: "Internal error",
};
