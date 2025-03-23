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

// Account represents a trading account as defined in the API documentation
type Account struct {
	AccountNumber         string    `json:"account-number"`
	AccountTypeName       string    `json:"account-type-name"`
	ClosedAt              time.Time `json:"closed-at,omitempty"`
	CreatedAt             time.Time `json:"created-at,omitempty"`
	DayTraderStatus       bool      `json:"day-trader-status"`
	ExtAccountID          string    `json:"ext-account-id,omitempty"`
	ExtCrmID              string    `json:"ext-crm-id,omitempty"`
	ExternalFdid          string    `json:"external-fdid,omitempty"`
	ExternalID            string    `json:"external-id,omitempty"`
	FundingDate           string    `json:"funding-date,omitempty"`
	FuturesAccountPurpose string    `json:"futures-account-purpose,omitempty"`
	InvestmentObjective   string    `json:"investment-objective,omitempty"`
	InvestmentTimeHorizon string    `json:"investment-time-horizon,omitempty"`
	IsClosed              bool      `json:"is-closed"`
	IsFirmError           bool      `json:"is-firm-error"`
	IsFirmProprietary     bool      `json:"is-firm-proprietary"`
	IsForeign             bool      `json:"is-foreign,omitempty"`
	IsFuturesApproved     bool      `json:"is-futures-approved"`
	LiquidityNeeds        string    `json:"liquidity-needs,omitempty"`
	MarginOrCash          string    `json:"margin-or-cash"`
	Nickname              string    `json:"nickname,omitempty"`
	OpenedAt              time.Time `json:"opened-at,omitempty"`
	RiskTolerance         string    `json:"risk-tolerance,omitempty"`
	SubmittingUserID      string    `json:"submitting-user-id,omitempty"`
	SuitableOptionsLevel  string    `json:"suitable-options-level,omitempty"`
}

// AccountAuthorityDecorator represents an account with authority information
type AccountAuthorityDecorator struct {
	Account        Account `json:"account"`
	AuthorityLevel string  `json:"authority-level"`
}

// AccountsResponse represents the nested response structure from the accounts endpoint
type AccountsResponse struct {
	Data struct {
		Items []AccountAuthorityDecorator `json:"items"`
	} `json:"data"`
	Context string `json:"context,omitempty"`
}

// AccountResponse represents the nested response structure for a single account
type AccountResponse struct {
	Data    Account `json:"data"`
	Context string  `json:"context,omitempty"`
}

// QuoteStreamerTokenAuthResult represents quote streamer authentication result
type QuoteStreamerTokenAuthResult struct {
	DxlinkURL    string    `json:"dxlink-url"`
	ExpiresAt    time.Time `json:"expires-at"`
	IssuedAt     time.Time `json:"issued-at"`
	Level        string    `json:"level"`
	Token        string    `json:"token"`
	WebsocketURL string    `json:"websocket-url"`
}

// QuoteTokenResponse represents the nested response structure for quote tokens
type QuoteTokenResponse struct {
	Data    QuoteStreamerTokenAuthResult `json:"data"`
	Context string                       `json:"context,omitempty"`
}

// PermittedAccountType represents an account type that a customer is permitted to open
type PermittedAccountType struct {
	Name                string       `json:"name"`
	Description         string       `json:"description"`
	IsTaxAdvantaged     bool         `json:"is_tax_advantaged"`
	HasMultipleOwners   bool         `json:"has_multiple_owners"`
	IsPubliclyAvailable bool         `json:"is_publicly_available"`
	MarginTypes         []MarginType `json:"margin_types"`
}

// MarginType represents a margin type available for an account
type MarginType struct {
	Name     string `json:"name"`
	IsMargin bool   `json:"is_margin"`
}

// Person represents personal information of a customer
type Person struct {
	ExternalID         string `json:"external-id"`
	FirstName          string `json:"first-name"`
	LastName           string `json:"last-name"`
	BirthDate          string `json:"birth-date"`
	CitizenshipCountry string `json:"citizenship-country"`
	USACitizenshipType string `json:"usa-citizenship-type"`
	EmployerName       string `json:"employer-name"`
	EmploymentStatus   string `json:"employment-status"`
	JobTitle           string `json:"job-title"`
	MaritalStatus      string `json:"marital-status"`
	NumberOfDependents int    `json:"number-of-dependents"`
	Occupation         string `json:"occupation"`
	MiddleName         string `json:"middle-name,omitempty"`
	PrefixName         string `json:"prefix-name,omitempty"`
	SuffixName         string `json:"suffix-name,omitempty"`
}

// Customer represents a TastyTrade customer with all fields from the API response
type Customer struct {
	ID                              string                 `json:"id"`
	FirstName                       string                 `json:"first-name"`
	FirstSurname                    string                 `json:"first-surname,omitempty"`
	LastName                        string                 `json:"last-name"`
	MiddleName                      string                 `json:"middle-name,omitempty"`
	PrefixName                      string                 `json:"prefix-name,omitempty"`
	SecondSurname                   string                 `json:"second-surname,omitempty"`
	SuffixName                      string                 `json:"suffix-name,omitempty"`
	Address                         Address                `json:"address"`
	CustomerSuitability             CustomerSuitability    `json:"customer-suitability"`
	MailingAddress                  Address                `json:"mailing-address"`
	IsForeign                       bool                   `json:"is-foreign"`
	RegulatoryDomain                string                 `json:"regulatory-domain"`
	USACitizenshipType              string                 `json:"usa-citizenship-type"`
	HomePhoneNumber                 string                 `json:"home-phone-number,omitempty"`
	MobilePhoneNumber               string                 `json:"mobile-phone-number,omitempty"`
	WorkPhoneNumber                 string                 `json:"work-phone-number,omitempty"`
	BirthDate                       string                 `json:"birth-date"`
	Email                           string                 `json:"email"`
	ExternalID                      string                 `json:"external-id"`
	ForeignTaxNumber                string                 `json:"foreign-tax-number,omitempty"`
	TaxNumber                       string                 `json:"tax-number"`
	TaxNumberType                   string                 `json:"tax-number-type"`
	BirthCountry                    string                 `json:"birth-country,omitempty"`
	CitizenshipCountry              string                 `json:"citizenship-country"`
	VisaExpirationDate              string                 `json:"visa-expiration-date,omitempty"`
	VisaType                        string                 `json:"visa-type,omitempty"`
	AgreedToMargining               bool                   `json:"agreed-to-margining"`
	SubjectToTaxWithholding         bool                   `json:"subject-to-tax-withholding"`
	AgreedToTerms                   bool                   `json:"agreed-to-terms"`
	SignatureOfAgreement            bool                   `json:"signature-of-agreement,omitempty"`
	DeskCustomerID                  string                 `json:"desk-customer-id,omitempty"`
	ExtCrmID                        string                 `json:"ext-crm-id,omitempty"`
	FamilyMemberNames               string                 `json:"family-member-names,omitempty"`
	Gender                          string                 `json:"gender,omitempty"`
	HasIndustryAffiliation          bool                   `json:"has-industry-affiliation"`
	HasInstitutionalAssets          string                 `json:"has-institutional-assets,omitempty"`
	HasListedAffiliation            bool                   `json:"has-listed-affiliation"`
	HasPoliticalAffiliation         bool                   `json:"has-political-affiliation"`
	IndustryAffiliationFirm         string                 `json:"industry-affiliation-firm,omitempty"`
	IsInvestmentAdviser             bool                   `json:"is-investment-adviser,omitempty"`
	ListedAffiliationSymbol         string                 `json:"listed-affiliation-symbol,omitempty"`
	PoliticalOrganization           string                 `json:"political-organization,omitempty"`
	UserID                          string                 `json:"user-id,omitempty"`
	HasDelayedQuotes                bool                   `json:"has-delayed-quotes"`
	HasPendingOrApprovedApplication bool                   `json:"has-pending-or-approved-application"`
	IsProfessional                  bool                   `json:"is-professional"`
	PermittedAccountTypes           []PermittedAccountType `json:"permitted-account-types"`
	CreatedAt                       time.Time              `json:"created-at"`
	IdentifiableType                string                 `json:"identifiable-type"`
	Person                          Person                 `json:"person"`
}

// Address represents a physical address
type Address struct {
	City        string `json:"city,omitempty"`
	Country     string `json:"country,omitempty"`
	IsDomestic  bool   `json:"is-domestic,omitempty"`
	IsForeign   bool   `json:"is-foreign,omitempty"`
	PostalCode  string `json:"postal-code,omitempty"`
	StateRegion string `json:"state-region,omitempty"`
	StreetOne   string `json:"street-one,omitempty"`
	StreetThree string `json:"street-three,omitempty"`
	StreetTwo   string `json:"street-two,omitempty"`
}

// CustomerSuitability represents customer suitability information
type CustomerSuitability struct {
	ID                              int    `json:"id,omitempty"`
	AnnualNetIncome                 int    `json:"annual-net-income,omitempty"`
	CoveredOptionsTradeExperience   string `json:"covered-options-trading-experience,omitempty"`
	CustomerID                      int    `json:"customer-id,omitempty"`
	EmployerName                    string `json:"employer-name,omitempty"`
	EmploymentStatus                string `json:"employment-status,omitempty"`
	FuturesTradeExperience          string `json:"futures-trading-experience,omitempty"`
	JobTitle                        string `json:"job-title,omitempty"`
	LiquidNetWorth                  int    `json:"liquid-net-worth,omitempty"`
	MaritalStatus                   string `json:"marital-status,omitempty"`
	NetWorth                        int    `json:"net-worth,omitempty"`
	NumberOfDependents              int    `json:"number-of-dependents,omitempty"`
	Occupation                      string `json:"occupation,omitempty"`
	StockTradeExperience            string `json:"stock-trading-experience,omitempty"`
	TaxBracket                      string `json:"tax-bracket,omitempty"`
	UncoveredOptionsTradeExperience string `json:"uncovered-options-trading-experience,omitempty"`
}

// CustomerResponse represents the nested response structure for a customer
type CustomerResponse struct {
	Data    Customer `json:"data"`
	Context string   `json:"context,omitempty"`
}

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
	IsConfirmed bool   `json:"is-confirmed"`
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
