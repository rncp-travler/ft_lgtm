// Package ipfs uploads run results to a kubo node through its RPC API.
package ipfs

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"mime/multipart"
	"net/http"
	"strings"
	"time"

	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
)

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

// Upload adds data to IPFS (pinned, CIDv1) and returns its CID.
func (c *Client) Upload(ctx context.Context, name string, data []byte) (cid string, err error) {
	ctx, span := otel.Tracer("ft_lgtm/backend").Start(ctx, "ipfs.upload")

	defer span.End()

	span.SetAttributes(attribute.Int("ipfs.bytes", len(data)))

	defer func() {
		if err != nil {
			span.RecordError(err)
			span.SetStatus(codes.Error, err.Error())
		}
	}()

	var body bytes.Buffer

	mw := multipart.NewWriter(&body)
	fw, err := mw.CreateFormFile("file", name)
	if err != nil {
		return "", err
	}
	if _, err := fw.Write(data); err != nil {
		return "", err
	}
	if err := mw.Close(); err != nil {
		return "", err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost,
		c.apiURL+"/api/v0/add?pin=true&cid-version=1", &body)

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

	var out struct{ Hash string }
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return "", err
	}
	span.SetAttributes(attribute.String("ipfs.cid", out.Hash))
	return out.Hash, nil
}

// ShareURL builds a gateway link for a CID.
func (c *Client) ShareURL(cid string) string {
	return c.gatewayURL + "/ipfs/" + cid
}
