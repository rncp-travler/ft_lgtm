import { useRef, useState, type FC } from "react";
import CodeEditor from "./components/CodeEditor";
import OutputPanel from "./components/OutputPanel";
import RunButton from "./components/RunButton";
import ShareLink from "./components/ShareLink";
import StatusBar from "./components/StatusBar";
import { runCode } from "./api/client";
import type { RunResponse } from "./types";
import "./App.css";

const SAMPLE = `fn main() {
    println!("Hi this is yuhyoon & taebkim!");
}
`;

const App: FC = () => {
  const [code, setCode] = useState(SAMPLE);
  const [result, setResult] = useState<RunResponse | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [running, setRunning] = useState(false);
  const abortRef = useRef<AbortController | null>(null);

  const handleRun = async () => {
    const controller = new AbortController();
    abortRef.current = controller;
    setRunning(true);
    setError(null);
    setResult(null);

    try {
      setResult(await runCode(code, controller.signal));
    } catch (err) {
      if (!controller.signal.aborted) {
        setError(err instanceof Error ? err.message : String(err));
      }
    } finally {
      setRunning(false);
      abortRef.current = null;
    }
  };

  const handleCancel = () => abortRef.current?.abort();

  return (
    <div className="app">
      <header className="app-header">
        <h1>LGTM Playground 페이지</h1>
        <span className="app-subtitle">Rust → WASI sandbox → IPFS</span>
        <RunButton
          running={running}
          onRun={handleRun}
          onCancel={handleCancel}
        />
      </header>

      <main className="app-main">
        <section className="pane pane-editor">
          <CodeEditor value={code} onChange={setCode} disabled={running} />
        </section>

        <section className="pane pane-output">
          <StatusBar running={running} result={result} error={error} />
          <OutputPanel result={result} />
          <ShareLink cid={result?.cid} shareUrl={result?.shareUrl} />
        </section>
      </main>
    </div>
  );
};

export default App;
