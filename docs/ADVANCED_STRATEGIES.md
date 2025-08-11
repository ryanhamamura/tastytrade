# Advanced Option Strategies Guide

This guide covers the advanced multi-leg option strategies available in the Tastytrade Ruby gem.

## Table of Contents

1. [Iron Butterfly](#iron-butterfly)
2. [Butterfly Spread](#butterfly-spread)
3. [Calendar Spread](#calendar-spread)
4. [Diagonal Spread](#diagonal-spread)

## Iron Butterfly

An iron butterfly is a 4-leg neutral strategy that combines a short straddle at the center strike with a long strangle at the wing strikes.

### Structure
- Short call at center strike (ATM)
- Short put at center strike (ATM)
- Long call at higher strike (wing)
- Long put at lower strike (wing)

### Ruby API Usage

```ruby
builder = Tastytrade::OptionOrderBuilder.new(session, account)

# Create iron butterfly with 10-point wings
short_call = find_option(symbol: "SPY", strike: 450, type: :call, dte: 30)
long_call = find_option(symbol: "SPY", strike: 460, type: :call, dte: 30)
short_put = find_option(symbol: "SPY", strike: 450, type: :put, dte: 30)
long_put = find_option(symbol: "SPY", strike: 440, type: :put, dte: 30)

order = builder.iron_butterfly(
  short_call,
  long_call,
  short_put,
  long_put,
  quantity: 1,
  price: 3.00  # Net credit
)

account.place_order(session, order)
```

### CLI Usage

```bash
# Create iron butterfly with explicit parameters
tastytrade option iron_butterfly SPY \
  --center-strike 450 \
  --wing-width 10 \
  --expiration 2025-02-21 \
  --limit 3.00 \
  --quantity 1 \
  --dry-run

# Use defaults (ATM strike, 10-point wings)
tastytrade option iron_butterfly SPY --dte 30 --dry-run
```

## Butterfly Spread

A butterfly spread is a 3-leg strategy with a 1-2-1 quantity ratio that creates a profit zone centered around the middle strike.

### Structure
- 1 long option at lower strike
- 2 short options at middle strike
- 1 long option at higher strike

### Ruby API Usage

```ruby
# Call butterfly
long_low = find_option(symbol: "SPY", strike: 440, type: :call, dte: 30)
short_middle = find_option(symbol: "SPY", strike: 450, type: :call, dte: 30)
long_high = find_option(symbol: "SPY", strike: 460, type: :call, dte: 30)

order = builder.butterfly_spread(
  long_low,
  short_middle,
  long_high,
  quantity: 1,  # Middle leg automatically gets 2x quantity
  price: 1.50   # Net debit
)

account.place_order(session, order)
```

### CLI Usage

```bash
# Call butterfly
tastytrade option butterfly SPY \
  --type call \
  --center-strike 450 \
  --wing-width 10 \
  --expiration 2025-02-21 \
  --limit 1.50 \
  --dry-run

# Put butterfly
tastytrade option butterfly SPY \
  --type put \
  --center-strike 450 \
  --wing-width 10 \
  --dte 30 \
  --dry-run
```

## Calendar Spread

A calendar spread (time spread) involves options at the same strike but different expirations.

### Structure
- Short option at near-term expiration
- Long option at longer-term expiration
- Same strike price for both

### Ruby API Usage

```ruby
# Call calendar spread
short_option = find_option(symbol: "SPY", strike: 450, type: :call, dte: 30)
long_option = find_option(symbol: "SPY", strike: 450, type: :call, dte: 60)

order = builder.calendar_spread(
  short_option,
  long_option,
  quantity: 1,
  price: 1.00  # Net debit
)

account.place_order(session, order)
```

### CLI Usage

```bash
# Call calendar spread
tastytrade option calendar SPY \
  --type call \
  --strike 450 \
  --short-dte 30 \
  --long-dte 60 \
  --limit 1.00 \
  --dry-run

# Put calendar with default DTEs (30/60)
tastytrade option calendar SPY \
  --type put \
  --strike 450 \
  --dry-run
```

## Diagonal Spread

A diagonal spread combines elements of vertical and calendar spreads with different strikes AND different expirations.

### Structure
- Short option at near-term expiration and one strike
- Long option at longer-term expiration and different strike

### Ruby API Usage

```ruby
# Bullish call diagonal
short_option = find_option(symbol: "SPY", strike: 450, type: :call, dte: 30)
long_option = find_option(symbol: "SPY", strike: 455, type: :call, dte: 60)

order = builder.diagonal_spread(
  short_option,
  long_option,
  quantity: 1,
  price: 2.00  # Net debit
)

account.place_order(session, order)
```

### CLI Usage

```bash
# Call diagonal spread
tastytrade option diagonal SPY \
  --type call \
  --short-strike 450 \
  --long-strike 455 \
  --short-dte 30 \
  --long-dte 60 \
  --limit 2.00 \
  --dry-run

# Put diagonal with auto-calculated long strike
tastytrade option diagonal SPY \
  --type put \
  --short-strike 450 \
  --strike-width 5 \
  --short-dte 30 \
  --long-dte 60 \
  --dry-run
```

## Strategy Selection Guide

| Strategy | Market Outlook | Volatility Expectation | Risk/Reward |
|----------|---------------|------------------------|-------------|
| **Iron Butterfly** | Neutral | Decreasing | Limited risk, limited reward |
| **Butterfly Spread** | Neutral with price target | Low | Limited risk, limited reward |
| **Calendar Spread** | Neutral to slightly directional | Increasing near-term | Limited risk, limited reward |
| **Diagonal Spread** | Directional | Variable | Limited risk, limited reward |

## Common Parameters

### Time in Force
- `DAY` - Day order (default)
- `GTC` - Good till canceled
- `GTD` - Good till date
- `IOC` - Immediate or cancel

### Position Effect
- `:auto` - Automatically determine (default)
- `:opening` - Opening position
- `:closing` - Closing position

## Risk Management

### General Guidelines
1. **Iron Butterfly**: Best for range-bound markets with declining volatility
2. **Butterfly Spread**: Target specific price levels with limited risk
3. **Calendar Spread**: Profit from time decay differential
4. **Diagonal Spread**: Combine directional bias with time decay

### Position Sizing
- Always specify quantity explicitly
- Consider account size and risk tolerance
- Use dry-run mode to validate orders before placement

### Exit Strategies
- Iron Butterfly: Close at 25-50% of max profit
- Butterfly: Hold closer to expiration for max profit
- Calendar: Manage based on volatility changes
- Diagonal: Adjust based on directional movement

## Testing Strategies

Always test strategies in sandbox mode first:

```bash
# Login to sandbox
tastytrade login --test

# Test with dry-run
tastytrade option iron_butterfly SPY --test --dry-run

# Run test scripts
ruby test_advanced_strategies.rb
```

## Additional Resources

- [Tastytrade Learn Center](https://www.tastytrade.com/learn)
- [Option Greeks Guide](https://www.tastytrade.com/learn/option-greeks)
- [Multi-leg Strategies](https://www.tastytrade.com/learn/multi-leg-option-strategies)