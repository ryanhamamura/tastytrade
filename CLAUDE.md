# Guidance for Claude on TastyTrade Go API Wrapper

This document provides essential information for Claude to effectively assist with the TastyTrade Go API wrapper project.

## Project Overview

This project is a comprehensive Go client for the [TastyTrade API](https://developer.tastytrade.com/), providing programmatic access to TastyTrade's trading platform. Key features include:

- Authentication and session management
- Account and customer information retrieval
- Market data for equities and options
- Order placement, modification, and management
- Instrument information (equities, options, chains)
- Strongly-typed response models

## Repository Structure

- `/pkg/tastytrade/`: Core API wrapper package
  - `client.go`: Base client, authentication, HTTP utilities
  - `accounts.go`: Account/customer functionality
  - `errors.go`: Error types and handling
  - `instrument_models.go`: Data structures for instruments
  - `instruments.go`: Instrument-related API methods
  - `models.go`: Shared models and constants
  - `order_models.go`: Order-related data structures
  - `orders.go`: Order management functionality

- `/cmd/`: Command-line tools and examples
  - `/example/`: Example application showing API usage
  - `/tastycli/`: Interactive CLI for testing the API

- `/tests/integration/`: Integration tests for API functionality

## Development Workflow

1. **Run Tests**: Most functionality has integration tests
   ```bash
   # Run integration tests with credentials in .env file
   cd tests/integration
   go test -v
   ```

2. **Manual Testing**: Use the CLI tool
   ```bash
   go run cmd/tastycli/main.go
   ```

3. **Code Style**: Follow Go best practices
   - Use error handling with context
   - Implement proper API error propagation
   - Document exported functions and types
   - Maintain consistent parameter naming

## Common Tasks

### Authentication Flow

Authentication is managed automatically by the client with `EnsureValidToken()` before each API call. Key methods:

- `client.Login(ctx, username, password)`: Initial authentication
- `client.LoginWithRememberMeToken(ctx, username, token)`: Token-based auth
- `client.Logout(ctx)`: End session

### Order Operations

Order operations follow a consistent pattern. Key methods:

- `client.SubmitOrder(ctx, accountNumber, orderReq)`: Place new order
- `client.CancelReplaceOrder(ctx, accountNumber, orderID, newOrderReq)`: Modify order
- `client.CancelOrder(ctx, accountNumber, orderID)`: Cancel order
- `client.SearchOrders(ctx, accountNumber, params)`: Find orders with filters

Note: The `CancelReplaceOrder` implementation handles the API's behavior of cancelling the original order and creating a new one, then finding the new order automatically.

### Debugging

Enable debug mode to see API requests and responses:

```go
client := tastytrade.NewClient(false, tastytrade.WithDebug(true))
```

## Testing Notes

When running integration tests:

1. Set environment variables or use `.env` file in the integration test directory:
   ```
   RUN_INTEGRATION_TESTS=true
   TT_TEST_USERNAME=your_tastytrade_username
   TT_TEST_PASSWORD=your_tastytrade_password
   TT_TEST_ACCOUNT_NUMBER=your_account_number
   ```

2. Always use small quantities and prices far from market to avoid accidental fills

3. Clean up test orders at the end of each test

4. For order search tests, use the properly URL-encoded parameters

## Common Issues and Solutions

1. **URL Encoding**: Be careful with parameters in URLs. The client properly handles query parameter encoding in `doRequest()` but any direct URL manipulation should use proper encoding.

2. **Cancel-Replace Pattern**: The API cancels the original order and creates a new one. Tests should handle this by looking for the new order after the cancel-replace call.

3. **Environment Differences**: Some API endpoints may work differently in sandbox vs production environments.

4. **Order Status Transitions**: Orders go through multiple status transitions; tests should account for various potential states.

## Future Improvements

Potential areas for enhancement:

- Add streaming market data support
- Implement futures and cryptocurrencies endpoints
- Add complex order types (OCO, OTO, OTOCO)
- Include additional examples for common trading strategies 
- Enhance error retry mechanisms for transient failures

For any modifications, ensure integration tests are updated to verify the changes.