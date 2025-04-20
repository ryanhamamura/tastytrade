# TastyTrade Go API Wrapper

A comprehensive, type-safe Go client for the [TastyTrade API](https://developer.tastytrade.com/). This package provides access to TastyTrade's trading platform features, including account management, market data, order placement and management, and instrument information.

## Features

- **Type-Safe API**: Strongly-typed structs matching TastyTrade's API responses
- **Authentication Management**: Built-in token handling with automatic session management
- **Account Management**: Access to customer and account details
- **Market Data**: Instrument data for equities and equity options
- **Order Management**: Place, modify, and cancel orders
- **Option Chain Data**: Retrieve option chains, expirations, and strikes
- **Robust Error Handling**: Detailed error types with response information
- **Context Support**: All methods accept context for timeout/cancellation
- **Debug Mode**: Optional detailed logging of API requests and responses
- **Environment Support**: Use certification (sandbox) or production environments

## Installation

```bash
go get github.com/ryanhamamura/tastytrade
```

## Quick Start

```go
package main

import (
    "context"
    "fmt"
    "log"
    "time"
    
    "github.com/ryanhamamura/tastytrade/pkg/tastytrade"
)

func main() {
    // Create a client (false = use certification/sandbox environment)
    client := tastytrade.NewClient(false)
    
    // Create context with timeout
    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()
    
    // Login with your credentials
    err := client.Login(ctx, "your-username", "your-password")
    if err != nil {
        log.Fatalf("Login failed: %v", err)
    }
    
    // Get customer information
    customer, err := client.GetCustomer(ctx, "me", false)
    if err != nil {
        log.Fatalf("Failed to get customer info: %v", err)
    }
    fmt.Printf("Logged in as: %s %s (%s)\n", customer.FirstName, customer.LastName, customer.Email)
    
    // Get user accounts
    accounts, err := client.GetCustomerAccounts(ctx, "me")
    if err != nil {
        log.Fatalf("Failed to get accounts: %v", err)
    }
    
    // Print account details
    for i, account := range accounts {
        fmt.Printf("%d. Account: %s (%s)\n", 
            i+1, 
            account.Account.AccountNumber,
            account.Account.AccountTypeName)
    }
}
```

## Authentication

The client handles authentication with the TastyTrade API. Use the `Login` method with your TastyTrade username and password:

```go
err := client.Login(ctx, "your-username", "your-password")
```

For returning users, you can use a remember-me token for authentication:

```go
err := client.LoginWithRememberMeToken(ctx, "your-username", "your-remember-me-token")
```

When finished, you can explicitly log out:

```go
err := client.Logout(ctx)
```

The client will automatically handle token validation via the `EnsureValidToken` method that's called internally by all API methods.

## Account Information

Retrieve information about customers and their accounts:

```go
// Get customer information (use "me" for the current authenticated user)
customer, err := client.GetCustomer(ctx, "me", false)

// Get all accounts for a customer
accounts, err := client.GetCustomerAccounts(ctx, "me")

// Get specific account details
account, err := client.GetCustomerAccount(ctx, "me", "your-account-number")
```

## Instruments

The package provides methods for retrieving instrument data:

### Equities

```go
// Get a single equity
equity, err := client.GetEquity(ctx, "AAPL")

// Get multiple equities
equities, err := client.GetEquities(ctx, []string{"AAPL", "MSFT", "GOOG"}, false, false, "")

// Get active equities (paginated)
equities, pagination, err := client.GetActiveEquities(ctx, "", 1, 50)
```

### Options

```go
// Get a single equity option
option, err := client.GetEquityOption(ctx, "AAPL_012123C100")

// Get multiple equity options
options, err := client.GetEquityOptions(ctx, []string{"AAPL_012123C100", "AAPL_012123P100"}, true, false)

// Get option chain for a symbol
chain, err := client.GetOptionChain(ctx, "AAPL")

// Get nested option chain grouped by expiration and strike
nestedChain, err := client.GetNestedOptionChain(ctx, "AAPL")

// Get compact option chain with symbol lists
compactChain, err := client.GetCompactOptionChain(ctx, "AAPL")

// Get active expiration dates for a symbol
expirations, err := client.GetActiveExpirations(ctx, "AAPL")
```

## Orders

Place and manage orders:

```go
// Get live orders for an account
orders, err := client.GetLiveOrders(ctx, "your-account-number")

// Search for orders with filters
params := map[string]interface{}{
    "status": "filled",
    "start-date": time.Now().AddDate(0, -1, 0),
}
orders, err := client.SearchOrders(ctx, "your-account-number", params)

// Create an order request
orderReq := tastytrade.OrderSubmitRequest{
    TimeInForce: "Day",
    OrderType:   "Limit",
    Price:       "150.00",
    PriceEffect: "Debit",
    Legs: []tastytrade.OrderLeg{
        {
            InstrumentType: "Equity",
            Symbol:         "AAPL",
            Quantity:       1,
            Action:         "Buy to Open",
        },
    },
}

// Validate an order with dry run
dryRunResp, err := client.DryRunOrder(ctx, "your-account-number", orderReq)

// Submit an order
orderResp, err := client.SubmitOrder(ctx, "your-account-number", orderReq)

// Cancel an order
cancelledOrder, err := client.CancelOrder(ctx, "your-account-number", orderId)

// Get a specific order
order, err := client.GetOrder(ctx, "your-account-number", orderId)
```

## Error Handling

The package provides detailed error types for API errors:

```go
customer, err := client.GetCustomer(ctx, "me", false)
if err != nil {
    // Check if it's an API error
    if apiErr, ok := tastytrade.IsAPIError(err); ok {
        if apiErr.IsNotFound() {
            // Handle 404 errors
            fmt.Println("Customer not found")
        } else if apiErr.IsUnauthorized() {
            // Handle authentication errors
            fmt.Println("Authentication required")
        } else if apiErr.IsForbidden() {
            // Handle permission errors
            fmt.Println("Permission denied") 
        } else {
            // Handle other API errors
            fmt.Printf("API Error: %s\n", apiErr.Error())
        }
    } else {
        // Handle other errors (connection, timeout, etc.)
        fmt.Printf("Error: %v\n", err)
    }
}
```

## Advanced Usage

### Custom HTTP Client

You can provide a custom HTTP client for the API:

```go
// Create a custom HTTP client with specific timeouts
httpClient := &http.Client{
    Timeout: 45 * time.Second,
    Transport: &http.Transport{
        TLSHandshakeTimeout:   10 * time.Second,
        ResponseHeaderTimeout: 30 * time.Second,
    },
}

// Use the client with the API
client := tastytrade.NewClient(false, tastytrade.WithHTTPClient(httpClient))
```

### Debug Mode

Enable debug logging to see all API requests and responses:

```go
// Create a client with debug mode enabled
client := tastytrade.NewClient(false, tastytrade.WithDebug(true))
```

### Environment Selection

Choose between certification (sandbox) and production environments:

```go
// Use the certification/sandbox environment (default)
client := tastytrade.NewClient(false)

// Use the production environment
client := tastytrade.NewClient(true)
```

## CLI Testing Tool

The repository includes a CLI tool for testing the API:

```bash
go run cmd/tastycli/main.go
```

The CLI provides interactive commands for:
- Choosing between sandbox and production environments
- Authentication (login/logout)
- Account and customer information
- Instrument data (equities, options, option chains)
- Order management (submit, dry run, search)

## Example Application

A simple example application is included to demonstrate API usage:

```bash
go run cmd/example/main.go
```

This example requires a `.env` file with the following variables:
- USERNAME
- PASSWORD
- ACCOUNT_NUMBER
- ENVIRONMENT (sandbox or production)

## Package Structure

The package is organized into logical files:

- `client.go`: Core client and authentication functionality
- `accounts.go`: Account and customer management methods
- `errors.go`: Error types and handling
- `models.go`: Shared data models and constants
- `instrument_models.go`: Data models for instruments
- `instruments.go`: Methods for retrieving instrument data
- `order_models.go`: Data models for orders
- `orders.go`: Methods for order management

## Development Status

Current implemented features:
- Authentication (login, logout, token management)
- Account and customer information
- Equities and equity option instrument data
- Option chains, expirations, and strike data
- Order management (submit, cancel, replace, search)

Planned features:
- Futures and futures options support
- Cryptocurrency support
- Complex order types (OCO, OTO, OTOCO)
- Warrant instrument support
- Streaming market data

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Disclaimer

This package is not officially affiliated with TastyTrade. Use at your own risk.

## Contribution

Contributions are welcome! Please feel free to submit a Pull Request.