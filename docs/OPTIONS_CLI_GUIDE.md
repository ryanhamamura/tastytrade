# Tastytrade Options Trading CLI Guide

## Overview

The Tastytrade CLI now includes comprehensive options trading functionality, allowing you to view option chains, get quotes, and place both single-leg and multi-leg option orders directly from the command line.

## Prerequisites

1. Set up your credentials in `.env.sandbox` (for testing) or `.env` (for production):
```bash
TASTYTRADE_USERNAME=your_email@example.com
TASTYTRADE_PASSWORD=your_password
TASTYTRADE_REMEMBER=true
```

2. Login to your account:
```bash
# For sandbox/testing
tastytrade login --test --no-interactive

# For production
tastytrade login --no-interactive
```

## Available Commands

### 1. View Option Chains

Display option chains for any symbol with customizable filters:

```bash
# Basic option chain
tastytrade option chain SPY --test

# With filters
tastytrade option chain SPY --test \
  --strikes 10 \           # Number of strikes around ATM
  --expirations 5 \        # Number of expirations to show
  --dte 30 \              # Max days to expiration
  --type weekly \         # Filter by expiration type (weekly/monthly/quarterly)
  --format table          # Output format (table/compact/json/csv)
```

**Filters available:**
- `--strikes N` - Number of strikes to display around ATM
- `--expirations N` - Number of expiration dates to show
- `--dte N` - Maximum days to expiration
- `--min-dte N` - Minimum days to expiration
- `--type` - Expiration type (weekly/monthly/quarterly/all)
- `--format` - Output format (table/compact/json/csv)
- `--greeks` - Include Greeks in display
- `--moneyness` - Filter by moneyness (itm/atm/otm/all)
- `--delta N` - Find strikes near specific delta

### 2. Get Option Quotes

Get detailed quotes for specific option contracts:

```bash
# Get quote for a specific option
tastytrade option quote "SPY 250815C00620000" --test

# Output formats
tastytrade option quote "SPY 250815C00620000" --test --format detailed
tastytrade option quote "SPY 250815C00620000" --test --format compact
tastytrade option quote "SPY 250815C00620000" --test --format json
```

### 3. Buy Options

Buy call or put options with various selection methods:

```bash
# Buy by explicit strike and expiration
tastytrade option buy call SPY --test \
  --strike 620 \
  --expiration "2025-08-15" \
  --quantity 1 \
  --limit 2.50 \
  --dry-run

# Buy by delta
tastytrade option buy put SPY --test \
  --delta -0.30 \
  --dte 30 \
  --quantity 1 \
  --dry-run

# Buy ATM option
tastytrade option buy call SPY --test \
  --dte 7 \
  --quantity 1 \
  --dry-run
```

### 4. Sell Options

Sell call or put options (opening positions):

```bash
# Sell covered call
tastytrade option sell call SPY --test \
  --strike 625 \
  --expiration "2025-08-15" \
  --quantity 1 \
  --limit 1.50 \
  --dry-run

# Sell cash-secured put
tastytrade option sell put SPY --test \
  --strike 615 \
  --expiration "2025-08-15" \
  --quantity 1 \
  --dry-run
```

### 5. Vertical Spreads

Create bull/bear call/put spreads:

```bash
# Bull call spread
tastytrade option spread SPY --test \
  --type call \
  --long-strike 618 \
  --short-strike 622 \
  --expiration "2025-08-15" \
  --quantity 1 \
  --limit 2.00 \
  --dry-run

# Bear put spread
tastytrade option spread SPY --test \
  --type put \
  --long-strike 622 \
  --short-strike 618 \
  --expiration "2025-08-15" \
  --quantity 1 \
  --dry-run
```

### 6. Strangles

Create long or short strangles:

```bash
# Long strangle with explicit strikes
tastytrade option strangle SPY --test \
  --call-strike 625 \
  --put-strike 615 \
  --expiration "2025-08-15" \
  --quantity 1 \
  --dry-run

# Short strangle using delta
tastytrade option strangle SPY --test \
  --call-delta 0.30 \
  --put-delta -0.30 \
  --dte 45 \
  --quantity 1 \
  --dry-run
```

### 7. Straddles

Create long or short straddles:

```bash
# Long straddle at specific strike
tastytrade option straddle SPY --test \
  --strike 620 \
  --expiration "2025-08-15" \
  --quantity 1 \
  --dry-run

# ATM straddle
tastytrade option straddle SPY --test \
  --dte 30 \
  --quantity 1 \
  --dry-run
```

## Common Options

All order commands support these common options:
- `--test` - Use sandbox environment
- `--quantity N` - Number of contracts (default: 1)
- `--limit N` - Limit price (uses mid if not specified)
- `--dry-run` - Validate order without placing
- `--help` - Show command help

## Order Confirmation

When placing real orders (without `--dry-run`), you'll see:
1. Order details summary
2. Account information (sandbox vs production)
3. Confirmation prompt

Example output:
```
Order Details:
Type:        Limit
Time in Force: Day

Leg 1:
  Symbol:    SPY 250815C00620000
  Action:    Buy to Open
  Quantity:  1

Price:       $2.50

Account: 5WZ31145 (SANDBOX)
Place this order? (Y/n)
```

## Tips and Best Practices

1. **Always use `--dry-run` first** to validate your orders before placing them
2. **Start with sandbox** (`--test`) to practice without risk
3. **Use delta selection** for dynamic strike selection based on probability
4. **Check the chain first** to see available strikes and expirations
5. **Set limit prices** to avoid bad fills, especially for multi-leg orders

## Troubleshooting

### Authentication Issues
If you get "You must be logged in" errors:
```bash
# Re-login
tastytrade login --test --no-interactive

# Check your session
tastytrade status --test
```

### Missing Data
Sandbox environment may have limited or placeholder data. Use production for real market data.

### Order Validation Errors
- Ensure strikes exist in the chain
- Check expiration dates are valid trading days
- Verify you have sufficient buying power

## Examples

### Example 1: Selling a Covered Call
```bash
# First, check the chain
tastytrade option chain AAPL --test --strikes 5 --dte 30

# Then sell the call
tastytrade option sell call AAPL --test \
  --strike 180 \
  --expiration "2025-09-15" \
  --quantity 1 \
  --limit 3.50
```

### Example 2: Iron Condor Setup
While iron condor isn't a single command, you can build one with two spreads:
```bash
# Put spread (sell 95/buy 90)
tastytrade option spread SPY --test \
  --type put \
  --long-strike 590 \
  --short-strike 595 \
  --expiration "2025-09-15" \
  --quantity 1

# Call spread (sell 105/buy 110)  
tastytrade option spread SPY --test \
  --type call \
  --long-strike 630 \
  --short-strike 625 \
  --expiration "2025-09-15" \
  --quantity 1
```

### Example 3: Delta-Neutral Strangle
```bash
tastytrade option strangle SPY --test \
  --call-delta 0.16 \
  --put-delta -0.16 \
  --dte 45 \
  --quantity 1 \
  --dry-run
```

## Support

For issues or questions:
- Check help: `tastytrade option help [COMMAND]`
- View all options: `tastytrade option --help`
- Report issues: [GitHub Issues](https://github.com/your-repo/issues)