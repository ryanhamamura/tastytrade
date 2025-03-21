package tastytrade

import (
	"context"
	"fmt"
	"net/url"
	"strings"
	"time"
)

// Quote represents a market quote
type Quote struct {
	Symbol        string    `json:"symbol"`
	BidPrice      float64   `json:"bid-price"`
	AskPrice      float64   `json:"ask-price"`
	LastPrice     float64   `json:"last-price"`
	BidSize       int       `json:"bid-size"`
	AskSize       int       `json:"ask-size"`
	LastSize      int       `json:"last-size"`
	Volume        int       `json:"volume"`
	OpenPrice     float64   `json:"open-price"`
	PreviousClose float64   `json:"previous-close-price"`
	DayHigh       float64   `json:"high-price"`
	DayLow        float64   `json:"low-price"`
	NetChange     float64   `json:"net-change"`
	PercentChange float64   `json:"percent-change"`
	TimeStamp     time.Time `json:"timestamp,omitempty"`
	// Add other fields as needed
}

// GetQuotes retrieves quotes for symbols
func (c *Client) GetQuotes(ctx context.Context, symbols []string) (map[string]Quote, error) {
	if err := c.EnsureValidToken(ctx); err != nil {
		return nil, err
	}

	if len(symbols) == 0 {
		return nil, fmt.Errorf("at least one symbol is required")
	}

	// Construct query string with multiple symbols
	params := url.Values{}
	params.Set("symbols", strings.Join(symbols, ","))

	endpoint := "/quotes?" + params.Encode()
	var quotes map[string]Quote
	err := c.doRequest(ctx, "GET", endpoint, nil, true, &quotes)
	if err != nil {
		return nil, err
	}

	return quotes, nil
}

// GetQuote retrieves a quote for a single symbol
func (c *Client) GetQuote(ctx context.Context, symbol string) (*Quote, error) {
	quotes, err := c.GetQuotes(ctx, []string{symbol})
	if err != nil {
		return nil, err
	}

	quote, ok := quotes[symbol]
	if !ok {
		return nil, fmt.Errorf("quote not found for symbol: %s", symbol)
	}

	return &quote, nil
}
