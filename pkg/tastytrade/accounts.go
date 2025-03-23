package tastytrade

import (
	"context"
	"fmt"
)

// GetAPIQuoteTokens retrieves API quote tokens for market data
func (c *Client) GetAPIQuoteTokens(ctx context.Context) (*QuoteStreamerTokenAuthResult, error) {
	if err := c.EnsureValidToken(ctx); err != nil {
		return nil, err
	}

	var response QuoteTokenResponse
	err := c.doRequest(ctx, "GET", "/api-quote-tokens", nil, true, &response)
	if err != nil {
		return nil, err
	}

	return &response.Data, nil
}

// GetCustomerAccounts retrieves accounts for a specific customer
func (c *Client) GetCustomerAccounts(ctx context.Context, customerID string) ([]AccountAuthorityDecorator, error) {
	if err := c.EnsureValidToken(ctx); err != nil {
		return nil, err
	}

	endpoint := fmt.Sprintf("/customers/%s/accounts", customerID)
	var response AccountsResponse
	err := c.doRequest(ctx, "GET", endpoint, nil, true, &response)
	if err != nil {
		return nil, err
	}

	return response.Data.Items, nil
}

// GetCustomerAccount retrieves a specific account for a customer
func (c *Client) GetCustomerAccount(ctx context.Context, customerID string, accountNumber string) (*Account, error) {
	if err := c.EnsureValidToken(ctx); err != nil {
		return nil, err
	}

	endpoint := fmt.Sprintf("/customers/%s/accounts/%s", customerID, accountNumber)
	var response AccountResponse
	err := c.doRequest(ctx, "GET", endpoint, nil, true, &response)
	if err != nil {
		return nil, err
	}

	return &response.Data, nil
}

// GetCustomer retrieves customer information
func (c *Client) GetCustomer(ctx context.Context, customerID string, allowMissing bool) (*Customer, error) {
	if err := c.EnsureValidToken(ctx); err != nil {
		return nil, err
	}

	endpoint := fmt.Sprintf("/customers/%s", customerID)
	if allowMissing {
		endpoint += "?allow-missing=true"
	}

	var response CustomerResponse
	err := c.doRequest(ctx, "GET", endpoint, nil, true, &response)
	if err != nil {
		return nil, err
	}

	return &response.Data, nil
}
