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

// parseTime is a helper function to parse time using multiple formats
func parseTime(timeStr string, debug bool) (time.Time, bool) {
	// Try several time formats since the API might return different formats
	timeFormats := []string{
		time.RFC3339,                    // Standard format with seconds precision: "2006-01-02T15:04:05Z07:00"
		time.RFC3339Nano,                // With nanoseconds: "2006-01-02T15:04:05.999999999Z07:00"
		"2006-01-02T15:04:05.000Z",      // Common format with milliseconds and Z timezone
		"2006-01-02T15:04:05.000-07:00", // Format with timezone offset
	}

	for _, format := range timeFormats {
		expTime, err := time.Parse(format, timeStr)
		if err == nil {
			return expTime, true
		}
	}

	if debug {
		fmt.Printf("Failed to parse time '%s' with standard formats\n", timeStr)
	}

	return time.Now().Add(24 * time.Hour), false
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
	var authResp struct {
		SessionResponse AuthResponse `json:"data"`
	}

	if err := json.Unmarshal(respBody, &authResp); err != nil {
		// Try direct unmarshaling if wrapper format fails
		if err2 := json.Unmarshal(respBody, &authResp.SessionResponse); err2 != nil {
			return fmt.Errorf("failed to parse auth response: %w", err)
		}
	}

	// Store the tokens
	c.Token = authResp.SessionResponse.SessionToken
	c.RememberMeToken = authResp.SessionResponse.RememberMeToken

	// Store session ID if available
	if authResp.SessionResponse.User.ExternalID != "" {
		c.SessionID = authResp.SessionResponse.User.ExternalID
	}

	// Parse expiration time if provided
	if authResp.SessionResponse.SessionExpiration != "" {
		expTime, success := parseTime(authResp.SessionResponse.SessionExpiration, c.Debug)
		if success {
			c.ExpiresAt = expTime
		} else {
			// Set a default expiration (24 hours from now) as fallback
			c.ExpiresAt = time.Now().Add(24 * time.Hour)
		}
	} else {
		// No expiration provided, set a default (24 hours from now)
		c.ExpiresAt = time.Now().Add(24 * time.Hour)
	}

	if c.Debug {
		fmt.Printf("Authentication successful. Token: %s\n", c.Token)
		fmt.Printf("Remember-me token: %s\n", c.RememberMeToken)
		fmt.Printf("Session expiration: %s\n", c.ExpiresAt.Format(time.RFC3339))
	}

	return nil
}

// LoginWithRememberMeToken authenticates using a saved remember-me token
func (c *Client) LoginWithRememberMeToken(ctx context.Context, username, rememberMeToken string) error {
	if rememberMeToken == "" {
		return fmt.Errorf("remember-me token is required")
	}

	reqBody, err := json.Marshal(map[string]interface{}{
		"login":          username,
		"remember-token": rememberMeToken,
	})
	if err != nil {
		return err
	}

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
	var authResp struct {
		SessionResponse AuthResponse `json:"data"`
	}

	if err := json.Unmarshal(respBody, &authResp); err != nil {
		// Try direct unmarshaling if wrapper format fails
		if err2 := json.Unmarshal(respBody, &authResp.SessionResponse); err2 != nil {
			return fmt.Errorf("failed to parse auth response: %w - %w", err, err2)
		}
	}

	// Store the tokens
	c.Token = authResp.SessionResponse.SessionToken
	c.RememberMeToken = authResp.SessionResponse.RememberMeToken

	// Store session ID if available
	if authResp.SessionResponse.User.ExternalID != "" {
		c.SessionID = authResp.SessionResponse.User.ExternalID
	}

	// Parse expiration time if provided
	if authResp.SessionResponse.SessionExpiration != "" {
		expTime, err := time.Parse(TimeFormat, authResp.SessionResponse.SessionExpiration)
		if err != nil {
			return fmt.Errorf("failed to parse expiration time: %w", err)
		}
		c.ExpiresAt = expTime
	}

	if c.Debug {
		fmt.Printf("Authentication successful with remember token. Token: %s\n", c.Token)
		fmt.Printf("Remember-me token: %s\n", c.RememberMeToken)
		fmt.Printf("Session expiration: %s\n", c.ExpiresAt.Format(time.RFC3339))
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

	// Check if token is expired or about to expire (less than 5 minutes left)
	if time.Until(c.ExpiresAt) <= 5*time.Minute {
		if c.Debug {
			fmt.Println("Session token is about to expire, attempting to refresh")
		}

		// If remember-me token is available, try to use it
		if c.RememberMeToken != "" {
			// This is a simplified version; you might need more complex logic
			// for token refresh based on API's capabilities
			return fmt.Errorf("session expired, re-authentication required")
		}
		return fmt.Errorf("session expired, re-authentication required")
	}
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
		if auth {
			fmt.Printf("Using authorization token: %s\n", c.Token)
		}
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

	// Try to parse the response as a data wrapper first
	var dataWrapper struct {
		Data json.RawMessage `json:"data"`
	}

	// Parse the response
	if err := json.Unmarshal(respBody, &dataWrapper); err != nil && len(dataWrapper.Data) > 0 {
		// If we have data in the wrapper, unmarshal just that part
		if err := json.Unmarshal(dataWrapper.Data, v); err != nil {
			return fmt.Errorf("failed to parse response data: %w", err)
		}
		return nil
	}

	// If no data wrapper, try direct unmarshaling
	if err := json.Unmarshal(respBody, v); err != nil {
		return fmt.Errorf("failed to parse response: %w", err)
	}

	return nil
}
