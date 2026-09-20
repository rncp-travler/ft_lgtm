import { Editor, loader } from "@monaco-editor/react";
import * as monaco from "monaco-editor/editor";
import "monaco-editor/languages/definitions/rust/register";
import EditorWorker from "monaco-editor/editor/editor.worker?worker";
import type { FC } from "react";

self.MonacoEnvironment = { getWorker: () => new EditorWorker() };

loader.config({ monaco });

interface Props {
  value: string;
  onChange: (value: string) => void;
  disabled?: boolean;
}

const CodeEditor: FC<Props> = ({ value, onChange, disabled }) => (
  <Editor
    height="100%"
    language="rust"
    theme="vs-dark"
    value={value}
    onChange={(next) => onChange(next ?? "")}
    loading="Loading editor…"
    options={{
      readOnly: disabled,
      minimap: { enabled: false },
      fontSize: 14,
      tabSize: 4,
      scrollBeyondLastLine: false,
      automaticLayout: true,
    }}
  />
);

export default CodeEditor;
