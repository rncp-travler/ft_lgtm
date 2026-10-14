// Package ipfs uploads run results to a kubo node through its RPC API.
package ipfs

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"net/url"
	"strings"
	"time"

	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
)

// File is one entry of the directory pinned for a run. Name is a plain file
// name: the directory is flat.
type File struct {
	Name string
	Data []byte
}

type Client struct {
	apiURL     string
	gatewayURL string
	http       *http.Client
}

func New(apiURL, gatewayURL string) *Client {
	return &Client{
		apiURL:     strings.TrimRight(apiURL, "/"),
		gatewayURL: strings.TrimRight(gatewayURL, "/"),
		http: &http.Client{
			Timeout:   10 * time.Second,
			Transport: otelhttp.NewTransport(http.DefaultTransport),
		},
	}
}

// addQuery pins the result, uses CIDv1 (the base32 form public gateways
// expect) and wraps the files in one directory, whose CID is the share link.
var addQuery = url.Values{
	"pin":                 {"true"},
	"cid-version":         {"1"},
	"wrap-with-directory": {"true"},
}.Encode()

// UploadDir adds files to IPFS as a single directory and returns the
// directory's CID. The same files always give the same CID.
func (c *Client) UploadDir(ctx context.Context, files []File) (cid string, err error) {
	ctx, span := otel.Tracer("ft_lgtm/backend").Start(ctx, "ipfs.upload")
	defer span.End()

	defer func() {
		if err != nil {
			span.RecordError(err)
			span.SetStatus(codes.Error, err.Error())
		}
	}()

	if len(files) == 0 {
		return "", errors.New("ipfs add: no files")
	}

	var body bytes.Buffer
	mw := multipart.NewWriter(&body)
	total := 0
	for _, f := range files {
		// kubo unescapes the part's filename, so escape it on the way in.
		fw, err := mw.CreateFormFile("file", url.QueryEscape(f.Name))
		if err != nil {
			return "", err
		}
		if _, err := fw.Write(f.Data); err != nil {
			return "", err
		}
		total += len(f.Data)
	}
	if err := mw.Close(); err != nil {
		return "", err
	}
	span.SetAttributes(
		attribute.Int("ipfs.files", len(files)),
		attribute.Int("ipfs.bytes", total),
	)

	req, err := http.NewRequestWithContext(ctx, http.MethodPost,
		c.apiURL+"/api/v0/add?"+addQuery, &body)
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", mw.FormDataContentType())

	resp, err := c.http.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("ipfs add: unexpected status %s", resp.Status)
	}

	cid, err = wrapperCID(resp.Body)
	if err != nil {
		return "", err
	}
	span.SetAttributes(attribute.String("ipfs.cid", cid))
	return cid, nil
}

// wrapperCID reads the add response, one JSON object per line: one per file,
// then the wrapping directory, which is the entry with an empty Name. Taking
// the first line would return the CID of a single file instead.
func wrapperCID(r io.Reader) (string, error) {
	dec := json.NewDecoder(r)
	cid := ""
	for {
		var entry struct{ Name, Hash string }
		err := dec.Decode(&entry)
		if errors.Is(err, io.EOF) {
			break
		}
		if err != nil {
			return "", fmt.Errorf("ipfs add: decoding response: %w", err)
		}
		if entry.Name == "" && entry.Hash != "" {
			cid = entry.Hash
		}
	}
	if cid == "" {
		return "", errors.New("ipfs add: no directory in response")
	}
	return cid, nil
}

// ShareURL builds a gateway link for a CID.
func (c *Client) ShareURL(cid string) string {
	return c.gatewayURL + "/ipfs/" + cid
}
