package tastytrade

import (
	"context"
	"fmt"
	"net/url"
)

// Position represents a trading position
type Position struct {
	Symbol           string  `json:"symbol"`
	Quantity         float64 `json:"quantity"`
	CostBasis        float64 `json:"cost-basis"`
	MarkPrice        float64 `json:"mark-price"`
	InstrumentType   string  `json:"instrument-type"`
	UnderlyingSymbol string  `json:"underlying-symbol,omitempty"`
	ExpirationDate   string  `json:"expiration-date,omitempty"`
	StrikePrice      float64 `json:"strike-price,omitempty"`
	OptionType       string  `json:"option-type,omitempty"`
	MarketValue      float64 `json:"market-value"`
	// Add other fields as needed
}

// PositionsResponse represents the response for positions list
type PositionsResponse struct {
	Items []Position `json:"items"`
	PaginationData
}

// GetPositionsWithParams retrieves positions for an account with query parameters
func (c *Client) GetPositionsWithParams(ctx context.Context, accountNumber string, params url.Values) ([]Position, error) {
	if err := c.EnsureValidToken(ctx); err != nil {
		return nil, err
	}

	endpoint := fmt.Sprintf("/accounts/%s/positions", accountNumber)
	if len(params) > 0 {
		endpoint += "?" + params.Encode()
	}

	var resp PositionsResponse
	err := c.doRequest(ctx, "GET", endpoint, nil, true, &resp)
	if err != nil {
		return nil, err
	}

	return resp.Items, nil
}

// GetPositions retrieves all positions for an account
func (c *Client) GetPositions(ctx context.Context, accountNumber string) ([]Position, error) {
	return c.GetPositionsWithParams(ctx, accountNumber, nil)
}

// GetEquityPositions retrieves equity positions for an account
func (c *Client) GetEquityPositions(ctx context.Context, accountNumber string) ([]Position, error) {
	params := url.Values{}
	params.Set("instrument-type", "Equity")
	return c.GetPositionsWithParams(ctx, accountNumber, params)
}

// GetOptionPositions retrieves option positions for an account
func (c *Client) GetOptionPositions(ctx context.Context, accountNumber string) ([]Position, error) {
	params := url.Values{}
	params.Set("instrument-type", "Equity Option")
	return c.GetPositionsWithParams(ctx, accountNumber, params)
}
