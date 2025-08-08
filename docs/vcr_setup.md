# VCR Setup and Recording Guide

## Initial Setup

### 1. Install Dependencies

```bash
bundle install
```

### 2. Configure Sandbox Credentials

Copy the example file and add your Tastytrade sandbox credentials:

```bash
cp .env.test.example .env.test
```

Edit `.env.test` with your sandbox credentials:
```bash
TASTYTRADE_SANDBOX_USERNAME=your_email@example.com
TASTYTRADE_SANDBOX_PASSWORD=your_sandbox_password
TASTYTRADE_SANDBOX_ACCOUNT=5WV12345  # Your sandbox account number
```

> **Note**: Get sandbox access at https://developer.tastytrade.com/

### 3. Enable Git Hooks (Optional but Recommended)

Configure Git to use the project's hooks:

```bash
git config core.hooksPath .githooks
```

This enables automatic secret scanning before commits.

## Recording VCR Cassettes

### Important: Market Hours Requirement

The Tastytrade sandbox API only accepts order-related requests during US market hours:
- **Monday - Friday**: 9:30 AM - 4:00 PM Eastern Time
- **Closed**: Weekends and US market holidays

### Recording New Cassettes

1. **Ensure market is open** (for order-related tests):
   ```bash
   bundle exec rspec spec/tastytrade/session_vcr_spec.rb --tag market_hours
   ```

2. **Record cassettes**:
   ```bash
   # Record all cassettes (overwrites existing)
   VCR_MODE=record bundle exec rspec spec/tastytrade/session_vcr_spec.rb
   
   # Record only missing cassettes
   bundle exec rspec spec/tastytrade/session_vcr_spec.rb
   ```

3. **Verify sensitive data is filtered**:
   ```bash
   # Check cassettes for leaked credentials
   grep -r "SANDBOX" spec/fixtures/vcr_cassettes/
   ```

### Recording Modes

- **Default (`:once`)**: Records if cassette doesn't exist, replays if it does
- **`VCR_MODE=record` (`:all`)**: Always records, overwrites existing cassettes
- **CI Environment (`:none`)**: Never records, only replays existing cassettes

## GitHub Actions Setup

### Required Repository Secrets

Add these secrets to your GitHub repository (Settings → Secrets → Actions):

1. **`TASTYTRADE_SANDBOX_USERNAME`**
   - Your Tastytrade sandbox email/username
   - Example: `test@example.com`

2. **`TASTYTRADE_SANDBOX_PASSWORD`**
   - Your Tastytrade sandbox password
   - Keep this secure!

3. **`TASTYTRADE_SANDBOX_ACCOUNT`**
   - Your sandbox account number
   - Format: `5WV12345`

### CI Configuration

The CI workflow automatically uses these secrets:

```yaml
# .github/workflows/test.yml
env:
  TASTYTRADE_SANDBOX_USERNAME: ${{ secrets.TASTYTRADE_SANDBOX_USERNAME }}
  TASTYTRADE_SANDBOX_PASSWORD: ${{ secrets.TASTYTRADE_SANDBOX_PASSWORD }}
  TASTYTRADE_SANDBOX_ACCOUNT: ${{ secrets.TASTYTRADE_SANDBOX_ACCOUNT }}
```

## Cassette Organization

Cassettes are organized by class and test scenario:

```
spec/fixtures/vcr_cassettes/
├── session/
│   ├── login_success.yml
│   ├── login_remember.yml
│   ├── validate.yml
│   └── destroy.yml
├── account/
│   ├── get_accounts.yml
│   └── get_balances.yml
└── order/
    ├── create_order.yml
    └── cancel_order.yml
```

## Troubleshooting

### "Market is closed" Error

This occurs when trying to record order-related cassettes outside market hours. Solutions:
1. Wait until market hours (9:30 AM - 4:00 PM ET, Mon-Fri)
2. Use existing cassettes (don't set `VCR_MODE=record`)
3. For non-order tests, they should work anytime

### "No cassette found" Error

This means the cassette doesn't exist and VCR is not in recording mode:
1. Set `VCR_MODE=record` to record new cassettes
2. Ensure you have valid sandbox credentials in `.env.test`
3. Check if market is open (for order-related tests)

### Sensitive Data in Cassettes

If the pre-commit hook detects sensitive data:
1. Check the VCR configuration in `spec/spec_helper.rb`
2. Add appropriate filters for the detected pattern
3. Re-record the affected cassettes
4. Verify filtering with: `grep -r "password\|token\|account" spec/fixtures/vcr_cassettes/`

## Best Practices

1. **Never commit `.env.test`** - It contains real credentials
2. **Always verify cassettes** after recording for sensitive data
3. **Use descriptive cassette names** that match the test scenario
4. **Keep cassettes small** - One test scenario per cassette
5. **Update cassettes periodically** to catch API changes
6. **Document market-hours dependencies** in test descriptions

## Security Considerations

The VCR configuration automatically filters:
- Sandbox credentials (username, password, account)
- Session tokens
- Remember tokens
- Authorization headers
- Email addresses
- Account numbers in URLs

Additional patterns can be added to `spec/spec_helper.rb` as needed.