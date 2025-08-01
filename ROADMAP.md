# Tastytrade Ruby SDK Roadmap

This document outlines the development roadmap for the unofficial Tastytrade Ruby SDK. Track progress via [GitHub Projects](https://github.com/users/ryanhamamura/projects/1).

## Project Goals

- Port the Python Tastytrade SDK to Ruby with idiomatic Ruby patterns
- Provide both synchronous and asynchronous API support
- Include a powerful CLI tool within the same gem
- Maintain comprehensive test coverage and documentation

## Development Phases

### Phase 1: Core SDK Foundation
**Target: Q3 2025 (July - September)**

#### Authentication & Session Management
- [x] Basic session class with login/logout (closes #1)
- [x] Token management and refresh (closes #2)
- [x] Production/sandbox environment support (closes #3)
- [x] Credentials storage (secure) (closes #4)
- [x] Session validation and error handling (closes #5)

#### Account Operations
- [x] Fetch account info and balances (closes #6)
- [x] Get positions
- [ ] Get transaction history
- [ ] Calculate buying power
- [ ] Account status and trading permissions

#### Basic Trading
- [ ] Place equity orders (market, limit)
- [ ] Cancel/replace orders
- [ ] Get order status
- [ ] Order validation
- [ ] Basic order types (day, GTC)

#### Core Infrastructure
- [x] HTTP client setup (Faraday) (closes #16)
- [x] Error handling framework (closes #17)
- [ ] Logging system
- [x] Configuration management (closes #19)
- [x] Basic data models (using dry-struct) (closes #20)

### Phase 2: Advanced SDK Features
**Target: Q4 2025 (October - December)**

#### Options Trading
- [ ] Option chain retrieval
- [ ] Options orders (single leg)
- [ ] Multi-leg strategies (spreads, strangles, iron condors)
- [ ] Greeks calculation
- [ ] Options-specific validations

#### Advanced Order Types
- [ ] Stop/stop-limit orders
- [ ] OCO (One-Cancels-Other)
- [ ] Trailing stops
- [ ] Conditional orders
- [ ] Order grouping

#### Market Data
- [ ] Real-time quotes
- [ ] Historical data
- [ ] Market hours/calendar
- [ ] Instrument search
- [ ] Watchlist management

#### Streaming Support
- [ ] WebSocket connection management
- [ ] Quote streaming (DXLink)
- [ ] Account alerts streaming
- [ ] Auto-reconnection logic
- [ ] Event handling system

### Phase 3: CLI Integration
**Target: Q1 2026 (January - March)**

#### Core CLI Commands
- [ ] Authentication (`tt login`)
- [ ] Account info (`tt account`)
- [ ] Portfolio view (`tt portfolio`)
- [ ] Basic trading (`tt trade`)
- [ ] Order management (`tt orders`)

#### Options CLI
- [ ] Option chains (`tt option chain`)
- [ ] Options trading (`tt option trade`)
- [ ] Strategy builder
- [ ] Greeks display

#### Advanced CLI Features
- [ ] Watchlist monitoring (`tt watch`)
- [ ] Portfolio analysis (`tt analyze`)
- [ ] Real-time quotes (`tt quote`)
- [ ] Configuration management (`tt config`)
- [ ] Interactive mode

#### CLI Enhancements
- [ ] Rich terminal output (TTY gems)
- [ ] Progress indicators
- [ ] Confirmation prompts
- [ ] Output formatting (JSON, CSV, table)
- [ ] Shell completion

### Phase 4: Advanced Features & Polish
**Target: Q2 2026 (April - June)**

#### Advanced Analytics
- [ ] Portfolio metrics calculation
- [ ] Risk analysis
- [ ] P&L tracking
- [ ] Tax lot management
- [ ] Performance reporting

#### Async Support
- [ ] Async HTTP client option
- [ ] Concurrent operations
- [ ] Batch operations
- [ ] Rate limiting

#### Developer Experience
- [ ] Comprehensive documentation
- [ ] Example applications
- [ ] Video tutorials
- [ ] API reference docs
- [ ] Migration guide from Python

#### Testing & Quality
- [ ] 90%+ test coverage
- [ ] Integration test suite
- [ ] Performance benchmarks
- [ ] Security audit
- [ ] Load testing

## Success Metrics

- **Test Coverage**: Maintain >90% coverage
- **Documentation**: 100% public API documented
- **Performance**: <100ms average response time
- **Reliability**: 99.9% uptime for streaming
- **Community**: Active user base and contributors

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for details on how to help with development.

## Notes

- Each phase builds upon the previous one
- Phases may overlap as development progresses
- Community feedback will influence priorities
- Breaking changes will be minimized after v1.0

---

Last Updated: 2025-07-30