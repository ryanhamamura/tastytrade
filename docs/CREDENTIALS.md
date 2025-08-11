# Credential Management

The Tastytrade gem supports multiple ways to manage your API credentials securely.

## Environment Files (.env)

The recommended approach is to use environment files to store your credentials. This keeps them separate from your code and prevents accidental commits.

### Setup

1. **For Production:**
   ```bash
   cp .env.production.example .env
   # Edit .env with your production credentials
   ```

2. **For Sandbox (Testing):**
   ```bash
   cp .env.sandbox.example .env.sandbox
   # Edit .env.sandbox with your sandbox credentials
   ```

### Usage

The CLI automatically loads the appropriate .env file based on the `--test` flag:

```bash
# Uses .env (production credentials)
tastytrade login
tastytrade option chain SPY

# Uses .env.sandbox (sandbox credentials)
tastytrade login --test
tastytrade option chain SPY --test
```

## Environment Variables

You can also set credentials directly as environment variables:

```bash
export TASTYTRADE_USERNAME="your_username@example.com"
export TASTYTRADE_PASSWORD="your_password"
export TASTYTRADE_REMEMBER="true"

tastytrade login
```

## Security Best Practices

1. **Never commit .env files** - They're already in .gitignore
2. **Use sandbox for testing** - Always use `--test` flag when developing
3. **Rotate credentials regularly** - Change your passwords periodically
4. **Use read-only credentials** - If available, use read-only API keys for data access
5. **Limit scope** - Only grant the minimum permissions needed

## Multiple Accounts

To switch between multiple accounts quickly:

```bash
# Create account-specific env files
cp .env.example .env.account1
cp .env.example .env.account2

# Switch accounts by copying the desired file
cp .env.account1 .env
tastytrade login

# Or use environment variables
TASTYTRADE_USERNAME="account2@example.com" TASTYTRADE_PASSWORD="pass2" tastytrade login
```

## Troubleshooting

### Invalid Credentials Error
- Verify credentials work on the Tastytrade website
- Check for extra spaces or special characters in .env file
- Ensure you're using the correct environment (sandbox vs production)

### Session Expired
- Run `tastytrade login` again
- Enable remember mode: `TASTYTRADE_REMEMBER=true`

### Wrong Environment
- Production: `tastytrade login` (no flags)
- Sandbox: `tastytrade login --test`