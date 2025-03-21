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
	BaseURL         string
	HTTPClient      *http.Client
	Token           string
	RememberMeToken string
	ExpiresAt       time.Time
	Debug           bool
	SessionID       string
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

func DefaultLoginOptions() LoginOptions {
	return LoginOptions{
		RememberMe: false,
	}
}

// Login authenticates with the Tastytrade API
func (c *Client) Login(ctx context.Context, username, password string, opts ...LoginOptions) error {
	// Use default login options if none provided
	loginOpts := DefaultLoginOptions()
	if len(opts) > 0 {
		loginOpts = opts[0]
	}

	// Prepare request body
	reqData := map[string]interface{}{
		"login":    username,
		"password": password,
	}

	// Add remember-me if requested
	if loginOpts.RememberMe {
		reqData["remember-me"] = true
	}

	reqBody, err := json.Marshal(reqData)
	if err != nil {
		return err
	}

	var authResp AuthResponse

	// Create request for authentication - note: no version in the URL
	url := fmt.Sprintf("%s/sessions", c.BaseURL)
	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBuffer(reqBody))
	if err != nil {
		return err
	}

	// Set required headers
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")

	if c.Debug {
		fmt.Printf("Making POST request to %s\n", url)
		fmt.Printf("Request body: %s\n", string(reqBody))
	}

	// Execute the request
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

	// Parse authentication response
	if err := json.Unmarshal(respBody, &authResp); err != nil {
		return fmt.Errorf("failed to parse auth response: %w", err)
	}

	// Store the tokens
	c.Token = authResp.SessionToken
	c.RememberMeToken = authResp.RememberMeToken
	c.SessionID = authResp.ID

	// Parse expiration time if provided
	if authResp.ExpiresAt != "" {
		expTime, err := time.Parse(TimeFormat, authResp.ExpiresAt)
		if err != nil {
			return fmt.Errorf("failed to parse expiration time: %w", err)
		}
		c.ExpiresAt = expTime
	}

	return nil
}

// LoginWithRememberMeToken authenticates using a saved remember-me token
func (c *Client) LoginWithRememberMeToken(ctx context.Context, username, rememberMeToken string) error {
	if rememberMeToken == "" {
		return fmt.Errorf("remember-me token is required")
	}

	reqBody, err := json.Marshal(map[string]string{
		"login":             username,
		"remember-me-token": rememberMeToken,
	})
	if err != nil {
		return err
	}

	var authResp AuthResponse

	// Create request for auth with remember-me token
	url := fmt.Sprintf("%s/sessions", c.BaseURL)
	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBuffer(reqBody))
	if err != nil {
		return err
	}

	// Set required headers
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")

	if c.Debug {
		fmt.Printf("Making POST request to %s with remember-me token\n", url)
	}

	// Execute request
	resp, err := c.HTTPClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	// Read the response body
	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return err
	}

	// Check for errors
	if resp.StatusCode >= 400 {
		var errResp ErrorResponse
		if err := json.Unmarshal(respBody, &errResp); err != nil {
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

	// Parse authentication response
	if err := json.Unmarshal(respBody, &authResp); err != nil {
		return fmt.Errorf("failed to parse auth response: %w", err)
	}

	// Store the tokens
	c.Token = authResp.SessionToken
	c.RememberMeToken = authResp.RememberMeToken
	c.SessionID = authResp.ID

	// Parse expiration time if provided
	if authResp.ExpiresAt != "" {
		expTime, err := time.Parse(TimeFormat, authResp.ExpiresAt)
		if err != nil {
			return fmt.Errorf("failed to parse expiration time: %w", err)
		}
		c.ExpiresAt = expTime
	}

	return nil
}

// DestroyRememberMeToken invalidates a remember-me token
func (c *Client) DestroyRememberMeToken(ctx context.Context, rememberMeToken string) error {
	// According to the documentation, this endpoint destroys a remember-me token
	url := fmt.Sprintf("%s/sessions/remember-me", c.BaseURL)

	reqBody, err := json.Marshal(map[string]string{
		"remember-me-token": rememberMeToken,
	})
	if err != nil {
		return err
	}

	req, err := http.NewRequestWithContext(ctx, "DELETE", url, bytes.NewBuffer(reqBody))
	if err != nil {
		return err
	}

	// Set required headers
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")

	// Execute the request
	resp, err := c.HTTPClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	// Check for success
	if resp.StatusCode >= 400 {
		respBody, _ := io.ReadAll(resp.Body)
		var errResp ErrorResponse
		if err := json.Unmarshal(respBody, &errResp); err != nil {
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

	// Clear the remember-me token from the client
	if c.RememberMeToken == rememberMeToken {
		c.RememberMeToken = ""
	}

	return nil
}

// Logout destroys the current session
func (c *Client) Logout(ctx context.Context) error {
	if c.Token == "" || c.SessionID == "" {
		return fmt.Errorf("no active session")
	}

	// According to the documentation, this endpoint destroys a session
	url := fmt.Sprintf("%s/sessions/%s", c.BaseURL, c.SessionID)

	req, err := http.NewRequestWithContext(ctx, "DELETE", url, nil)
	if err != nil {
		return err
	}

	// Set required headers
	req.Header.Set("Accept", "application/json")
	req.Header.Set("Authorization", c.Token)

	// Execute the request
	resp, err := c.HTTPClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	// Check for success
	if resp.StatusCode >= 400 {
		respBody, _ := io.ReadAll(resp.Body)
		var errResp ErrorResponse
		if err := json.Unmarshal(respBody, &errResp); err != nil {
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

	// Clear the session information
	c.Token = ""
	c.SessionID = ""

	return nil
}

// EnsureValidToken ensures the token is valid, refreshing if needed
func (c *Client) EnsureValidToken(ctx context.Context) error {
	if c.Token == "" {
		return fmt.Errorf("no active session, authentication required")
	}
	if time.Until(c.ExpiresAt) <= time.Minute {
		return fmt.Errorf("session expired, re-authentication required")
	}

	// Token expired or about to expire, refresh it
	return nil
}

// doRequest is used for all other API requests after authentication
func (c *Client) doRequest(ctx context.Context, method, endpoint string, body io.Reader, auth bool, v interface{}) error {
	// If authentication is required, verify the token
	if auth {
		if err := c.EnsureValidToken(ctx); err != nil {
			return err
		}
	}

	// Normalize endpoint path
	if !strings.HasPrefix(endpoint, "/") {
		endpoint = "/" + endpoint
	}

	// Construct the full URL - note that the API is unversioned, so no API version in the path
	u, err := url.Parse(c.BaseURL)
	if err != nil {
		return err
	}

	// Remove leading slash if present to avoid double slashes
	cleanEndpoint := strings.TrimPrefix(endpoint, "/")
	u.Path = path.Join(u.Path, cleanEndpoint)
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
		// Set the Authorization header with the session token
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
