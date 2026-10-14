//go:build integration

// Runs against a real kubo node: `make test-ipfs` starts a throwaway
// container and sets IPFS_API_URL and IPFS_GATEWAY_URL. Plain
// `go test ./...` skips this file.
package ipfs

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/url"
	"os"
	"sort"
	"strings"
	"testing"
)

func integrationClient(t *testing.T) (*Client, string) {
	api := os.Getenv("IPFS_API_URL")
	if api == "" {
		t.Skip("IPFS_API_URL not set; run `make test-ipfs`")
	}
	gateway := os.Getenv("IPFS_GATEWAY_URL")
	if gateway == "" {
		gateway = "http://ipfs.lgtm.local"
	}
	return New(api, gateway), strings.TrimRight(api, "/")
}

// get fetches a gateway URL, following kubo's redirect to the trailing-slash
// form of a directory.
func get(t *testing.T, u string) []byte {
	t.Helper()
	resp, err := http.Get(u)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("GET %s: %s", u, resp.Status)
	}
	return body
}

// rpc calls a kubo RPC command and returns the body; kubo only takes POST.
func rpc(t *testing.T, api, cmd, arg string) []byte {
	t.Helper()
	resp, err := http.Post(api+"/api/v0/"+cmd+"?arg="+url.QueryEscape(arg), "", nil)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("%s %s: %s %s", cmd, arg, resp.Status, body)
	}
	return body
}

func TestIntegrationUploadDir(t *testing.T) {
	c, api := integrationClient(t)
	ctx := context.Background()

	cid, err := c.UploadDir(ctx, testFiles)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.HasPrefix(cid, "bafy") {
		t.Errorf("CID %s is not a CIDv1 dag-pb directory (bafy...)", cid)
	}

	// The CID is a directory holding exactly the files sent.
	var ls struct {
		Objects []struct{ Links []struct{ Name string } }
	}
	if err := json.Unmarshal(rpc(t, api, "ls", cid), &ls); err != nil {
		t.Fatal(err)
	}
	if len(ls.Objects) != 1 {
		t.Fatalf("ls returned %d objects", len(ls.Objects))
	}
	var got, want []string
	for _, l := range ls.Objects[0].Links {
		got = append(got, l.Name)
	}
	for _, f := range testFiles {
		want = append(want, f.Name)
	}
	sort.Strings(got)
	sort.Strings(want)
	if strings.Join(got, ",") != strings.Join(want, ",") {
		t.Fatalf("directory has %v, want %v", got, want)
	}

	// Each file reads back through the directory path.
	for _, f := range testFiles {
		if body := rpc(t, api, "cat", cid+"/"+f.Name); string(body) != string(f.Data) {
			t.Errorf("%s = %q, want %q", f.Name, body, f.Data)
		}
	}

	// Pinned, so the node's garbage collector keeps it.
	rpc(t, api, "pin/ls", cid)

	// Content addressing: the same files give the same CID.
	again, err := c.UploadDir(ctx, testFiles)
	if err != nil {
		t.Fatal(err)
	}
	if again != cid {
		t.Errorf("second upload gave %s, first gave %s", again, cid)
	}
}

// The share link itself: the gateway lists the directory and serves each
// file, which is what a visitor of http://ipfs.lgtm.local/ipfs/<CID> sees.
func TestIntegrationGateway(t *testing.T) {
	if os.Getenv("IPFS_GATEWAY_URL") == "" {
		t.Skip("IPFS_GATEWAY_URL not set; run `make test-ipfs`")
	}
	c, _ := integrationClient(t)

	cid, err := c.UploadDir(context.Background(), testFiles)
	if err != nil {
		t.Fatal(err)
	}
	link := c.ShareURL(cid)

	listing := string(get(t, link))
	for _, f := range testFiles {
		if !strings.Contains(listing, f.Name) {
			t.Errorf("directory listing at %s does not mention %s", link, f.Name)
		}
	}
	for _, f := range testFiles {
		if body := get(t, link+"/"+f.Name); string(body) != string(f.Data) {
			t.Errorf("%s/%s = %q, want %q", link, f.Name, body, f.Data)
		}
	}
}
