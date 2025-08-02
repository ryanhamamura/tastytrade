# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Order placement functionality for equities (#11)
  - Order and OrderLeg classes for building orders programmatically
  - Support for market and limit order types
  - All four order actions: BUY_TO_OPEN, SELL_TO_CLOSE, SELL_TO_OPEN, BUY_TO_CLOSE
  - Time in force options: DAY and GTC
  - Automatic price-effect calculation (Debit for buys, Credit for sells)
  - Account#place_order method for order submission
  - OrderResponse model for parsing placement results
  - Equity instrument class with build_leg helper method
  - CLI `order` command with options for type, price, action, and dry-run
  - Interactive order menu with vim navigation for order type and action
  - Dry-run simulation capability for testing orders
  - Improved error handling with helpful messages for common scenarios
  - Comprehensive test coverage for all order functionality
- CLI positions command (#7)
  - `positions` command to display account positions in table format
  - Position filtering options: --symbol, --underlying-symbol, --include-closed
  - Account selection with --account option
  - Color-coded P/L display (green for profit, red for loss)
  - Summary statistics showing total P/L and winners/losers count
  - Option-specific display formatting (e.g., "AAPL 150C 1/19")
  - Support for short positions with negative quantity display
  - Integration with interactive mode and balance submenu
- Positions formatter for table display
  - TTY::Table integration for professional formatting
  - BigDecimal precision for monetary values
  - Automatic symbol formatting for options
  - Summary row with position statistics
- Environment variable authentication support
  - Session.from_environment class method for creating sessions from env vars
  - Support for TASTYTRADE_USERNAME, TASTYTRADE_PASSWORD (or TT_ prefixed)
  - Optional TASTYTRADE_ENVIRONMENT for sandbox/production selection
  - Optional TASTYTRADE_REMEMBER for automatic session refresh
  - CLI automatically attempts env var login before prompting
  - Fallback to interactive login if env var authentication fails
  - Complete test coverage for all environment variable scenarios
- Enhanced CLI documentation
  - Comprehensive login command help with environment variable examples
  - README documentation for environment variable configuration
  - Examples for CI/CD and automation use cases
- CLI login improvements
  - Added --no-interactive flag to skip interactive mode after login
  - Useful for scripting and CI/CD environments
  - Correctly detects environment (sandbox/production) from env vars
- GitHub Release creation instructions in release workflow
  - Added `gh release create` command to release-pr.md
  - Automated release notes generation with --generate-notes flag
  - Draft release workflow for review before publishing

### Changed
- Session storage switched from keyring to secure file-based storage
  - Sessions now stored in ~/.config/tastytrade/credentials/ with 0600 permissions
  - More reliable across different systems without keyring dependencies
  - Credentials directory created with 0700 permissions for security
  - User data (email, username, external_id) now saved with sessions for validation

### Fixed
- Session persistence issues between command invocations
  - Fixed session corruption after first command execution
  - Sessions now properly persist across multiple CLI commands
  - Removed problematic session validation on load that was causing failures
- Removed stray error message "Failed to load current account" from positions/balance commands
  - Error now only displays when DEBUG_SESSION environment variable is set
- Fixed all test failures related to file-based storage implementation
  - Updated FileStore tests to properly mock temporary directories
  - Fixed CLI auth tests to stub environment variable checks
  - Added missing user attributes to test mocks
  - Updated session manager tests for new user data saving/loading

### Removed
- Keyring gem dependency and KeyringStore implementation
  - Replaced with more reliable file-based credential storage
  - Eliminates cross-platform keyring compatibility issues

### Deprecated
- Nothing yet

### Security
- Nothing yet

## [0.2.0] - 2025-08-01

### Added
- Initial gem structure with professional Ruby gem scaffold
- Basic configuration files (RuboCop, RSpec, GitHub Actions)
- Development tooling setup
  - RSpec test framework with SimpleCov coverage reporting
  - RuboCop linter with custom configuration
  - GitHub Actions CI for multi-OS and multi-Ruby testing
- HTTP client infrastructure (#16, #17, #19)
  - Faraday as HTTP client with retry middleware
  - RESTful methods (GET, POST, PUT, DELETE)
  - Automatic retry for transient failures (429, 503, 504)
  - Configurable timeout settings
  - Production/sandbox environment support
- Comprehensive error handling framework (#17)
  - InvalidCredentialsError for authentication failures
  - SessionExpiredError for expired sessions
  - TokenRefreshError for refresh failures
  - NetworkTimeoutError for connection timeouts
  - Unified error response parsing
- Session management with authentication (#1-5)
  - Basic session class with login/logout
  - Remember token authentication support
  - Session expiration tracking and automatic refresh
  - Secure credential storage using system keyring
  - Session validation and error handling
- Account models and data structures (#20)
  - Account model with proper data parsing
  - AccountBalance model with BigDecimal precision for monetary values
  - CurrentPosition model for position tracking with P&L calculations
  - Support for options, equities, and futures positions
- CLI foundation with interactive mode (#23, #24)
  - Core CLI structure using Thor
  - `login` command with --remember and --test flags
  - `logout` command with session cleanup
  - `status` command to check session status and expiration
  - `refresh` command to refresh session using remember token
  - `accounts` command to list all accounts
  - `select` command to choose active account
  - `balance` command with table formatting and --all flag
  - Interactive menu-driven interface
  - Vim-style navigation (j/k for up/down, q/ESC to exit)
  - Number key shortcuts for menu selection
  - Automatic entry into interactive mode after login
- CLI helper utilities
  - Colored output helpers (error, warning, success, info)
  - Currency formatting with thousand separators
  - TTY::Table integration for data display
  - Pastel color support
- Configuration management
  - YAML-based configuration file (~/.config/tastytrade/config.yml)
  - Environment persistence (production/sandbox)
  - Current account selection persistence
  - Safe config file handling with error recovery
- Security features
  - MIT License
  - Code of Conduct
  - Security policy documentation
  - Keyring integration for secure credential storage

### Changed
- Account.get_balances now returns AccountBalance object instead of raw hash
- Account.get_positions now returns array of CurrentPosition objects instead of raw hashes
- CLI menus now use consistent vim-style navigation with extracted helper method
- Updated release-pr Claude Code command to include ROADMAP.md updates in release process
- Removed MFA requirement for RubyGems.org publishing
- Updated release-pr command to reflect that rake release auto-creates git tags

### Fixed
- Account data parsing from API response (#25)
- "Failed to load current account" error in balance view by implementing account caching
- TTY::Table rendering in non-TTY environments with fallback formatting