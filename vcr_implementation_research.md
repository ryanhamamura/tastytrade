# VCR Implementation Research - Best Practices

## Research Progress

### Question 1: Test Environment & Credentials
**Question**: Do you have access to a Tastytrade sandbox/test account?
**Status**: ✅ ANSWERED
**Best Practice**: Use sandbox/test accounts for recording. APIs should provide sandbox environments for testing that don't affect production data.
**Recommendation**: We should use Tastytrade's sandbox environment for all VCR recordings.
**Outstanding**: Need to confirm if you have sandbox credentials.

### Question 2: How should we handle test credentials?
**Question**: Store in .env.test file? GitHub secrets for CI? Other approach?
**Status**: ✅ ANSWERED
**Best Practice**: 
- Use environment variables for credentials (12-Factor App practice)
- Local: Use .env.test file (gitignored) with dotenv gem
- CI: Use GitHub Actions secrets
- Filter sensitive data in VCR configuration
**Recommendation**: 
1. Create `.env.test.example` with placeholders
2. Use `.env.test` locally (gitignored)
3. Store credentials in GitHub secrets for CI
4. Configure VCR to filter all sensitive data

### Question 3: What recording mode should we use?
**Question**: :once, :new_episodes, :none, or custom strategy?
**Status**: ✅ ANSWERED
**Best Practice**:
- Use `:once` as default (recommended by VCR documentation)
- Use environment variable for re-recording: `VCR_MODE=rec` → `:all`
- Use `:none` in CI for safety (prevents accidental API calls)
- Avoid `:new_episodes` unless specifically needed (can silently record unmatched requests)
**Recommendation**:
```ruby
vcr_mode = ENV['VCR_MODE'] =~ /rec/i ? :all : :once
vcr_mode = :none if ENV['CI']
```

### Question 4: Should we record against production or sandbox API?
**Question**: Sandbox vs production for recordings?
**Status**: ✅ ANSWERED
**Best Practice**:
- Always use sandbox/test environments for recording cassettes
- Maintain complete isolation from production
- Don't change API URLs in test environment - point to real service
- Ensure proper compliance and data segregation
**Recommendation**: Use Tastytrade sandbox API exclusively for all recordings

### Question 5: Which test areas are most critical to convert first?
**Question**: Authentication, Orders, Account/Balance, or CLI?
**Status**: ✅ ANSWERED
**Best Practice**:
- Start with Authentication/Session tests (foundation for all other tests)
- Then Session management (stateful interactions)
- Then critical business logic (orders, accounts)
- Finally secondary features (CLI, etc.)
**Recommendation**: Priority order:
1. Authentication/Session tests (fundamental)
2. Account/Balance retrieval (frequently used)
3. Order placement (high risk, needs accurate testing)
4. CLI commands (user-facing, depends on above)

### Question 6: Should we keep existing mock tests during transition?
**Question**: Run both in parallel or replace completely?
**Status**: ✅ ANSWERED
**Best Practice**:
- Can use both VCR and WebMock together
- Use `:use_vcr` metadata to enable VCR for specific tests
- Gradually transition from mocks to VCR
- Keep mocks for simple unit tests, use VCR for integration tests
**Recommendation**: 
1. Keep existing mock tests initially
2. Add `:use_vcr` metadata to tests being converted
3. Run both in parallel during transition
4. Remove mocks after VCR tests are stable

### Question 7: How should we handle dynamic data in recordings?
**Question**: Timestamps, Order IDs, Market prices - custom matchers or freeze time?
**Status**: ✅ ANSWERED
**Best Practice**:
- Use `uri_without_params` for ignoring dynamic URL parameters
- Create custom matchers for complex scenarios
- Use ERB in cassettes for dynamic content
- Filter/replace dynamic data with placeholders
**Recommendation**:
1. Use `uri_without_params(:timestamp, :order_id)` for URLs
2. Filter sensitive/dynamic data in VCR config
3. Consider Timecop gem for freezing time in tests
4. Use custom matchers for market price matching

### Question 8: Cassette organization preference?
**Question**: One per test, one per file, or grouped by endpoint?
**Status**: ✅ ANSWERED
**Best Practice**:
- Use automatic naming with `configure_rspec_metadata!`
- Organize by API endpoint/functionality in subdirectories
- One cassette per test example (automatic with metadata)
- Group related cassettes in subdirectories
**Recommendation**:
```
spec/fixtures/vcr_cassettes/
  authentication/
  accounts/
  orders/
  positions/
```
With automatic naming: `ClassName/test_description.yml`

### Question 9: How should cassettes be managed in CI?
**Question**: Commit to repo, Git LFS, or generate fresh?
**Status**: ✅ ANSWERED
**Best Practice**:
- Commit cassettes to repo for CI reuse (faster builds)
- Use Git LFS only if cassettes are very large
- Use shallow clones in CI (`fetch-depth: 1`)
- Set recording mode to `:none` in CI
**Recommendation**:
1. Commit cassettes directly to repo (unless >100MB)
2. Use `.gitattributes` to reduce diff noise
3. Configure CI with `VCR_MODE=none` 
4. Use `fetch-depth: 1` in GitHub Actions

### Question 10: Should we implement automatic cassette refresh?
**Question**: Monthly refresh, manual, or automated detection?
**Status**: ✅ ANSWERED
**Best Practice**:
- No built-in auto-expiration in VCR (feature request)
- Delete cassettes liberally when in doubt
- Use environment variable for re-recording
- Implement custom age-checking if needed
**Recommendation**:
1. Manual refresh with `VCR_MODE=rec bundle exec rspec`
2. Create rake task for bulk cassette deletion by age
3. Document refresh schedule (e.g., monthly)
4. Consider custom age-checker in VCR config

### Question 11: How to handle rate-limited endpoints?
**Question**: Add delays or use specific cassettes?
**Status**: ✅ ANSWERED
**Best Practice**:
- Build throttling into the API client itself
- VCR eliminates rate limit issues during playback
- Record cassettes respecting rate limits initially
- Use `:once` mode to avoid re-recording
**Recommendation**:
1. Add rate limiting to API client (not just tests)
2. Record cassettes once with proper delays
3. Playback doesn't need delays (cassettes replay instantly)
4. Consider separate cassettes for rate-limited endpoints

### Question 12: WebSocket/streaming endpoints?
**Question**: Does the API have real-time endpoints needing special handling?
**Status**: ✅ ANSWERED  
**Best Practice**:
- Use specialized libraries like `simple-websocket-vcr` for WebSockets
- Standard VCR doesn't handle WebSocket protocol
- Record multiple messages/frames in WebSocket sessions
- Consider excluding real-time endpoints from VCR
**Recommendation**:
1. Check if Tastytrade API has WebSocket endpoints
2. If yes, use `simple-websocket-vcr` gem
3. If no, standard VCR is sufficient
4. Mock WebSocket connections for unit tests

### Question 13: Should we create a proof-of-concept first?
**Question**: Convert one simple test file first?
**Status**: ✅ ANSWERED
**Best Practice**:
- Start with single external service/API wrapper
- Create dedicated API wrapper classes
- Test wrapper with VCR, mock wrapper elsewhere
- Run tests twice (record then replay)
**Recommendation**:
1. YES - Start with proof-of-concept
2. Choose Session or Client class first
3. Establish patterns and conventions
4. Document learnings before full rollout

### Question 14: Compliance or security requirements?
**Question**: Extra sanitization for financial data? Regulatory requirements?
**Status**: ✅ ANSWERED
**Best Practice**:
- Filter all PII from cassettes (names, addresses, SSNs, account numbers)
- Use minimum necessary data for tests
- Implement access controls for test data
- Regular audits of cassette content
**Recommendation**:
1. Enhance VCR filter_sensitive_data for all PII
2. Use synthetic test data where possible
3. Document data handling procedures
4. Store cassettes securely (encrypted if needed)
5. Regular review of cassettes for leaked data

## Summary

### Questions Answered by Best Practices (10/14)
1. ✅ Test environment - Use sandbox
2. ✅ Credentials handling - .env.test + GitHub secrets
3. ✅ Recording mode - :once default, :none in CI
4. ✅ Production vs sandbox - Always use sandbox
5. ✅ Test priorities - Auth → Account → Orders → CLI
6. ✅ Migration strategy - Keep mocks initially, parallel transition
7. ✅ Dynamic data - Custom matchers and filters
8. ✅ Cassette organization - Auto-naming by endpoint
9. ✅ CI management - Commit cassettes, use :none mode
10. ✅ Refresh strategy - Manual with rake task
11. ✅ Rate limiting - Build into client, record once
12. ✅ WebSocket - Use specialized gem if needed
13. ✅ Proof-of-concept - Yes, start small
14. ✅ Compliance - Filter all PII, secure storage

### Outstanding Questions for User (1/14)
1. ~~**Do you have Tastytrade sandbox credentials?**~~ - ✅ CONFIRMED: User has sandbox credentials

### Critical Sandbox Behavior Note
**IMPORTANT**: Tastytrade sandbox endpoints behave like production - they only route orders during normal market hours. This impacts:
- Order placement tests (will fail outside market hours)
- Order validation tests (may behave differently based on market status)
- Any tests that depend on real-time market data

### Handling Market Hours Limitation

#### Strategy 1: Time-Independent Cassettes (RECOMMENDED)
1. **Record cassettes during market hours**
   - Schedule recording sessions during market hours (9:30 AM - 4:00 PM ET)
   - Use a specific day/time for consistency
   - Document the recording time in cassette metadata

2. **Use `:once` mode strictly**
   - Never re-record automatically
   - Cassettes remain valid regardless of current time
   - Tests pass 24/7 once recorded

3. **Separate market-dependent tests**
   ```ruby
   context "market hour dependent", :market_hours_only do
     # Tests that need live market
   end
   
   context "market hour independent", :vcr do
     # Most tests with cassettes
   end
   ```

#### Strategy 2: Mock Market Hours in Tests
1. **Use Timecop to freeze time during playback**
   ```ruby
   around(:each, :vcr) do |example|
     # Freeze to a known market hour when cassette was recorded
     Timecop.freeze(cassette_recorded_at) do
       example.run
     end
   end
   ```

2. **Add metadata to cassettes**
   ```ruby
   VCR.configure do |c|
     c.before_record do |interaction|
       interaction.response.headers['X-Cassette-Recorded-At'] = Time.current.iso8601
       interaction.response.headers['X-Market-Status'] = market_open? ? 'open' : 'closed'
     end
   end
   ```

### Handling Sandbox Credentials

#### Secure Credential Management
1. **Local Development (.env.test)**
   ```bash
   # .env.test (gitignored)
   TASTYTRADE_SANDBOX_USERNAME=your_sandbox_username
   TASTYTRADE_SANDBOX_PASSWORD=your_sandbox_password
   TASTYTRADE_SANDBOX_ACCOUNT=your_sandbox_account_number
   ```

2. **CI/CD (GitHub Secrets)**
   - Store same credentials as GitHub secrets
   - Reference in workflow: `${{ secrets.TASTYTRADE_SANDBOX_USERNAME }}`

3. **VCR Configuration Enhancement**
   ```ruby
   VCR.configure do |config|
     # Enhanced filtering for Tastytrade-specific data
     config.filter_sensitive_data('<SANDBOX_USERNAME>') { ENV['TASTYTRADE_SANDBOX_USERNAME'] }
     config.filter_sensitive_data('<SANDBOX_ACCOUNT>') { ENV['TASTYTRADE_SANDBOX_ACCOUNT'] }
     
     # Filter account numbers from responses
     config.before_record do |interaction|
       if interaction.response.body
         body = interaction.response.body
         # Replace any account numbers in response
         body.gsub!(/5W[A-Z0-9]{6}/, '<ACCOUNT_NUMBER>')
       end
     end
   end
   ```

4. **Test Helper for Sandbox Sessions**
   ```ruby
   # spec/support/sandbox_helpers.rb
   module SandboxHelpers
     def sandbox_session
       @sandbox_session ||= VCR.use_cassette('authentication/sandbox_login') do
         Tastytrade::Session.new(
           username: ENV['TASTYTRADE_SANDBOX_USERNAME'],
           password: ENV['TASTYTRADE_SANDBOX_PASSWORD'],
           is_test: true
         ).login
       end
     end
     
     def with_market_hours_check
       if !VCR.current_cassette && !market_open?
         skip "Skipping test - market closed and no cassette available"
       end
       yield
     end
   end
   ```

### Recommended Implementation Order (UPDATED)
1. ~~Obtain/confirm sandbox credentials~~ ✅ Complete
2. **Set up credential management** (.env.test + GitHub secrets)
3. **Record initial cassettes during market hours**
4. Create proof-of-concept with Session class
5. Establish VCR helper patterns with market hour handling
6. Convert tests incrementally following priority order
7. Document recording schedule and market hour dependencies