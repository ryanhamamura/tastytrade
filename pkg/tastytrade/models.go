package tastytrade

import (
	"net/http"
	"time"
)

const (
	// API endpoints
	BaseURLProduction = "https://api.tastyworks.com"
	BaseURLCertify    = "https://api.cert.tastyworks.com"

	// Time formats
	TimeFormat = time.RFC3339Nano
)

// AuthResponse represents the authentication response
type AuthResponse struct {
	User              User   `json:"user"`
	RememberMeToken   string `json:"remember-token"`
	SessionExpiration string `json:"session-expiration"`
	SessionToken      string `json:"session-token"`
}

// LoginOptions contains options for the login process
type LoginOptions struct {
	RememberMe bool
}

// User represents a Tastytrade user
type User struct {
	Email       string `json:"email"`
	ExternalID  string `json:"external-id"`
	IsConfirmed string `json:"is-confirmed"`
	Name        string `json:"name"`
	Nickname    string `json:"nickname"`
	Username    string `json:"username"`
}

// ErrorResponse represents an error response from the API
type ErrorResponse struct {
	Context string   `json:"context,omitempty"`
	Code    string   `json:"code,omitempty"`
	Message string   `json:"message,omitempty"`
	Errors  []string `json:"errors,omitempty"`
}

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

// Common pagination fields that are used in many responses
type PaginationData struct {
	TotalCount  int `json:"total-count"`
	PerPage     int `json:"per-page"`
	CurrentPage int `json:"current-page"`
	TotalPages  int `json:"total-pages"`
}
