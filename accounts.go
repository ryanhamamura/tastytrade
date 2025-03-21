package tastytrade

import (
	"context"
	"fmt"
)

// Account represents a trading account
type Account struct {
	AccountNumber string `json:"account-number"`
	Name          string `json:"nickname"`
	AccountType   string `json:"account-type"`
	IsFunded      bool   `json:"is-funded"`
	IsMargin      bool   `json:"margin-or-cash"`
	MarginStatus  string `json:"margin-status,omitempty"`
	Cryptos       bool   `json:"cryptos-enabled"`
	Futures       bool   `json:"futures-enabled"`
	Equities      bool   `json:"equities-enabled"`
	DayTrader     bool   `json:"day-trader-status"`
	OptionLevel   string `json:"option-level"`
	// Add other fields as needed
}

// AccountsResponse represents the response for accounts list
type AccountsResponse struct {
	Items []Account `json:"items"`
	PaginationData
}

// GetAccounts retrieves the user's accounts
func (c *Client) GetAccounts(ctx context.Context) ([]Account, error) {
	if err := c.EnsureValidToken(ctx); err != nil {
		return nil, err
	}

	var resp AccountsResponse
	err := c.doRequest(ctx, "GET", "/customers/me/accounts", nil, true, &resp)
	if err != nil {
		return nil, err
	}

	return resp.Items, nil
}

// BalancesResponse represents account balances
type BalancesResponse struct {
	AccountNumber          string  `json:"account-number"`
	Cash                   float64 `json:"cash"`
	LongStockValue         float64 `json:"long-stock-value"`
	ShortStockValue        float64 `json:"short-stock-value"`
	LongOptionValue        float64 `json:"long-option-value"`
	ShortOptionValue       float64 `json:"short-option-value"`
	NetLiq                 float64 `json:"net-liquidation-value"`
	BuyingPower            float64 `json:"buying-power"`
	MaintenanceRequirement float64 `json:"maintenance-requirement"`
	// Add other fields as needed
}

// GetBalances retrieves balances for an account
func (c *Client) GetBalances(ctx context.Context, accountNumber string) (*BalancesResponse, error) {
	if err := c.EnsureValidToken(ctx); err != nil {
		return nil, err
	}

	endpoint := fmt.Sprintf("/accounts/%s/balances", accountNumber)
	var balances BalancesResponse
	err := c.doRequest(ctx, "GET", endpoint, nil, true, &balances)
	if err != nil {
		return nil, err
	}

	return &balances, nil
}
