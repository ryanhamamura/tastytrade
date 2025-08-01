# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

### Deprecated
- Nothing yet

### Removed
- Nothing yet

### Security
- Nothing yet