package tastytrade

const (
	// API endpoints
	BaseURLProduction = "https://api.tastytrade.com"
	BaseURLCertify    = "https://api.cert.tastytrade.com"

	// API versions
	APIVersion = "v1"

	// Time formats
	TimeFormat = "2006-01-02T15:04:05.000-07:00"
)

// AuthResponse represents the authentication response
type AuthResponse struct {
	SessionToken string `json:"session-token"`
	RefreshToken string `json:"refresh-token"`
	ExpiresAt    string `json:"expires-at"`
	User         User   `json:"user"`
}

// User represents a Tastytrade user
type User struct {
	ID        string `json:"id"`
	Username  string `json:"username"`
	Email     string `json:"email"`
	FirstName string `json:"first-name"`
	LastName  string `json:"last-name"`
	// Add other fields as needed
}

// ErrorResponse represents an error response from the API
type ErrorResponse struct {
	Context string   `json:"context,omitempty"`
	Code    string   `json:"code,omitempty"`
	Message string   `json:"message,omitempty"`
	Errors  []string `json:"errors,omitempty"`
}

// Common pagination fields that are used in many responses
type PaginationData struct {
	TotalCount  int `json:"total-count"`
	PerPage     int `json:"per-page"`
	CurrentPage int `json:"current-page"`
	TotalPages  int `json:"total-pages"`
}
