package tastytrade

import (
	"context"
	"fmt"
	"time"
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

func PrintAccount(account *Account) {
	fmt.Println("Account Details:")
	fmt.Printf("Account Number: %s\n", account.AccountNumber)
	fmt.Printf("Type: %s\n", account.AccountTypeName)
	fmt.Printf("Nickname: %s\n", account.Nickname)
	fmt.Printf("Margin or Cash: %s\n", account.MarginOrCash)
	fmt.Printf("Created At: %s\n", account.CreatedAt.Format(time.RFC3339))
	fmt.Printf("Day Trader Status: %v\n", account.DayTraderStatus)
	fmt.Printf("Is Closed: %v\n", account.IsClosed)
	fmt.Printf("Is Futures Approved: %v\n", account.IsFuturesApproved)
	fmt.Printf("Suitable Options Level: %s\n", account.SuitableOptionsLevel)
}
