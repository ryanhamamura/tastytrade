package tastytrade

import (
	"encoding/json"
	"fmt"
	"strconv"
	"time"
)

// BaseInstrument contains fields common to all instrument types
type BaseInstrument struct {
	Symbol               string `json:"symbol"`
	InstrumentType       string `json:"instrument-type"`
	Description          string `json:"description,omitempty"`
	Active               bool   `json:"active"`
	IsClosingOnly        bool   `json:"is-closing-only"`
	StreamerSymbol       string `json:"streamer-symbol,omitempty"`
	MarketTimeCollection string `json:"market-time-instrument-collection,omitempty"`
}

// TickSize represents a tick size rule with an optional threshold
type TickSize struct {
	Value     string  `json:"value"`
	Threshold *string `json:"threshold,omitempty"`
}

// Equity represents equity instruments (stocks, ETFs, indices)
type Equity struct {
	BaseInstrument
	ID                           int        `json:"id,omitempty"`
	CUSIP                        string     `json:"cusip,omitempty"`
	ShortDescription             string     `json:"short-description,omitempty"`
	IsIndex                      bool       `json:"is-index"`
	IsETF                        bool       `json:"is-etf"`
	ListedMarket                 string     `json:"listed-market,omitempty"`
	Lendability                  string     `json:"lendability,omitempty"`
	BorrowRate                   string     `json:"borrow-rate,omitempty"`
	IsFractionalQuantityEligible bool       `json:"is-fractional-quantity-eligible"`
	IsIlliquid                   bool       `json:"is-illiquid"`
	TickSizes                    []TickSize `json:"tick-sizes,omitempty"`
	OptionTickSizes              []TickSize `json:"option-tick-sizes,omitempty"`
	IsOptionsClosingOnly         bool       `json:"is-options-closing-only"`
}

// EquityOption represents equity option instruments
type EquityOption struct {
	BaseInstrument
	StrikePrice       float64   `json:"-"` // Custom unmarshaling
	RootSymbol        string    `json:"root-symbol,omitempty"`
	UnderlyingSymbol  string    `json:"underlying-symbol,omitempty"`
	ExpirationDate    string    `json:"expiration-date,omitempty"`
	ExerciseStyle     string    `json:"exercise-style,omitempty"`
	SharesPerContract int       `json:"shares-per-contract,omitempty"`
	OptionType        string    `json:"option-type,omitempty"`
	OptionChainType   string    `json:"option-chain-type,omitempty"`
	ExpirationType    string    `json:"expiration-type,omitempty"`
	SettlementType    string    `json:"settlement-type,omitempty"`
	StopsTradingAt    time.Time `json:"stops-trading-at,omitempty"`
	DaysToExpiration  int       `json:"days-to-expiration,omitempty"`
	ExpiresAt         time.Time `json:"expires-at,omitempty"`
}

// UnmarshalJSON implements custom JSON unmarshaling for EquityOption
func (o *EquityOption) UnmarshalJSON(data []byte) error {
	// Use an alias to avoid infinite recursion
	type Alias EquityOption

	// Create a temporary struct with string fields for custom parsing
	aux := &struct {
		StrikePrice    string `json:"strike-price,omitempty"`
		StopsTradingAt string `json:"stops-trading-at,omitempty"`
		ExpiresAt      string `json:"expires-at,omitempty"`
		*Alias
	}{
		Alias: (*Alias)(o),
	}

	if err := json.Unmarshal(data, &aux); err != nil {
		return err
	}

	// Convert strike price string to float64
	if aux.StrikePrice != "" {
		price, err := strconv.ParseFloat(aux.StrikePrice, 64)
		if err != nil {
			return fmt.Errorf("failed to parse strike price '%s': %w", aux.StrikePrice, err)
		}
		o.StrikePrice = price
	}

	// Parse time fields
	if aux.StopsTradingAt != "" {
		t, success := parseTime(aux.StopsTradingAt, false)
		if !success {
			return fmt.Errorf("failed to parse stops-trading-at time: %s", aux.StopsTradingAt)
		}
		o.StopsTradingAt = t
	}

	if aux.ExpiresAt != "" {
		t, success := parseTime(aux.ExpiresAt, false)
		if !success {
			return fmt.Errorf("failed to parse expires-at time: %s", aux.ExpiresAt)
		}
		o.ExpiresAt = t
	}

	return nil
}

// EquityResponse represents a response containing a single equity
type EquityResponse struct {
	Data    Equity `json:"data"`
	Context string `json:"context,omitempty"`
}

// EquitiesResponse represents a response containing multiple equities
type EquitiesResponse struct {
	Data struct {
		Items []Equity `json:"items"`
	} `json:"data"`
	Context    string          `json:"context,omitempty"`
	Pagination *PaginationData `json:"pagination,omitempty"`
}

// EquityOptionResponse represents a response containing a single equity option
type EquityOptionResponse struct {
	Data    EquityOption `json:"data"`
	Context string       `json:"context,omitempty"`
}

// EquityOptionsResponse represents a response containing multiple equity options
type EquityOptionsResponse struct {
	Data struct {
		Items []EquityOption `json:"items"`
	} `json:"data"`
	Context string `json:"context,omitempty"`
}

// OptionChain represents a detailed option chain for an underlying symbol
type OptionChain struct {
	Items []EquityOption `json:"items"`
}

// OptionChainResponse represents a response containing an option chain
type OptionChainResponse struct {
	Data    OptionChain `json:"data"`
	Context string      `json:"context,omitempty"`
}

// NestedOptionStrike represents a strike price with call and put symbols
type NestedOptionStrike struct {
	StrikePrice        string `json:"strike-price"`
	Call               string `json:"call"`
	CallStreamerSymbol string `json:"call-streamer-symbol,omitempty"`
	Put                string `json:"put"`
	PutStreamerSymbol  string `json:"put-streamer-symbol,omitempty"`
}

// NestedOptionExpiration represents an expiration date with strikes
type NestedOptionExpiration struct {
	ExpirationType   string               `json:"expiration-type"`
	ExpirationDate   string               `json:"expiration-date"`
	DaysToExpiration int                  `json:"days-to-expiration"`
	SettlementType   string               `json:"settlement-type"`
	Strikes          []NestedOptionStrike `json:"strikes"`
}

// NestedOptionChain represents an option chain grouped by expiration and strike
type NestedOptionChain struct {
	UnderlyingSymbol  string                   `json:"underlying-symbol"`
	RootSymbol        string                   `json:"root-symbol"`
	OptionChainType   string                   `json:"option-chain-type"`
	SharesPerContract int                      `json:"shares-per-contract"`
	Expirations       []NestedOptionExpiration `json:"expirations"`
}

// NestedOptionChainResponse represents a response containing a nested option chain
type NestedOptionChainResponse struct {
	Data struct {
		Items []NestedOptionChain `json:"items"`
	} `json:"data"`
	Context string `json:"context,omitempty"`
}

// CompactOptionSymbols represents an option chain as a flat list of symbols
type CompactOptionSymbols struct {
	UnderlyingSymbol  string        `json:"underlying-symbol"`
	RootSymbol        string        `json:"root-symbol"`
	OptionChainType   string        `json:"option-chain-type"`
	SettlementType    string        `json:"settlement-type"`
	SharesPerContract int           `json:"shares-per-contract"`
	ExpirationType    string        `json:"expiration-type"`
	Deliverables      []interface{} `json:"deliverables,omitempty"`
	Symbols           []string      `json:"symbols"`
}

// CompactOptionChainResponse represents a response containing a compact option chain
type CompactOptionChainResponse struct {
	Data struct {
		Items []CompactOptionSymbols `json:"items"`
	} `json:"data"`
	Context string `json:"context,omitempty"`
}

// OptionExpiration represents an option expiration date with additional metadata
type OptionExpiration struct {
	ExpirationDate   string
	ExpirationType   string
	DaysToExpiration int
	SettlementType   string
}

// QuantityDecimalPrecision represents the decimal precision for instrument quantities
type QuantityDecimalPrecision struct {
	InstrumentType            string `json:"instrument-type"`
	Symbol                    string `json:"symbol,omitempty"`
	Value                     int    `json:"value"`
	MinimumIncrementPrecision int    `json:"minimum-increment-precision"`
}

// QuantityDecimalPrecisionsResponse represents a response containing quantity decimal precisions
type QuantityDecimalPrecisionsResponse struct {
	Data struct {
		Items []QuantityDecimalPrecision `json:"items"`
	} `json:"data"`
	Context string `json:"context,omitempty"`
}

// TODO: Add Future struct and related types
// TODO: Add FutureOption struct and related types
// TODO: Add Cryptocurrency struct and related types
// TODO: Add Warrant struct and related types
