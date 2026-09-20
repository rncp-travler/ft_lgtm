import { useState, type FC } from "react";

interface Props {
  cid?: string;
  shareUrl?: string;
}

/** IPFS share link for the pinned run result. */
const ShareLink: FC<Props> = ({ cid, shareUrl }) => {
  const [copied, setCopied] = useState(false);

  if (!cid || !shareUrl) return null;

  const copy = async () => {
    await navigator.clipboard.writeText(shareUrl);
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  };

  return (
    <div className="share">
      <span className="share-label">IPFS</span>
      <a href={shareUrl} target="_blank" rel="noreferrer" className="share-cid">
        {cid}
      </a>
      <button type="button" onClick={copy}>
        {copied ? "Copied" : "Copy link"}
      </button>
    </div>
  );
};

export default ShareLink;
