# TastyTrade Go API Wrapper

A comprehensive, type-safe Go client for the [TastyTrade API](https://developer.tastytrade.com/). This package provides access to TastyTrade's trading platform features, including account management, market data, order placement and management, and streaming services.

## Features

- **Type-Safe API**: Strongly-typed interfaces matching TastyTrade's API requirements
- **Authentication Management**: Built-in token refresh and session handling
- **Comprehensive Order Support**: All order types supported including complex orders
- **Streaming Support**: Tools for real-time market data and account updates
- **Robust Error Handling**: Detailed error types and validation
- **Context Support**: All methods accept context for timeout/cancellation
- **Helper Methods**: Convenience functions for common operations

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
    
    "github.com/ryanhamamura/tastytrade"
)

func main() {
    // Create a client (false = use certification environment)
    client := tastytrade.NewClient(false)
    
    // Create context with timeout
    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()
    
    // Login with your credentials
    err := client.Login(ctx, "your-username", "your-password")
    if err != nil {
        log.Fatalf("Login failed: %v", err)
    }
    
    // Get user accounts
    accounts, err := client.GetAccounts(ctx)
    if err != nil {
        log.Fatalf("Failed to get accounts: %v", err)
    }
    
    // Print account details
    for _, account := range accounts {
        fmt.Printf("Account: %s (%s)\n", account.Name, account.AccountNumber)
    }
    
    // Get quotes for symbols
    quotes, err := client.GetQuotes(ctx, []string{"AAPL", "SPY", "TSLA"})
    if err != nil {
        log.Fatalf("Failed to get quotes: %v", err)
    }
    
    // Print quote data
    for symbol, quote := range quotes {
        fmt.Printf("%s: Last Price: $%.2f\n", symbol, quote.LastPrice)
    }
}
```

## Authentication

The client handles authentication and token refresh automatically. Simply use the `Login` method with your TastyTrade username and password:

```go
err := client.Login(ctx, "your-username", "your-password")
```

The client will store the session token and refresh it automatically when needed via the `EnsureValidToken` method that's called internally by all API methods.

## Account Information

Get information about user accounts and their balances:

```go
// Get all accounts
accounts, err := client.GetAccounts(ctx)

// Get account balances
balances, err := client.GetBalances(ctx, accountNumber)

// Get account positions
positions, err := client.GetPositions(ctx, accountNumber)
```

## Market Data

Retrieve quotes, option chains, and other market data:

```go
// Get quotes for multiple symbols
quotes, err := client.GetQuotes(ctx, []string{"AAPL", "SPY", "TSLA"})

// Get option chain for a symbol
chains, err := client.GetOptionChain(ctx, "AAPL")

// Get quote for a single symbol
quote, err := client.GetQuote(ctx, "AAPL")
```

## Order Placement

The package supports all TastyTrade order types including market, limit, stop, stop-limit, and notional market orders.

### Basic Order Placement

```go
// Place a market order (using helper method)
resp, err := client.PlaceEquityMarketOrder(
    ctx,
    accountNumber,
    "AAPL",
    5, // 5 shares
    tastytrade.OrderDirectionBuyToOpen,
)

// Place a limit order
quantity := 10.0
price := 150.0
priceEffect := tastytrade.PriceEffectDebit

order := tastytrade.OrderRequest{
    OrderType:   tastytrade.OrderTypeLimit,
    TimeInForce: tastytrade.TimeInForceDay,
    Price:       &price,
    PriceEffect: &priceEffect,
    Legs: []tastytrade.OrderLeg{
        {
            Symbol:         "AAPL",
            Quantity:       &quantity,
            Action:         tastytrade.OrderDirectionBuyToOpen,
            InstrumentType: tastytrade.InstrumentTypeEquity,
        },
    },
}

resp, err := client.PlaceOrder(ctx, accountNumber, order)
```

### Fractional Share Orders (Notional Market Orders)

```go
// Place a notional market order (dollar-based)
resp, err := client.PlaceEquityNotionalMarketOrder(
    ctx,
    accountNumber,
    "AAPL",
    100.0, // $100 worth of shares
    tastytrade.OrderDirectionBuyToOpen,
)
```

### Option Strategies

```go
// Place a vertical call spread
resp, err := client.PlaceEquityOptionSpreadOrder(
    ctx,
    accountNumber,
    "AAPL  230721C00190000", // Sell the $190 call
    "AAPL  230721C00195000", // Buy the $195 call
    1.0,                     // 1 contract (represents 100 shares)
    1.25,                    // $1.25 credit ($125 total)
    tastytrade.TimeInForceDay,
)
```

### Complex Orders (OTOCO, OCO)

```go
// Build a One-Triggers-OCO (OTOCO) order
// First create the entry order
triggerOrder := tastytrade.OrderRequest{
    OrderType:   tastytrade.OrderTypeLimit,
    TimeInForce: tastytrade.TimeInForceDay,
    Price:       &entryPrice,
    PriceEffect: &entryPriceEffect,
    Legs: []tastytrade.OrderLeg{
        {
            Symbol:         "AAPL",
            Quantity:       &entryQty,
            Action:         tastytrade.OrderDirectionBuyToOpen,
            InstrumentType: tastytrade.InstrumentTypeEquity,
        },
    },
}

// Create the profit target and stop loss orders
// ... (see examples in documentation)

// Bundle them into a complex order
complexOrder := tastytrade.ComplexOrderRequest{
    Type:         tastytrade.ComplexOrderTypeOTOCO,
    TriggerOrder: &triggerOrder,
    Orders:       []tastytrade.OrderRequest{profitOrder, stopOrder},
}

// Place the complex order
resp, err := client.PlaceComplexOrder(ctx, accountNumber, complexOrder)
```

### Order Validation

Validate orders before submission:

```go
// Dry-run to validate an order
dryRunResp, err := client.DryRunOrder(ctx, accountNumber, order)
if err != nil {
    log.Fatalf("Order validation failed: %v", err)
}

// Check for warnings
if len(dryRunResp.Warnings) > 0 {
    fmt.Println("Order has warnings:")
    for _, warning := range dryRunResp.Warnings {
        fmt.Printf("- %s\n", warning)
    }
}
```

## Order Management

Manage existing orders:

```go
// Get all orders for an account
orders, err := client.GetOrders(ctx, accountNumber)

// Get a specific order
order, err := client.GetOrder(ctx, accountNumber, orderID)

// Cancel an order
err := client.CancelOrder(ctx, accountNumber, orderID)
```

## Error Handling

The package provides detailed error types for API errors:

```go
resp, err := client.PlaceOrder(ctx, accountNumber, order)
if err != nil {
    // Check if it's an API error
    if apiErr, ok := tastytrade.IsAPIError(err); ok {
        if apiErr.IsNotFound() {
            // Handle 404 errors
        } else if apiErr.IsUnauthorized() {
            // Handle authentication errors
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

## Package Structure

The package is organized into logical files:

- `client.go`: Core client and authentication functionality
- `accounts.go`: Account management methods
- `positions.go`: Position retrieval methods
- `orders.go`: Order management and placement
- `quotes.go`: Market data methods
- `options.go`: Option chain functionality
- `models.go`: Shared data models
- `errors.go`: Error types and handling

## Development and Testing

### Testing

Run the tests with:

```bash
go test ./...
```

### Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Disclaimer

This package is not officially affiliated with TastyTrade. Use at your own risk.
