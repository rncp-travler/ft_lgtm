import type { FC } from "react";

interface Props {
  running: boolean;
  onRun: () => void;
  onCancel: () => void;
}

const RunButton: FC<Props> = ({ running, onRun, onCancel }) => (
  <button
    type="button"
    className={`run-button${running ? " is-running" : ""}`}
    onClick={running ? onCancel : onRun}
  >
    {running ? (
      <>
        <span className="spinner" aria-hidden="true" />
        Cancel
      </>
    ) : (
      <>&#9654; Run</>
    )}
  </button>
);

export default RunButton;
