package tastytrade

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"path"
	"strings"
	"time"
)

// Client represents a Tastytrade API client
type Client struct {
	BaseURL      string
	HTTPClient   *http.Client
	Token        string
	RefreshToken string
	ExpiresAt    time.Time
	Debug        bool
}

// ClientOption is a function that configures a Client
type ClientOption func(*Client)

// WithHTTPClient sets a custom HTTP client
func WithHTTPClient(httpClient *http.Client) ClientOption {
	return func(c *Client) {
		c.HTTPClient = httpClient
	}
}

// WithDebug enables debug logging
func WithDebug(debug bool) ClientOption {
	return func(c *Client) {
		c.Debug = debug
	}
}

// NewClient creates a new Tastytrade API client
func NewClient(useProduction bool, opts ...ClientOption) *Client {
	baseURL := BaseURLCertify
	if useProduction {
		baseURL = BaseURLProduction
	}

	client := &Client{
		BaseURL: baseURL,
		HTTPClient: &http.Client{
			Timeout: time.Minute,
		},
	}

	// Apply options
	for _, opt := range opts {
		opt(client)
	}

	return client
}

// Login authenticates with the Tastytrade API
func (c *Client) Login(ctx context.Context, username, password string) error {
	reqBody, err := json.Marshal(map[string]string{
		"login":    username,
		"password": password,
	})
	if err != nil {
		return err
	}

	var authResp AuthResponse
	err = c.doRequest(ctx, "POST", "/sessions", bytes.NewBuffer(reqBody), false, &authResp)
	if err != nil {
		return err
	}

	c.Token = authResp.SessionToken
	c.RefreshToken = authResp.RefreshToken

	// Parse expiration time
	expTime, err := time.Parse(TimeFormat, authResp.ExpiresAt)
	if err != nil {
		return fmt.Errorf("failed to parse expiration time: %w", err)
	}
	c.ExpiresAt = expTime

	return nil
}

// RefreshSession refreshes the API token
func (c *Client) RefreshSession(ctx context.Context) error {
	if c.RefreshToken == "" {
		return fmt.Errorf("no refresh token available")
	}

	reqBody, err := json.Marshal(map[string]string{
		"refresh-token": c.RefreshToken,
	})
	if err != nil {
		return err
	}

	var authResp AuthResponse
	err = c.doRequest(ctx, "POST", "/sessions/refresh", bytes.NewBuffer(reqBody), false, &authResp)
	if err != nil {
		return err
	}

	c.Token = authResp.SessionToken
	c.RefreshToken = authResp.RefreshToken

	// Parse expiration time
	expTime, err := time.Parse(TimeFormat, authResp.ExpiresAt)
	if err != nil {
		return fmt.Errorf("failed to parse expiration time: %w", err)
	}
	c.ExpiresAt = expTime

	return nil
}

// EnsureValidToken ensures the token is valid, refreshing if needed
func (c *Client) EnsureValidToken(ctx context.Context) error {
	// Check if token will expire in the next minute
	if c.Token != "" && time.Until(c.ExpiresAt) > time.Minute {
		return nil
	}

	// Token expired or about to expire, refresh it
	return c.RefreshSession(ctx)
}

// Helper method to make HTTP requests
func (c *Client) doRequest(ctx context.Context, method, endpoint string, body io.Reader, auth bool, v interface{}) error {
	// Normalize endpoint path
	if !strings.HasPrefix(endpoint, "/") {
		endpoint = "/" + endpoint
	}

	// Construct the full URL
	apiPath := path.Join(APIVersion, endpoint)
	u, err := url.Parse(c.BaseURL)
	if err != nil {
		return err
	}
	u.Path = path.Join(u.Path, apiPath)
	fullURL := u.String()

	// Create request with context
	req, err := http.NewRequestWithContext(ctx, method, fullURL, body)
	if err != nil {
		return err
	}

	if body != nil && (method == "POST" || method == "PUT" || method == "PATCH") {
		req.Header.Set("Content-Type", "application/json")
	}

	req.Header.Set("Accept", "application/json")

	if auth && c.Token != "" {
		req.Header.Set("Authorization", c.Token)
	}

	if c.Debug {
		fmt.Printf("Making %s request to %s\n", method, fullURL)
		if body != nil {
			bodyBytes, _ := io.ReadAll(body)
			// Reset the body for the actual request
			body = bytes.NewBuffer(bodyBytes)
			req.Body = io.NopCloser(bytes.NewBuffer(bodyBytes))
			fmt.Printf("Request body: %s\n", string(bodyBytes))
		}
	}

	resp, err := c.HTTPClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if c.Debug {
		fmt.Printf("Response status: %s\n", resp.Status)
	}

	// Read the response body
	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return err
	}

	if c.Debug && len(respBody) > 0 {
		fmt.Printf("Response body: %s\n", string(respBody))
	}

	// Check for errors
	if resp.StatusCode >= 400 {
		var errResp ErrorResponse
		if err := json.Unmarshal(respBody, &errResp); err != nil {
			// If we can't parse the error response, return a generic error
			return &APIError{
				StatusCode: resp.StatusCode,
				Message:    string(respBody),
			}
		}

		return &APIError{
			StatusCode: resp.StatusCode,
			Message:    errResp.Message,
			Errors:     errResp.Errors,
		}
	}

	// If v is nil, we don't need to parse the response
	if v == nil {
		return nil
	}

	// Parse the response
	if err := json.Unmarshal(respBody, v); err != nil {
		return fmt.Errorf("failed to parse response: %w", err)
	}

	return nil
}
