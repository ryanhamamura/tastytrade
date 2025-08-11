# Option Order Placement Guide

This guide demonstrates how to use the tastytrade Ruby gem to place option orders and create multi-leg strategies.

## Prerequisites

```ruby
require 'tastytrade'

# Create session and authenticate
session = Tastytrade::Session.new
session.login(username: ENV['TASTYTRADE_USERNAME'], password: ENV['TASTYTRADE_PASSWORD'])

# Get account
account = Tastytrade::Models::Account.get(session, ENV['TASTYTRADE_ACCOUNT'])

# Create option order builder
builder = Tastytrade::OptionOrderBuilder.new(session, account)
```

## Single-Leg Option Orders

### Buy Call Option

```ruby
# Get the option contract
call_option = Tastytrade::Models::Option.get(session, "AAPL 240119C00150000")

# Create buy call order
order = builder.buy_call(call_option, quantity: 1, price: BigDecimal("2.50"))

# Place the order
response = account.place_order(session, order)
```

### Sell Put Option

```ruby
# Get the option contract
put_option = Tastytrade::Models::Option.get(session, "AAPL 240119P00145000")

# Create sell put order
order = builder.sell_put(put_option, quantity: 1, price: BigDecimal("3.00"))

# Place the order with validation
response = account.place_order(session, order)
```

### Close an Existing Position

```ruby
# Get the option you own
option = Tastytrade::Models::Option.get(session, "AAPL 240119C00150000")

# Create closing order (automatically detects if you need to sell or buy to close)
order = builder.close_position(option, quantity: 1, price: BigDecimal("3.50"))

# Place the order
response = account.place_order(session, order)
```

## Multi-Leg Strategies

### Vertical Spread (Bull Call Spread)

```ruby
# Get the options for the spread
long_call = Tastytrade::Models::Option.get(session, "AAPL 240119C00150000")
short_call = Tastytrade::Models::Option.get(session, "AAPL 240119C00155000")

# Create vertical spread order
order = builder.vertical_spread(
  long_call,
  short_call,
  quantity: 1,
  price: BigDecimal("1.00")  # Net debit
)

# Place the order
response = account.place_order(session, order)
```

### Iron Condor

```ruby
# Get all four options for the iron condor
put_short = Tastytrade::Models::Option.get(session, "SPY 240119P00440000")
put_long = Tastytrade::Models::Option.get(session, "SPY 240119P00435000")
call_short = Tastytrade::Models::Option.get(session, "SPY 240119C00460000")
call_long = Tastytrade::Models::Option.get(session, "SPY 240119C00465000")

# Create iron condor order
order = builder.iron_condor(
  put_short,
  put_long,
  call_short,
  call_long,
  quantity: 1,
  price: BigDecimal("2.00")  # Net credit
)

# Place the order
response = account.place_order(session, order)
```

### Strangle

```ruby
# Get put and call options with different strikes
put_option = Tastytrade::Models::Option.get(session, "AAPL 240119P00145000")
call_option = Tastytrade::Models::Option.get(session, "AAPL 240119C00155000")

# Create long strangle
order = builder.strangle(
  put_option,
  call_option,
  quantity: 1,
  action: Tastytrade::OrderAction::BUY_TO_OPEN,
  price: BigDecimal("5.00")
)

# Create short strangle
order = builder.strangle(
  put_option,
  call_option,
  quantity: 1,
  action: Tastytrade::OrderAction::SELL_TO_OPEN,
  price: BigDecimal("5.00")
)
```

### Straddle

```ruby
# Create straddle at specific strike
option_strike = { symbol: "AAPL", strike: 150 }
expiration = Date.new(2024, 1, 19)

# Create long straddle
order = builder.straddle(
  option_strike,
  expiration,
  quantity: 1,
  action: Tastytrade::OrderAction::BUY_TO_OPEN,
  price: BigDecimal("7.00")
)

# Place the order
response = account.place_order(session, order)
```

## Order Validation

All option orders are automatically validated for:

- Valid OCC symbol format
- Option expiration (rejects expired options)
- Account permissions for options trading
- Buying power requirements (via dry-run)
- Position effects (Opening/Closing)

### Dry-Run Validation

```ruby
# Create an order
order = builder.buy_call(option, 1, price: BigDecimal("2.50"))

# Validate with dry-run (checks buying power without placing)
dry_run_response = account.place_order(session, order, dry_run: true)

# Check buying power effect
if dry_run_response.buying_power_effect
  puts "Order would use: $#{dry_run_response.buying_power_effect.buying_power_change_amount}"
  puts "New buying power: $#{dry_run_response.buying_power_effect.new_buying_power}"
end

# If validation passes, place the real order
if dry_run_response.errors.empty?
  response = account.place_order(session, order)
end
```

## Working with Option Chains

```ruby
# Get option chain for a symbol
chain = Tastytrade::Models::OptionChain.get(session, "AAPL")

# Find options by expiration
expiration = Date.new(2024, 1, 19)
options_for_date = chain.expirations_by_date[expiration]

# Filter for specific strikes
calls_near_money = chain.filter_strikes(
  expiration: expiration,
  strike_count: 5  # 5 strikes around ATM
)

# Build orders from chain
if calls_near_money.any?
  call_option = calls_near_money.first
  order = builder.buy_call(call_option, 1, price: call_option.ask)
end
```

## Net Premium Calculation

```ruby
# Calculate net premium for any order
order = builder.vertical_spread(long_call, short_call, 1)
net_premium = builder.calculate_net_premium(order)

if net_premium < 0
  puts "Net debit: $#{net_premium.abs}"
else
  puts "Net credit: $#{net_premium}"
end
```

## Error Handling

```ruby
begin
  # Create and place order
  order = builder.buy_call(option, 1, price: BigDecimal("2.50"))
  response = account.place_order(session, order)
  
  puts "Order placed successfully: #{response.order.id}"
  
rescue Tastytrade::OptionOrderBuilder::InvalidOptionError => e
  puts "Invalid option: #{e.message}"
  
rescue Tastytrade::OptionOrderBuilder::InvalidStrategyError => e
  puts "Invalid strategy: #{e.message}"
  
rescue Tastytrade::OrderValidationError => e
  puts "Order validation failed: #{e.message}"
  
rescue StandardError => e
  puts "Error placing order: #{e.message}"
end
```

## Position Effect

The gem automatically detects position effects based on the action:

- `BUY_TO_OPEN` / `SELL_TO_OPEN` → "Opening"
- `BUY_TO_CLOSE` / `SELL_TO_CLOSE` → "Closing"

You can also explicitly set the position effect:

```ruby
leg = Tastytrade::OrderLeg.new(
  action: Tastytrade::OrderAction::BUY_TO_OPEN,
  symbol: "AAPL 240119C00150000",
  quantity: 1,
  instrument_type: "Option",
  position_effect: "Auto"  # Let the API determine
)
```

## Best Practices

1. **Always validate orders before placing**: Use dry-run to check buying power
2. **Check option liquidity**: Verify bid/ask spreads before placing orders
3. **Handle 0 DTE options carefully**: The validator will warn about same-day expiration
4. **Use limit orders for options**: Market orders on options can result in poor fills
5. **Verify account permissions**: Ensure your account is approved for the option level you need
6. **Monitor position effects**: Ensure Opening/Closing effects match your intent

## API Constants

### Order Actions
- `Tastytrade::OrderAction::BUY_TO_OPEN`
- `Tastytrade::OrderAction::SELL_TO_OPEN`
- `Tastytrade::OrderAction::BUY_TO_CLOSE`
- `Tastytrade::OrderAction::SELL_TO_CLOSE`

### Order Types
- `Tastytrade::OrderType::MARKET`
- `Tastytrade::OrderType::LIMIT`
- `Tastytrade::OrderType::STOP`

### Time in Force
- `Tastytrade::OrderTimeInForce::DAY`
- `Tastytrade::OrderTimeInForce::GTC`