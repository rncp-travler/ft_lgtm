import type { RunResponse } from "../types";

/**
 * @POST /api/run
 * compiles, sandboxes and pins the result to IPFS.
 */
export async function runCode(
  code: string,
  signal?: AbortSignal,
): Promise<RunResponse> {
  const res = await fetch("/api/run", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ code }),
    signal,
  });

  if (!res.ok) {
    const detail = await res.text();
    throw new Error(`Request failed (${res.status}): ${detail.slice(0, 200)}`);
  }
  return (await res.json()) as RunResponse;
}
