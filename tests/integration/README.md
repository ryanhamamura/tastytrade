# TastyTrade API Integration Tests

This directory contains integration tests for the TastyTrade API wrapper. These tests validate the functionality against the actual TastyTrade API.

## Environment Setup

To run the integration tests, you need to set up a `.env` file with the required credentials:

1. Copy the example file to create your own:
   ```bash
   cp .env.example .env
   ```

2. Edit the `.env` file and fill in your TastyTrade credentials:
   ```
   RUN_INTEGRATION_TESTS=true
   TT_TEST_USERNAME=your_tastytrade_username
   TT_TEST_PASSWORD=your_tastytrade_password
   TT_TEST_ACCOUNT_NUMBER=your_account_number
   ```

It's recommended to create a dedicated test account for these tests, or at minimum use the sandbox/certification environment.

## Running Tests

Run the integration tests with:

```bash
cd tests/integration
go test -v
```

The tests are designed to skip automatically if the `RUN_INTEGRATION_TESTS` environment variable is not set to `true`. This prevents accidental test execution that could create real orders.

## Test Coverage

Current integration tests cover:

- **Limit Order Lifecycle**: Tests creation, verification, modification, and cancellation of limit orders
- **Invalid Order Handling**: Verifies that invalid orders are properly rejected

## Adding New Tests

When adding new integration tests:

1. Always use the sandbox environment when possible
2. Ensure all tests have proper cleanup (e.g., cancel any created orders)
3. Use small quantities and prices far from market to avoid accidental fills
4. Include proper error handling and informative error messages
5. Follow the convention of checking for the `RUN_INTEGRATION_TESTS` environment variable