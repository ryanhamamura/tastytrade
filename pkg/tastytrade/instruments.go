package tastytrade

import (
	"context"
	"fmt"
	"net/url"
	"sort"
	"time"
)

// GetEquity retrieves a single equity by symbol
func (c *Client) GetEquity(ctx context.Context, symbol string) (*Equity, error) {
	if err := c.EnsureValidToken(ctx); err != nil {
		return nil, err
	}

	// Escape the symbol for URL safety
	encodedSymbol := url.PathEscape(symbol)
	endpoint := fmt.Sprintf("/instruments/equities/%s", encodedSymbol)

	var response EquityResponse
	err := c.doRequest(ctx, "GET", endpoint, nil, true, &response)
	if err != nil {
		return nil, err
	}

	return &response.Data, nil
}

// GetEquities retrieves a list of equities by symbols
func (c *Client) GetEquities(ctx context.Context, symbols []string, isETF, isIndex bool, lendability string) ([]Equity, error) {
	if err := c.EnsureValidToken(ctx); err != nil {
		return nil, err
	}

	// Build query parameters
	params := url.Values{}

	// Add symbols to query params
	for _, symbol := range symbols {
		params.Add("symbol[]", symbol)
	}

	// Add optional filters
	if isETF {
		params.Add("is-etf", "true")
	}

	if isIndex {
		params.Add("is-index", "true")
	}

	if lendability != "" {
		params.Add("lendability", lendability)
	}

	endpoint := fmt.Sprintf("/instruments/equities?%s", params.Encode())

	var response EquitiesResponse
	err := c.doRequest(ctx, "GET", endpoint, nil, true, &response)
	if err != nil {
		return nil, err
	}

	return response.Data.Items, nil
}

// GetActiveEquities retrieves a paginated list of active equities
func (c *Client) GetActiveEquities(ctx context.Context, lendability string, page, perPage int) ([]Equity, *PaginationData, error) {
	if err := c.EnsureValidToken(ctx); err != nil {
		return nil, nil, err
	}

	// Build query parameters
	params := url.Values{}

	if lendability != "" {
		params.Add("lendability", lendability)
	}

	// Add pagination params
	if perPage > 0 {
		params.Add("per-page", fmt.Sprintf("%d", perPage))
	}

	if page > 0 {
		params.Add("page-offset", fmt.Sprintf("%d", page))
	}

	endpoint := fmt.Sprintf("/instruments/equities/active?%s", params.Encode())

	var response EquitiesResponse
	err := c.doRequest(ctx, "GET", endpoint, nil, true, &response)
	if err != nil {
		return nil, nil, err
	}

	return response.Data.Items, response.Pagination, nil
}

// GetEquityOption retrieves a single equity option by symbol
func (c *Client) GetEquityOption(ctx context.Context, symbol string) (*EquityOption, error) {
	if err := c.EnsureValidToken(ctx); err != nil {
		return nil, err
	}

	// Escape the symbol for URL safety
	encodedSymbol := url.PathEscape(symbol)
	endpoint := fmt.Sprintf("/instruments/equity-options/%s", encodedSymbol)

	var response EquityOptionResponse
	err := c.doRequest(ctx, "GET", endpoint, nil, true, &response)
	if err != nil {
		return nil, err
	}

	return &response.Data, nil
}

// GetEquityOptions retrieves a list of equity options by symbols
func (c *Client) GetEquityOptions(ctx context.Context, symbols []string, activeOnly, withExpired bool) ([]EquityOption, error) {
	if err := c.EnsureValidToken(ctx); err != nil {
		return nil, err
	}

	// Build query parameters
	params := url.Values{}

	// Add symbols to query params
	for _, symbol := range symbols {
		params.Add("symbol[]", symbol)
	}

	// Add optional filters
	if activeOnly {
		params.Add("active", "true")
	}

	if withExpired {
		params.Add("with-expired", "true")
	}

	endpoint := fmt.Sprintf("/instruments/equity-options?%s", params.Encode())

	var response EquityOptionsResponse
	err := c.doRequest(ctx, "GET", endpoint, nil, true, &response)
	if err != nil {
		return nil, err
	}

	return response.Data.Items, nil
}

// GetOptionChain retrieves detailed equity option chain for an underlying symbol
func (c *Client) GetOptionChain(ctx context.Context, symbol string) ([]EquityOption, error) {
	if err := c.EnsureValidToken(ctx); err != nil {
		return nil, err
	}

	// Escape the symbol for URL safety
	encodedSymbol := url.PathEscape(symbol)
	endpoint := fmt.Sprintf("/option-chains/%s", encodedSymbol)

	var response OptionChainResponse
	err := c.doRequest(ctx, "GET", endpoint, nil, true, &response)
	if err != nil {
		return nil, err
	}

	return response.Data.Items, nil
}

// GetNestedOptionChain retrieves a nested option chain grouped by expiration and strike
func (c *Client) GetNestedOptionChain(ctx context.Context, symbol string) ([]NestedOptionChain, error) {
	if err := c.EnsureValidToken(ctx); err != nil {
		return nil, err
	}

	// Escape the symbol for URL safety
	encodedSymbol := url.PathEscape(symbol)
	endpoint := fmt.Sprintf("/option-chains/%s/nested", encodedSymbol)

	var response NestedOptionChainResponse
	err := c.doRequest(ctx, "GET", endpoint, nil, true, &response)
	if err != nil {
		return nil, err
	}

	return response.Data.Items, nil
}

// GetCompactOptionChain retrieves a compact option chain with symbol lists
func (c *Client) GetCompactOptionChain(ctx context.Context, symbol string) ([]CompactOptionSymbols, error) {
	if err := c.EnsureValidToken(ctx); err != nil {
		return nil, err
	}

	// Escape the symbol for URL safety
	encodedSymbol := url.PathEscape(symbol)
	endpoint := fmt.Sprintf("/option-chains/%s/compact", encodedSymbol)

	var response CompactOptionChainResponse
	err := c.doRequest(ctx, "GET", endpoint, nil, true, &response)
	if err != nil {
		return nil, err
	}

	return response.Data.Items, nil
}

// GetActiveExpirations returns available expiration dates for options on a symbol
func (c *Client) GetActiveExpirations(ctx context.Context, symbol string) ([]OptionExpiration, error) {
	chains, err := c.GetNestedOptionChain(ctx, symbol)
	if err != nil {
		return nil, err
	}

	// Use a map to avoid duplicates, with the expiration date as key
	expirationMap := make(map[string]OptionExpiration)

	for _, chain := range chains {
		for _, exp := range chain.Expirations {
			// Only add if we haven't seen this expiration date yet
			if _, exists := expirationMap[exp.ExpirationDate]; !exists {
				expirationMap[exp.ExpirationDate] = OptionExpiration{
					ExpirationDate:   exp.ExpirationDate,
					ExpirationType:   exp.ExpirationType,
					DaysToExpiration: exp.DaysToExpiration,
					SettlementType:   exp.SettlementType,
				}
			}
		}
	}

	// Convert to slice
	expirations := make([]OptionExpiration, 0, len(expirationMap))
	for _, exp := range expirationMap {
		expirations = append(expirations, exp)
	}

	// Sort dates in chronological order (closest first)
	sort.Slice(expirations, func(i, j int) bool {
		// Parse dates in YYYY-MM-DD format
		// If parsing fails, we'll use string comparison as fallback
		dateI, errI := time.Parse("2006-01-02", expirations[i].ExpirationDate)
		dateJ, errJ := time.Parse("2006-01-02", expirations[j].ExpirationDate)

		if errI == nil && errJ == nil {
			// If both parse successfully, compare dates
			return dateI.Before(dateJ)
		}

		// Fallback to string comparison
		return expirations[i].ExpirationDate < expirations[j].ExpirationDate
	})
	return expirations, nil
}

// GetQuantityDecimalPrecisions retrieves precision settings for instrument quantities
func (c *Client) GetQuantityDecimalPrecisions(ctx context.Context) ([]QuantityDecimalPrecision, error) {
	if err := c.EnsureValidToken(ctx); err != nil {
		return nil, err
	}

	endpoint := "/instruments/quantity-decimal-precisions"

	var response QuantityDecimalPrecisionsResponse
	err := c.doRequest(ctx, "GET", endpoint, nil, true, &response)
	if err != nil {
		return nil, err
	}

	return response.Data.Items, nil
}

// TODO: Implement Future-related methods
// TODO: Implement FutureOption-related methods
// TODO: Implement Cryptocurrency-related methods
// TODO: Implement Warrant-related methods
