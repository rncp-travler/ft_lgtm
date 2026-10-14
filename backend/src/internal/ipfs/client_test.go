package ipfs

import (
	"context"
	"fmt"
	"io"
	"mime"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
)

// Fixed CIDs, so a failing test shows the same values every run. They are
// only strings to the client; the integration test checks real ones.
const (
	dirCID  = "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
	fileCID = "bafkreifjjcie6lypi6ny7amxnfftagclbuxndqonfipmb64f2km2devei4"
)

// fakeKubo answers /api/v0/add the way kubo does with wrap-with-directory:
// one line per file, then the wrapping directory with an empty Name. It
// records what the client sent.
type fakeKubo struct {
	query url.Values
	files map[string]string
	order []string
}

func (k *fakeKubo) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost || r.URL.Path != "/api/v0/add" {
		http.NotFound(w, r)
		return
	}
	k.query = r.URL.Query()
	k.files = map[string]string{}

	_, params, err := mime.ParseMediaType(r.Header.Get("Content-Type"))
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	mr := multipart.NewReader(r.Body, params["boundary"])
	for {
		p, err := mr.NextPart()
		if err == io.EOF {
			break
		}
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		name, _ := url.QueryUnescape(p.FileName())
		data, _ := io.ReadAll(p)
		k.files[name] = string(data)
		k.order = append(k.order, name)
	}

	for _, name := range k.order {
		fmt.Fprintf(w, `{"Name":%q,"Hash":%q,"Size":"1"}`+"\n", name, fileCID)
	}
	fmt.Fprintf(w, `{"Name":"","Hash":%q,"Size":"4"}`+"\n", dirCID)
}

func newTestClient(t *testing.T, h http.Handler) *Client {
	srv := httptest.NewServer(h)
	t.Cleanup(srv.Close)
	return New(srv.URL, "http://ipfs.lgtm.local/")
}

var testFiles = []File{
	{Name: "main.rs", Data: []byte(`fn main() { println!("hi"); }`)},
	{Name: "stdout.txt", Data: []byte("hi\n")},
	{Name: "stderr.txt", Data: nil},
	{Name: "result.json", Data: []byte(`{"status":"success"}`)},
}

func TestUploadDirReturnsWrapperCID(t *testing.T) {
	kubo := &fakeKubo{}
	cid, err := newTestClient(t, kubo).UploadDir(context.Background(), testFiles)
	if err != nil {
		t.Fatal(err)
	}
	if cid != dirCID {
		t.Fatalf("got CID %s, want the directory %s (not a file's)", cid, dirCID)
	}
}

func TestUploadDirQuery(t *testing.T) {
	kubo := &fakeKubo{}
	if _, err := newTestClient(t, kubo).UploadDir(context.Background(), testFiles); err != nil {
		t.Fatal(err)
	}
	for key, want := range map[string]string{
		"pin":                 "true",
		"cid-version":         "1",
		"wrap-with-directory": "true",
	} {
		if got := kubo.query.Get(key); got != want {
			t.Errorf("%s=%q, want %q", key, got, want)
		}
	}
}

func TestUploadDirSendsEveryFile(t *testing.T) {
	kubo := &fakeKubo{}
	if _, err := newTestClient(t, kubo).UploadDir(context.Background(), testFiles); err != nil {
		t.Fatal(err)
	}
	if len(kubo.order) != len(testFiles) {
		t.Fatalf("sent %v, want %d files", kubo.order, len(testFiles))
	}
	for _, f := range testFiles {
		got, ok := kubo.files[f.Name]
		if !ok {
			t.Errorf("%s missing", f.Name)
		} else if got != string(f.Data) {
			t.Errorf("%s = %q, want %q", f.Name, got, f.Data)
		}
	}
}

func TestUploadDirErrors(t *testing.T) {
	tests := []struct {
		name    string
		handler http.HandlerFunc
		files   []File
		want    string
	}{
		{
			name:  "no files",
			files: nil,
			want:  "no files",
		},
		{
			name: "http error",
			handler: func(w http.ResponseWriter, _ *http.Request) {
				http.Error(w, "boom", http.StatusInternalServerError)
			},
			files: testFiles,
			want:  "unexpected status",
		},
		{
			name: "no directory entry",
			handler: func(w http.ResponseWriter, _ *http.Request) {
				fmt.Fprintf(w, `{"Name":"main.rs","Hash":%q}`+"\n", fileCID)
			},
			files: testFiles,
			want:  "no directory",
		},
		{
			name: "malformed response",
			handler: func(w http.ResponseWriter, _ *http.Request) {
				io.WriteString(w, "not json")
			},
			files: testFiles,
			want:  "decoding response",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			h := tt.handler
			if h == nil {
				h = func(w http.ResponseWriter, _ *http.Request) {
					t.Error("no request expected")
				}
			}
			_, err := newTestClient(t, h).UploadDir(context.Background(), tt.files)
			if err == nil || !strings.Contains(err.Error(), tt.want) {
				t.Fatalf("got %v, want an error containing %q", err, tt.want)
			}
		})
	}
}

func TestShareURL(t *testing.T) {
	c := New("http://ipfs:5001", "http://ipfs.lgtm.local/")
	if got, want := c.ShareURL(dirCID), "http://ipfs.lgtm.local/ipfs/"+dirCID; got != want {
		t.Fatalf("got %s, want %s", got, want)
	}
}
