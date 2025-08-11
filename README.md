# Tastytrade Ruby SDK (Unofficial)

[![Gem Version](https://badge.fury.io/rb/tastytrade.svg)](https://badge.fury.io/rb/tastytrade)
[![CI](https://github.com/ryanhamamura/tastytrade/actions/workflows/main.yml/badge.svg)](https://github.com/ryanhamamura/tastytrade/actions/workflows/main.yml)
[![Ruby Style Guide](https://img.shields.io/badge/code_style-rubocop-brightgreen.svg)](https://github.com/rubocop/rubocop)

> An unofficial Ruby SDK for the Tastytrade API

**⚠️ IMPORTANT DISCLAIMER**: This is an **unofficial** SDK and is not affiliated with, endorsed by, or sponsored by Tastytrade, Tastyworks, or any of their affiliates. This is an independent project created to help Ruby developers interact with the Tastytrade API.

This Ruby gem provides a simple interface to interact with the Tastytrade API, allowing you to:
- Authenticate with your Tastytrade account
- Retrieve account information and balances
- Access market data
- Place and manage orders
- Monitor positions and transactions

## Features

- Secure authentication with Tastytrade API
- Real-time market data access
- Account management and portfolio tracking
- Order placement and management with dry-run support
- Position monitoring
- Transaction history with filtering and grouping
- Buying power calculations and monitoring
- CLI with interactive mode and rich formatting

## Roadmap

See [ROADMAP.md](ROADMAP.md) for the detailed development roadmap. Track progress on our [GitHub Project Board](https://github.com/users/ryanhamamura/projects/1).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'tastytrade'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install tastytrade
```

## Configuration

### Environment Variables

The tastytrade gem supports authentication via environment variables, which is recommended for automation and CI/CD environments:

```bash
# Required for environment variable authentication
export TASTYTRADE_USERNAME="your_email@example.com"
export TASTYTRADE_PASSWORD="your_password"

# Optional environment variables
export TASTYTRADE_ENVIRONMENT="sandbox"  # Use "sandbox" for test environment
export TASTYTRADE_REMEMBER="true"        # Enable remember token

# Alternative shorter variable names
export TT_USERNAME="your_email@example.com"
export TT_PASSWORD="your_password"
export TT_ENVIRONMENT="sandbox"
export TT_REMEMBER="true"
```

When environment variables are set, the CLI will automatically use them for authentication without prompting for credentials.

## Usage

### Authentication

```ruby
require 'tastytrade'

# Create a session
session = Tastytrade::Session.new(
  username: 'your_username',
  password: 'your_password',
  remember_me: true  # Optional: enables session refresh with remember token
)

# Login
session.login

# Check if authenticated
session.authenticated? # => true

# Session will automatically refresh when expired if remember_me was enabled
```

### CLI Usage

The gem includes a command-line interface for common operations:

#### Authentication

```bash
# Login to your account interactively
tastytrade login

# Login with remember option for automatic session refresh
tastytrade login --remember

# Login using environment variables (recommended for automation)
export TASTYTRADE_USERNAME="your_email@example.com"
export TASTYTRADE_PASSWORD="your_password"
tastytrade login

# Or use shorter variable names
export TT_USERNAME="your_email@example.com"
export TT_PASSWORD="your_password"
tastytrade login

# Use sandbox environment for testing
export TASTYTRADE_ENVIRONMENT="sandbox"
tastytrade login

# Enable remember token via environment
export TASTYTRADE_REMEMBER="true"
tastytrade login

```

#### Account Operations

```bash
# View account balances
tastytrade balance

# View balances for all accounts
tastytrade balance --all

# View account positions
tastytrade positions

# Filter positions by symbol
tastytrade positions --symbol AAPL

# Filter positions by underlying symbol (for options)
tastytrade positions --underlying-symbol SPY

# View trading status and permissions
tastytrade trading_status

# View status for specific account
tastytrade trading_status --account 5WT0001

# Include closed positions
tastytrade positions --include-closed
```

#### Option Chains

```bash
# View option chain for a symbol
tastytrade option --symbol SPY

# Filter by days to expiration
tastytrade option --symbol SPY --dte 30

# Filter by expiration type
tastytrade option --symbol SPY --expiration-type weekly

# Output in different formats
tastytrade option --symbol SPY --format json    # JSON output
tastytrade option --symbol SPY --format compact # Compact view
tastytrade option --symbol SPY --format table   # Table view (default)

# Use nested chain format for more details
tastytrade option --symbol SPY --nested

# Combine filters
tastytrade option --symbol AAPL --dte 30 --expiration-type monthly
```

#### Interactive Mode

The CLI includes an interactive mode with menu-driven navigation:

```bash
# Login and enter interactive mode
tastytrade login

# Interactive features include:
# - Browse option chains with arrow key navigation
# - Select expirations and strikes interactively
# - View option details
# - Create buy/sell orders
# - Filter by various criteria
```

#### Transaction History

```bash
# View all transactions
tastytrade history

# Filter by date range
tastytrade history --start-date 2024-01-01 --end-date 2024-12-31

# Filter by symbol
tastytrade history --symbol AAPL

# Group transactions by symbol, type, or date
tastytrade history --group-by symbol
tastytrade history --group-by type
tastytrade history --group-by date

# Limit number of transactions
tastytrade history --limit 50

# Combine filters
tastytrade history --symbol AAPL --start-date 2024-01-01 --group-by date
```

#### Buying Power Status

```bash
# View buying power status
tastytrade buying_power

# View buying power for specific account
tastytrade buying_power --account 5WX12345
```

#### Order Management

##### Order Placement

```bash
# Place a limit buy order
tastytrade order place --symbol AAPL --action buy_to_open --quantity 100 --price 150.50

# Place a market order
tastytrade order place --symbol SPY --action buy_to_open --quantity 10 --type market

# Sell to close a position
tastytrade order place --symbol AAPL --action sell_to_close --quantity 100 --price 155.00

# Dry-run validation (validate without placing)
tastytrade order place --symbol MSFT --action buy_to_open --quantity 50 --price 300 --dry-run

# Skip confirmation prompt
tastytrade order place --symbol TSLA --action buy_to_open --quantity 10 --price 200 --skip-confirmation

# Supported actions:
# - buy_to_open (bto)
# - sell_to_close (stc) 
# - sell_to_open (sto)
# - buy_to_close (btc)

# Note: Orders that would use >80% of buying power will prompt for confirmation
```

##### Order Status and History

```bash
# List all live orders (open + last 24 hours)
tastytrade order list

# List orders with filters
tastytrade order list --status Live
tastytrade order list --symbol AAPL
tastytrade order list --all  # Show for all accounts

# Output orders in JSON format
tastytrade order list --format json

# Get historical orders (beyond 24 hours)
tastytrade order history
tastytrade order history --status Filled
tastytrade order history --symbol AAPL
tastytrade order history --from 2024-01-01 --to 2024-12-31
tastytrade order history --limit 100
tastytrade order history --format json

# Get details for a specific order
tastytrade order get ORDER_ID
tastytrade order get ORDER_ID --format json

# Cancel an order
tastytrade order cancel ORDER_ID
tastytrade order cancel ORDER_ID --account 5WX12345

# Replace/modify an order
tastytrade order replace ORDER_ID  # Interactive prompts for new price/quantity
tastytrade order replace ORDER_ID --price 155.00
tastytrade order replace ORDER_ID --quantity 50
```

#### Account Management

```bash
# List all accounts
tastytrade accounts

# Select an account
tastytrade select

# Check session status
tastytrade status

# Refresh session (requires remember token)
tastytrade refresh

# Logout
tastytrade logout
```

### Account Information

```ruby
# Get all accounts
accounts = Tastytrade::Models::Account.get_all(session)

# Get specific account
account = Tastytrade::Models::Account.get(session, 'account_number')

# Check account status
account.closed? # => false
account.futures_approved? # => true
```

### Account Balances

```ruby
# Get account balance
balance = account.get_balances(session)

# Access balance information
balance.cash_balance # => BigDecimal("10000.50")
balance.net_liquidating_value # => BigDecimal("42001.00")
balance.equity_buying_power # => BigDecimal("20000.00")
balance.available_trading_funds # => BigDecimal("12000.00")
balance.day_trading_buying_power # => BigDecimal("40000.00")
balance.derivative_buying_power # => BigDecimal("20000.00")

# Check buying power usage
balance.buying_power_usage_percentage # => BigDecimal("40.00")
balance.derivative_buying_power_usage_percentage # => BigDecimal("25.00")
balance.high_buying_power_usage? # => false (checks if > 80%)

# Check if sufficient buying power for order
balance.sufficient_buying_power?(15000) # => true
balance.sufficient_buying_power?(15000, buying_power_type: :derivative) # => true

# Calculate buying power impact
balance.buying_power_impact_percentage(15000) # => BigDecimal("75.00")

# Calculate totals
balance.total_equity_value # => BigDecimal("30001.00")
balance.total_derivative_value # => BigDecimal("4500.00")
balance.total_market_value # => BigDecimal("34501.00")
```

### Positions

```ruby
# Get all positions
positions = account.get_positions(session)

# Filter positions
positions = account.get_positions(session, 
  symbol: 'AAPL',
  underlying_symbol: 'AAPL',
  include_closed: false
)

# Work with positions
positions.each do |position|
  puts position.symbol
  puts position.quantity
  puts position.unrealized_pnl
  puts position.unrealized_pnl_percentage
  
  # Check position type
  position.equity? # => true
  position.option? # => false
  position.long? # => true
  position.short? # => false
end
```

### Option Chains

```ruby
# Get option chain for a symbol
chain = Tastytrade::Models::OptionChain.get_chain(session, "SPY")

# Access expirations
chain.expiration_dates.each do |date|
  options = chain.options_for_expiration(date)
  puts "#{date}: #{options.size} options"
end

# Get nested option chain with more details
nested_chain = Tastytrade::Models::NestedOptionChain.get(session, "SPY")

# Access strikes for an expiration
expiration = nested_chain.expirations.first
expiration.strikes.each do |strike|
  puts "Strike #{strike.strike_price}: Call=#{strike.call}, Put=#{strike.put}"
end

# Filter options by DTE
near_term = chain.filter_by_dte(max_dte: 30)
puts "Near-term options: #{near_term.all_options.size}"

# Filter by expiration type
weeklies = chain.weekly_expirations
monthlies = chain.monthly_expirations

# Filter by moneyness (requires current price)
current_price = BigDecimal("450")
itm_options = chain.filter_by_moneyness("ITM", current_price)
atm_strike = chain.find_atm_strike(current_price)

# Get specific strikes around ATM
focused_chain = chain.filter_by_strikes(5, current_price) # 5 strikes around ATM
```

### Order Placement

```ruby
# Create an order leg for buying stock
leg = Tastytrade::OrderLeg.new(
  action: Tastytrade::OrderAction::BUY_TO_OPEN,
  symbol: 'AAPL',
  quantity: 100
)

# Create a market order
market_order = Tastytrade::Order.new(
  type: Tastytrade::OrderType::MARKET,
  legs: leg
)

# Create a limit order
limit_order = Tastytrade::Order.new(
  type: Tastytrade::OrderType::LIMIT,
  legs: leg,
  price: 150.50  # Will be converted to BigDecimal
)

# Place the order
response = account.place_order(session, market_order)

# Dry run (simulate order without placing)
response = account.place_order(session, limit_order, dry_run: true)

# Check order response
puts response.order_id           # => "123456"
puts response.status             # => "Filled"

# Dry run orders return a BuyingPowerEffect object
if response.buying_power_effect.is_a?(Tastytrade::Models::BuyingPowerEffect)
  bp_effect = response.buying_power_effect
  puts bp_effect.buying_power_change_amount # => BigDecimal("15050.00")
  puts bp_effect.buying_power_usage_percentage # => BigDecimal("75.25")
  puts bp_effect.exceeds_threshold?(80) # => false
  puts bp_effect.debit? # => true
else
  puts response.buying_power_effect # => BigDecimal("-15050.00")
end

puts response.warnings           # => [] or warning messages
```

### Order Management

```ruby
# Get live orders (open orders + orders from last 24 hours)
orders = account.get_live_orders(session)

# Filter orders by status
live_orders = account.get_live_orders(session, status: "Live")
filled_orders = account.get_live_orders(session, status: "Filled")

# Filter orders by symbol
aapl_orders = account.get_live_orders(session, underlying_symbol: "AAPL")

# Filter by time range
recent_orders = account.get_live_orders(session,
  from_time: Time.now - 86400,  # Last 24 hours
  to_time: Time.now
)

# Work with order details
orders.each do |order|
  puts order.id                  # => "12345"
  puts order.status              # => "Live"
  puts order.underlying_symbol   # => "AAPL"
  puts order.order_type          # => "Limit"
  puts order.price               # => BigDecimal("150.50")
  
  # Check order capabilities
  puts order.cancellable?        # => true
  puts order.editable?           # => true
  puts order.terminal?           # => false
  puts order.working?            # => true
  
  # Check fill status
  puts order.remaining_quantity  # => 100
  puts order.filled_quantity     # => 0
  
  # Work with order legs
  order.legs.each do |leg|
    puts leg.symbol              # => "AAPL"
    puts leg.action              # => "Buy"
    puts leg.quantity            # => 100
    puts leg.remaining_quantity  # => 100
    puts leg.partially_filled?   # => false
  end
end

# Cancel an order
account.cancel_order(session, "12345")

# Replace an order with new parameters
new_order = Tastytrade::Order.new(
  type: Tastytrade::OrderType::LIMIT,
  legs: leg,
  price: 155.00  # New price
)
response = account.replace_order(session, "12345", new_order)
```

### Order Validation

The SDK includes comprehensive order validation to prevent submission errors and ensure orders meet all requirements before reaching the API.

#### Validation Features

```ruby
# Orders are automatically validated before submission
order = Tastytrade::Order.new(
  type: Tastytrade::OrderType::LIMIT,
  legs: leg,
  price: 150.00
)

# Validation happens automatically when placing orders
begin
  response = account.place_order(session, order)
rescue Tastytrade::OrderValidationError => e
  puts "Validation failed:"
  e.errors.each { |error| puts "  - #{error}" }
end

# You can also validate manually
order.validate!(session, account)  # Raises if invalid

# Or perform a dry-run validation
dry_run_response = order.dry_run(session, account)
puts dry_run_response.buying_power_effect
puts dry_run_response.warnings
```

#### Validation Rules

The following validations are performed:

1. **Symbol Validation**
   - Verifies symbol exists and is tradeable
   - Checks instrument type compatibility

2. **Quantity Validation**
   - Minimum quantity: 1
   - Maximum quantity: 999,999
   - No fractional shares (whole numbers only)

3. **Price Validation**
   - Price must be positive for limit orders
   - Price is rounded to appropriate tick size
   - Price reasonableness checks

4. **Account Permissions**
   - Validates trading permissions for instrument type
   - Checks for account restrictions (frozen, closing-only, etc.)
   - Verifies options/futures permissions if applicable

5. **Buying Power Validation**
   - Ensures sufficient buying power via dry-run
   - Warns if order uses >50% of available buying power
   - Checks margin requirements

6. **Market Hours Validation**
   - Warns about market orders outside regular hours
   - Alerts for weekend submissions

#### Validation Errors

```ruby
# Specific validation error types
Tastytrade::OrderValidationError     # General validation failure
Tastytrade::InvalidSymbolError       # Symbol doesn't exist
Tastytrade::InsufficientBuyingPowerError  # Not enough buying power
Tastytrade::AccountRestrictedError   # Account has restrictions
Tastytrade::InvalidQuantityError     # Quantity out of range
Tastytrade::InvalidPriceError        # Price validation failure
Tastytrade::MarketClosedError        # Market is closed
```

#### Using the OrderValidator

```ruby
# Direct use of OrderValidator for custom validation
validator = Tastytrade::OrderValidator.new(session, account, order)

# Perform full validation
validator.validate!  # Raises if invalid

# Or just dry-run validation
dry_run_response = validator.dry_run_validate!

# Check warnings and errors
puts validator.warnings  # Array of warning messages
puts validator.errors    # Array of error messages
```

#### Skip Validation (Use with Caution)

```ruby
# Skip validation when you're certain the order is valid
response = account.place_order(session, order, skip_validation: true)
```

### Transaction History

```ruby
# Get all transactions
transactions = account.get_transactions(session)

# Filter transactions
transactions = account.get_transactions(session,
  start_date: Date.new(2024, 1, 1),
  end_date: Date.new(2024, 12, 31),
  symbol: 'AAPL',
  transaction_types: ['Trade'],
  per_page: 100
)

# Work with transactions
transactions.each do |transaction|
  puts transaction.symbol               # => "AAPL"
  puts transaction.transaction_type     # => "Trade"
  puts transaction.transaction_sub_type # => "Buy"
  puts transaction.quantity             # => BigDecimal("100")
  puts transaction.price                # => BigDecimal("150.00")
  puts transaction.value                # => BigDecimal("-15000.00")
  puts transaction.net_value            # => BigDecimal("-15007.00")
  puts transaction.executed_at          # => Time object
  
  # Fee breakdown
  puts transaction.commission           # => BigDecimal("5.00")
  puts transaction.clearing_fees        # => BigDecimal("1.00")
  puts transaction.regulatory_fees      # => BigDecimal("0.50")
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies and verify your environment is configured correctly.

Run tests with:
```bash
bundle exec rake spec
```

Run linting with:
```bash
bundle exec rake rubocop
```

For an interactive console:
```bash
bin/console
```

To install this gem onto your local machine:
```bash
bundle exec rake install
```

## Documentation

TODO: Add links to additional documentation
- [API Documentation](https://rubydoc.info/gems/tastytrade)
- [Wiki](https://github.com/ryanhamamura/tastytrade/wiki)

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ryanhamamura/tastytrade. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/ryanhamamura/tastytrade/blob/main/CODE_OF_CONDUCT.md).

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## Security

Please see our [security policy](SECURITY.md) for reporting vulnerabilities.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Tastytrade project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/ryanhamamura/tastytrade/blob/main/CODE_OF_CONDUCT.md).

## Legal Disclaimer

**⚠️ IMPORTANT FINANCIAL DISCLAIMER**

This software is provided for educational and informational purposes only. It is not intended to be used as financial advice, investment advice, or as a recommendation to buy, sell, or hold any securities or financial instruments.

**TRADING RISKS**: Trading securities, options, futures, and other financial instruments involves substantial risk of loss and is not suitable for all investors. Past performance is not indicative of future results. You may lose some or all of your invested capital.

**NO WARRANTY**: This software is provided "as is" without warranty of any kind, either express or implied, including but not limited to the implied warranties of merchantability, fitness for a particular purpose, or non-infringement.

**YOUR RESPONSIBILITY**: You are solely responsible for any investment and trading decisions you make using this software. You should consult with a qualified financial advisor before making any investment decisions.

**API USAGE**: By using this SDK, you are responsible for complying with Tastytrade's Terms of Service and API usage guidelines. Excessive API usage may result in rate limiting or account suspension by Tastytrade.

**NOT AFFILIATED**: This project is not affiliated with, endorsed by, or sponsored by Tastytrade, Tastyworks, or any of their affiliates. All trademarks and registered trademarks are the property of their respective owners.

The authors and contributors of this software shall not be held liable for any losses, damages, or costs of any kind arising from the use of this software.
