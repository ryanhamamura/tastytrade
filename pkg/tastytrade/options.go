package tastytrade

import (
	"context"
	"net/url"
)

// OptionChain represents an option chain
type OptionChain struct {
	Symbol         string           `json:"symbol"`
	ExpirationDate string           `json:"expiration-date"`
	Calls          []OptionContract `json:"calls"`
	Puts           []OptionContract `json:"puts"`
}

// OptionContract represents an option contract
type OptionContract struct {
	Symbol         string  `json:"symbol"`
	StrikePrice    float64 `json:"strike-price"`
	BidPrice       float64 `json:"bid-price"`
	AskPrice       float64 `json:"ask-price"`
	Delta          float64 `json:"delta,omitempty"`
	Gamma          float64 `json:"gamma,omitempty"`
	Theta          float64 `json:"theta,omitempty"`
	Vega           float64 `json:"vega,omitempty"`
	ImpliedVol     float64 `json:"implied-volatility,omitempty"`
	OpenInterest   int     `json:"open-interest"`
	Volume         int     `json:"volume"`
	InTheMoney     bool    `json:"in-the-money"`
	ExpirationDate string  `json:"expiration-date"`
	OptionType     string  `json:"option-type"` // Call or Put
	// Add other fields as needed
}

// GetOptionChain retrieves an option chain for a symbol
func (c *Client) GetOptionChain(ctx context.Context, symbol string) ([]OptionChain, error) {
	if err := c.EnsureValidToken(ctx); err != nil {
		return nil, err
	}

	params := url.Values{}
	params.Set("symbol", symbol)

	endpoint := "/option-chains?" + params.Encode()
	var chains []OptionChain
	err := c.doRequest(ctx, "GET", endpoint, nil, true, &chains)
	if err != nil {
		return nil, err
	}

	return chains, nil
}

// GetExpirations retrieves available expiration dates for a symbol
func (c *Client) GetExpirations(ctx context.Context, symbol string) ([]string, error) {
	chains, err := c.GetOptionChain(ctx, symbol)
	if err != nil {
		return nil, err
	}

	expirations := make([]string, 0, len(chains))
	for _, chain := range chains {
		expirations = append(expirations, chain.ExpirationDate)
	}

	return expirations, nil
}

// GetOptionStrikes retrieves available strike prices for a symbol and expiration
func (c *Client) GetOptionStrikes(ctx context.Context, symbol, expiration string) ([]float64, error) {
	chains, err := c.GetOptionChain(ctx, symbol)
	if err != nil {
		return nil, err
	}

	// Find the chain for the specified expiration
	var targetChain *OptionChain
	for _, chain := range chains {
		if chain.ExpirationDate == expiration {
			targetChain = &chain
			break
		}
	}

	if targetChain == nil {
		return nil, nil // No strikes found for this expiration
	}

	// Get unique strikes from both calls and puts
	strikeMap := make(map[float64]struct{})
	for _, call := range targetChain.Calls {
		strikeMap[call.StrikePrice] = struct{}{}
	}

	for _, put := range targetChain.Puts {
		strikeMap[put.StrikePrice] = struct{}{}
	}

	strikes := make([]float64, 0, len(strikeMap))
	for strike := range strikeMap {
		strikes = append(strikes, strike)
	}

	return strikes, nil
}
