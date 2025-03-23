# TastyTrade Go API Wrapper

A comprehensive, type-safe Go client for the [TastyTrade API](https://developer.tastytrade.com/). This package provides access to TastyTrade's trading platform features, including account management, market data, order placement and management, and streaming services.

## Features

- **Type-Safe API**: Strongly-typed structs matching TastyTrade's API responses
- **Authentication Management**: Built-in token handling with automatic session management
- **Account Management**: Access to customer and account details
- **Market Data**: Real-time and delayed quote functionality
- **Streaming Support**: Tools for real-time data via quote tokens
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

## Market Data

Get real-time quotes using quote tokens:

```go
// Get API quote tokens
quoteToken, err := client.GetAPIQuoteTokens(ctx)

// The quote token can be used with streaming services
fmt.Printf("Quote token: %s\n", quoteToken.Token)
fmt.Printf("Websocket URL: %s\n", quoteToken.WebsocketURL)
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

The CLI allows you to:
- Choose between sandbox and production environments
- Login with your credentials
- List accounts
- Get customer details
- Retrieve quote tokens
- And more

## Package Structure

The package is organized into logical files:

- `client.go`: Core client and authentication functionality
- `accounts.go`: Account and customer management methods
- `errors.go`: Error types and handling
- `models.go`: Shared data models and constants

## Development and Testing

### Requirements

- Go 1.23.6 or higher

### Testing

Run the tests with:

```bash
go test ./...
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Disclaimer

This package is not officially affiliated with TastyTrade. Use at your own risk.

## Contribution

Contributions are welcome! Please feel free to submit a Pull Request.
