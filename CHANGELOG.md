# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- VCR test framework implementation - PR #2: Account & Model Classes (#42)
  - Converted Account model tests from mocks to VCR with real API calls
  - Converted Transaction model tests to use VCR recordings
  - Converted order placement tests with idempotent test patterns
  - Created OrderTestHelper for automated order cleanup
  - Implemented one-cassette-per-test organization pattern
  - Removed duplicate account method test files
  - Added lazy session loading for VCR compatibility
  - Pure Ruby model tests left unchanged (no API calls)
- VCR test framework implementation - PR #1: Foundation & Session (#42)
  - Replaced WebMock-based mocks with real API recordings via VCR
  - Added comprehensive VCR configuration with sensitive data filtering
  - Implemented market hours helper for Tastytrade sandbox constraints
  - Created pre-commit hook for automated secret scanning
  - Added dotenv support for test environment credentials
  - Converted Session class tests to use VCR cassettes
  - Added Ruby version compatibility checking module
  - Documented VCR setup and recording procedures
  - Configured GitHub Actions secrets documentation
  - 17 recorded cassettes with proper data sanitization
- Order time-in-force CLI support (#15)
  - Added --time-in-force option to `order place` command
  - Support for DAY and GTC (Good Till Cancelled) order durations
  - Accepts shorthand aliases: "d" for DAY, "g" or "good_till_cancelled" for GTC
  - Defaults to DAY order when not specified (backward compatible)
  - Display time-in-force in order summaries and order history tables
  - Added TIF column to order list and history displays
  - Complete test coverage for time-in-force parameter handling
  - Note: Core Order class already had full DAY/GTC support
- Comprehensive order validation framework (#14)
  - OrderValidator class with multi-layer validation checks
  - Symbol validation via Instruments API
  - Quantity validation with min/max constraints (1-999,999)
  - Price validation with tick size rounding
  - Account permissions validation using TradingStatus
  - Buying power validation via dry-run API calls
  - Market hours validation with warnings
  - Specific error classes (OrderValidationError, InvalidSymbolError, etc.)
  - Integration into Account#place_order method
  - Order#validate! and Order#dry_run helper methods
  - CLI `order place` command with validation support
  - Dry-run mode for testing orders without submission
  - Confirmation prompts with buying power impact display
  - Comprehensive test coverage for all validation scenarios
- Enhanced order status and history functionality (#13)
  - Account#get_order_history method for retrieving orders beyond 24 hours
  - Account#get_order method for fetching individual order details
  - Date range filtering for order history with from/to parameters
  - Pagination support for large order history queries
  - JSON output format for all order CLI commands (--format json)
  - LiveOrder#to_h method for JSON serialization
  - `order history` CLI command with comprehensive filtering options
  - `order get` CLI command for detailed single order information
  - Enhanced display_order_details method showing fills and timestamps
  - Complete test coverage for new order history methods
- Order cancellation and replacement functionality (#12)
  - LiveOrder model for parsing existing orders from API
  - OrderStatus module with status constants and validation helpers
  - Account#get_live_orders method with status/symbol/time filtering
  - Account#cancel_order method with proper error handling
  - Account#replace_order method with partial fill support
  - Custom exceptions for order operations (OrderNotCancellableError, OrderAlreadyFilledError, etc.)
  - CLI `order` subcommands structure with list/cancel/replace operations
  - `order list` command with real-time order display and status filtering
  - `order cancel` command with confirmation prompt and order details
  - `order replace` command with interactive price/quantity modification
  - Partial fill tracking with filled/remaining quantity calculations
  - Order status color coding in CLI output
  - VCR test configuration with sensitive data filtering
  - Comprehensive test coverage for all order management features
  - Integration tests for complete order lifecycle (place, list, modify, cancel)
  - Renamed existing `order` command to `place` for clarity
- Account trading status and permissions (#10)
  - TradingStatus model with 35+ fields matching Python SDK structure
  - Complete account state tracking (frozen, closed, margin call, PDT status)
  - Trading permissions for options, futures, cryptocurrency, and short calls
  - Options trading level parsing and validation
  - Pattern Day Trader (PDT) status with reset dates and day trade counts
  - Portfolio margin and risk-reducing mode indicators
  - Account restrictions detection and listing
  - Helper methods for permission checking (can_trade_options?, can_trade_futures?, etc.)
  - CLI `trading_status` command with color-coded warnings
  - Visual indicators for account restrictions and margin calls
  - Display of fee schedule and margin calculation type
  - Full test coverage for all trading status features
- Claude command for planning multi-issue implementations
  - `.claude/commands/plan.md` command for structured issue planning
  - Spawns concurrent subagents to research codebase, Python SDK, and CLI
  - Compiles comprehensive implementation plans with detailed todos
  - Requires user approval before proceeding with implementation
- Transaction history functionality (#8)
  - Transaction model with comprehensive field support including fees and metadata
  - Get all transactions with automatic pagination
  - Filtering by date range, symbol, instrument type, and transaction types
  - Manual pagination control with page_offset and per_page parameters
  - Account#get_transactions convenience method
  - CLI `history` command with table display and filtering options
  - Grouping transactions by symbol, type, or date
  - Transaction totals and summaries (credits, debits, fees, net cash flow)
  - Interactive history menu with date and symbol filtering
  - Full test coverage for Transaction model and API integration
- Buying power calculation and monitoring (#9)
  - Extended AccountBalance model with buying power calculation methods
  - Buying power usage percentage for equity, derivative, and day trading
  - Check if sufficient buying power exists for orders
  - Calculate buying power impact percentage for proposed orders
  - BuyingPowerEffect model for dry-run order validation
  - Dry-run orders now return detailed buying power impact information
  - CLI `buying_power` command to display buying power status
  - Buying power warnings when placing orders that use >80% of available BP
  - Interactive confirmation for high buying power usage orders
  - Integration with order placement workflow (both CLI and interactive)
  - Comprehensive test coverage for all buying power calculations
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