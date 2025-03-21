package tastytrade

import (
	"fmt"
	"strings"
)

// APIError represents an error response from the Tastytrade API
type APIError struct {
	StatusCode int
	Message    string
	Errors     []string
}

// Error implements the error interface for APIError
func (e *APIError) Error() string {
	if len(e.Errors) > 0 {
		return fmt.Sprintf("tastytrade API error (status %d): %s - %s", e.StatusCode, e.Message, strings.Join(e.Errors, "; "))
	}
	return fmt.Sprintf("tastytrade API error (status %d): %s", e.StatusCode, e.Message)
}

// IsNotFound returns true if the error is a 404 Not Found error
func (e *APIError) IsNotFound() bool {
	return e.StatusCode == 404
}

// IsUnauthorized returns true if the error is a 401 Unauthorized error
func (e *APIError) IsUnauthorized() bool {
	return e.StatusCode == 401
}

// IsForbidden returns true if the error is a 403 Forbidden error
func (e *APIError) IsForbidden() bool {
	return e.StatusCode == 403
}

// IsAPIError checks if an error is an APIError
func IsAPIError(err error) (*APIError, bool) {
	apiErr, ok := err.(*APIError)
	return apiErr, ok
}
