package tastytrade

import (
	"time"
)

// Position represents a position in an account
type Position struct {
	AccountNumber               string    `json:"account-number"`
	Symbol                      string    `json:"symbol"`
	InstrumentType              string    `json:"instrument-type"`
	UnderlyingSymbol            string    `json:"underlying-symbol,omitempty"`
	Quantity                    string    `json:"quantity"`
	QuantityDirection           string    `json:"quantity-direction"`
	ClosePrice                  string    `json:"close-price"`
	AverageOpenPrice            string    `json:"average-open-price"`
	AverageYearlyMarketClosePrice string    `json:"average-yearly-market-close-price"`
	AverageDailyMarketClosePrice  string    `json:"average-daily-market-close-price"`
	Multiplier                  int       `json:"multiplier"`
	CostEffect                  string    `json:"cost-effect"`
	IsSuppressed                bool      `json:"is-suppressed"`
	IsFrozen                    bool      `json:"is-frozen"`
	RestrictedQuantity          string    `json:"restricted-quantity"`
	RealizedDayGain             string    `json:"realized-day-gain"`
	RealizedDayGainEffect       string    `json:"realized-day-gain-effect"`
	RealizedDayGainDate         string    `json:"realized-day-gain-date,omitempty"`
	RealizedToday               string    `json:"realized-today"`
	RealizedTodayEffect         string    `json:"realized-today-effect"`
	RealizedTodayDate           string    `json:"realized-today-date,omitempty"`
	ExpiresAt                   time.Time `json:"expires-at,omitempty"`
	CreatedAt                   time.Time `json:"created-at,omitempty"`
	UpdatedAt                   time.Time `json:"updated-at,omitempty"`
}

// PositionsResponse represents a response containing multiple positions
type PositionsResponse struct {
	Data struct {
		Items []Position `json:"items"`
	} `json:"data"`
	Pagination *PaginationData `json:"pagination,omitempty"`
	Context    string          `json:"context,omitempty"`
}

// PositionResponse represents a response containing a single position
type PositionResponse struct {
	Data    Position `json:"data"`
	Context string   `json:"context,omitempty"`
}

// Direction types for position quantity
const (
	PositionDirectionLong  = "Long"
	PositionDirectionShort = "Short"
	PositionDirectionZero  = "Zero"
)

// Effect types for cost and gain effects
const (
	EffectCredit = "Credit"
	EffectDebit  = "Debit"
	EffectNone   = "None"
)