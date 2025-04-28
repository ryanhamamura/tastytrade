package tastytrade

import (
	"context"
	"fmt"
	"strings"
)

// GetPositions retrieves all positions for an account
func (c *Client) GetPositions(ctx context.Context, accountNumber string) ([]Position, error) {
	if err := c.EnsureValidToken(ctx); err != nil {
		return nil, err
	}

	endpoint := fmt.Sprintf("/accounts/%s/positions", accountNumber)
	
	var response PositionsResponse
	err := c.doRequest(ctx, "GET", endpoint, nil, true, &response)
	if err != nil {
		return nil, err
	}

	return response.Data.Items, nil
}

// GetPositionsByUnderlyingSymbol retrieves positions for a specific underlying symbol in an account
func (c *Client) GetPositionsByUnderlyingSymbol(ctx context.Context, accountNumber, underlyingSymbol string) ([]Position, error) {
	if err := c.EnsureValidToken(ctx); err != nil {
		return nil, err
	}

	// First, get all positions for the account
	positions, err := c.GetPositions(ctx, accountNumber)
	if err != nil {
		return nil, err
	}

	// Filter positions by underlying symbol
	var filteredPositions []Position
	for _, position := range positions {
		if position.UnderlyingSymbol == underlyingSymbol {
			filteredPositions = append(filteredPositions, position)
		}
	}

	return filteredPositions, nil
}

// GetPositionsByInstrumentType retrieves positions for a specific instrument type in an account
func (c *Client) GetPositionsByInstrumentType(ctx context.Context, accountNumber, instrumentType string) ([]Position, error) {
	if err := c.EnsureValidToken(ctx); err != nil {
		return nil, err
	}

	// First, get all positions for the account
	positions, err := c.GetPositions(ctx, accountNumber)
	if err != nil {
		return nil, err
	}

	// Filter positions by instrument type
	var filteredPositions []Position
	for _, position := range positions {
		if position.InstrumentType == instrumentType {
			filteredPositions = append(filteredPositions, position)
		}
	}

	return filteredPositions, nil
}

// GetOpenPositions retrieves only open positions (with non-zero quantity) for an account
func (c *Client) GetOpenPositions(ctx context.Context, accountNumber string) ([]Position, error) {
	if err := c.EnsureValidToken(ctx); err != nil {
		return nil, err
	}

	// First, get all positions for the account
	positions, err := c.GetPositions(ctx, accountNumber)
	if err != nil {
		return nil, err
	}

	// Filter out closed positions (quantity direction of Zero)
	var openPositions []Position
	for _, position := range positions {
		if position.QuantityDirection != PositionDirectionZero {
			openPositions = append(openPositions, position)
		}
	}

	return openPositions, nil
}

// SearchPositions searches for positions in an account based on various filters
// Supported filters:
// - underlying-symbol: The underlying symbol of the position
// - instrument-type: The instrument type of the position
// - quantity-direction: The direction of the position (Long, Short, Zero)
func (c *Client) SearchPositions(ctx context.Context, accountNumber string, params map[string]interface{}) ([]Position, error) {
	if err := c.EnsureValidToken(ctx); err != nil {
		return nil, err
	}

	// Since the API doesn't support query parameters for positions endpoint,
	// we'll get all positions and filter in memory

	// First, get all positions for the account
	positions, err := c.GetPositions(ctx, accountNumber)
	if err != nil {
		return nil, err
	}

	// Apply filters
	var filteredPositions []Position
	for _, position := range positions {
		include := true

		for key, value := range params {
			switch key {
			case "underlying-symbol":
				if stringVal, ok := value.(string); ok && position.UnderlyingSymbol != stringVal {
					include = false
				}
			case "instrument-type":
				if stringVal, ok := value.(string); ok && position.InstrumentType != stringVal {
					include = false
				}
			case "quantity-direction":
				if stringVal, ok := value.(string); ok && position.QuantityDirection != stringVal {
					include = false
				}
			case "symbol":
				if stringVal, ok := value.(string); ok {
					// Allow partial symbol matches
					if !strings.Contains(position.Symbol, stringVal) {
						include = false
					}
				}
			}
		}

		if include {
			filteredPositions = append(filteredPositions, position)
		}
	}

	return filteredPositions, nil
}

// PrintPosition is a utility to print detailed position information
func PrintPosition(position *Position) {
	fmt.Printf("Position: %s %s\n", position.InstrumentType, position.Symbol)
	fmt.Printf("Account: %s\n", position.AccountNumber)
	fmt.Printf("Quantity: %s (%s)\n", position.Quantity, position.QuantityDirection)
	fmt.Printf("Average Open Price: %s\n", position.AverageOpenPrice)
	fmt.Printf("Close Price: %s\n", position.ClosePrice)
	
	if position.UnderlyingSymbol != "" {
		fmt.Printf("Underlying Symbol: %s\n", position.UnderlyingSymbol)
	}
	
	fmt.Printf("Multiplier: %d\n", position.Multiplier)
	fmt.Printf("Cost Effect: %s\n", position.CostEffect)
	
	if position.RealizedDayGain != "0.0" {
		fmt.Printf("Realized Day Gain: %s (%s)\n", position.RealizedDayGain, position.RealizedDayGainEffect)
		fmt.Printf("Realized Day Gain Date: %s\n", position.RealizedDayGainDate)
	}
	
	if position.RealizedToday != "0.0" {
		fmt.Printf("Realized Today: %s (%s)\n", position.RealizedToday, position.RealizedTodayEffect)
		fmt.Printf("Realized Today Date: %s\n", position.RealizedTodayDate)
	}
	
	if !position.ExpiresAt.IsZero() {
		fmt.Printf("Expires At: %s\n", position.ExpiresAt.Format("2006-01-02"))
	}
	
	fmt.Printf("Created At: %s\n", position.CreatedAt.Format("2006-01-02 15:04:05"))
	fmt.Printf("Updated At: %s\n", position.UpdatedAt.Format("2006-01-02 15:04:05"))
}