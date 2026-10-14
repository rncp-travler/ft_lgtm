package api

import (
	"context"
	"encoding/json"
	"errors"
	"testing"

	"ft_lgtm/backend/src/internal/ipfs"
)

// fixedCID is what the fake publisher returns: a constant, never a random
// value, so it cannot be mistaken for content that exists on the network.
const fixedCID = "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"

type fakePublisher struct {
	files []ipfs.File
	err   error
}

func (p *fakePublisher) UploadDir(_ context.Context, files []ipfs.File) (string, error) {
	p.files = files
	if p.err != nil {
		return "", p.err
	}
	return fixedCID, nil
}

func (p *fakePublisher) ShareURL(cid string) string {
	return "http://ipfs.lgtm.local/ipfs/" + cid
}

var sampleRun = RunResponse{
	Status:   StatusRuntimeError,
	Stdout:   "partial\n",
	Stderr:   "thread 'main' panicked\n",
	ExitCode: 101,
}

func TestShareSetsLink(t *testing.T) {
	pub := &fakePublisher{}
	s := &Server{IPFS: pub}
	resp := sampleRun

	s.share(context.Background(), "fn main() {}", &resp)

	if resp.CID != fixedCID {
		t.Errorf("CID = %q, want %q", resp.CID, fixedCID)
	}
	if want := "http://ipfs.lgtm.local/ipfs/" + fixedCID; resp.ShareURL != want {
		t.Errorf("ShareURL = %q, want %q", resp.ShareURL, want)
	}
	if len(pub.files) != 4 {
		t.Errorf("uploaded %d files, want 4", len(pub.files))
	}
}

func TestShareFailureKeepsResult(t *testing.T) {
	s := &Server{IPFS: &fakePublisher{err: errors.New("kubo down")}}
	resp := sampleRun

	s.share(context.Background(), "fn main() {}", &resp)

	if resp.CID != "" || resp.ShareURL != "" {
		t.Errorf("got link %q / %q after a failed upload", resp.CID, resp.ShareURL)
	}
	if resp.Stdout != sampleRun.Stdout || resp.Status != sampleRun.Status {
		t.Errorf("run result changed: %+v", resp)
	}
}

func TestShareFilesLayout(t *testing.T) {
	code := "fn main() { println!(\"partial\"); panic!(); }"
	files := shareFiles(code, sampleRun)

	got := map[string]string{}
	for _, f := range files {
		got[f.Name] = string(f.Data)
	}
	for name, want := range map[string]string{
		"main.rs":    code,
		"stdout.txt": sampleRun.Stdout,
		"stderr.txt": sampleRun.Stderr,
	} {
		if got[name] != want {
			t.Errorf("%s = %q, want %q", name, got[name], want)
		}
	}

	var meta resultMeta
	if err := json.Unmarshal([]byte(got["result.json"]), &meta); err != nil {
		t.Fatalf("result.json: %v", err)
	}
	if meta.Status != sampleRun.Status || meta.ExitCode != sampleRun.ExitCode || meta.Language != "rust" {
		t.Errorf("result.json = %+v", meta)
	}
}

func TestShareFilesAlwaysComplete(t *testing.T) {
	// A clean run has no stderr; the file is still there, just empty.
	files := shareFiles("fn main() {}", RunResponse{Status: StatusSuccess})
	if len(files) != 4 {
		t.Fatalf("got %d files, want 4", len(files))
	}
}

func TestShareFilesDeterministic(t *testing.T) {
	// No timestamp in result.json: the same run must give the same bytes,
	// hence the same CID.
	a := shareFiles("fn main() {}", sampleRun)
	b := shareFiles("fn main() {}", sampleRun)
	for i := range a {
		if a[i].Name != b[i].Name || string(a[i].Data) != string(b[i].Data) {
			t.Fatalf("%s differs between two identical runs", a[i].Name)
		}
	}
}
