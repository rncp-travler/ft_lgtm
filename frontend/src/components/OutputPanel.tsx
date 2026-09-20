import type { FC } from "react";
import type { RunResponse } from "../types";

interface Props {
  result: RunResponse | null;
}

const OutputPanel: FC<Props> = ({ result }) => {
  if (!result) {
    return (
      <pre className="output output-empty">Press Run to execute your code.</pre>
    );
  }
  return (
    <div className="output">
      {result.stdout && <pre className="output-stdout">{result.stdout}</pre>}
      {result.stderr && <pre className="output-stderr">{result.stderr}</pre>}
      {!result.stdout && !result.stderr && (
        <pre className="output-empty">(no output)</pre>
      )}
    </div>
  );
};

export default OutputPanel;
