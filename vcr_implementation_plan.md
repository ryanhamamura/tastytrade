# VCR Implementation Plan for Tastytrade Gem

## Executive Summary
Implement VCR cassettes to replace existing mocks, accounting for Tastytrade sandbox's market-hours-only order routing behavior.

## Phase 1: Foundation Setup (Week 1)

### 1.1 Credential Management
```bash
# Create .env.test (add to .gitignore)
TASTYTRADE_SANDBOX_USERNAME=your_username
TASTYTRADE_SANDBOX_PASSWORD=your_password
TASTYTRADE_SANDBOX_ACCOUNT=your_account
TASTYTRADE_ENVIRONMENT=sandbox
```

### 1.2 Enhanced VCR Configuration
```ruby
# spec/spec_helper.rb
require 'dotenv'
Dotenv.load('.env.test') if File.exist?('.env.test')

VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  
  # Recording mode management
  vcr_mode = ENV['VCR_MODE'] =~ /rec/i ? :all : :once
  vcr_mode = :none if ENV['CI'] # Prevent recording in CI
  
  config.default_cassette_options = {
    record: vcr_mode,
    match_requests_on: [:method, :uri, :body],
    allow_playback_repeats: true,
    record_on_error: false
  }
  
  # Enhanced sensitive data filtering
  config.filter_sensitive_data('<SANDBOX_USERNAME>') { ENV['TASTYTRADE_SANDBOX_USERNAME'] }
  config.filter_sensitive_data('<SANDBOX_PASSWORD>') { ENV['TASTYTRADE_SANDBOX_PASSWORD'] }
  config.filter_sensitive_data('<SANDBOX_ACCOUNT>') { ENV['TASTYTRADE_SANDBOX_ACCOUNT'] }
  
  # Filter dynamic/sensitive data from responses
  config.before_record do |interaction|
    if interaction.response.body
      body = interaction.response.body
      
      # Filter account numbers (format: 5WX12345)
      body.gsub!(/5W[A-Z0-9]{6,8}/, '<ACCOUNT_NUMBER>')
      
      # Filter session tokens
      body.gsub!(/"session-token":"[^"]+/, '"session-token":"<SESSION_TOKEN>')
      body.gsub!(/"remember-token":"[^"]+/, '"remember-token":"<REMEMBER_TOKEN>')
      
      # Filter personal information
      body.gsub!(/"email":"[^"]+/, '"email":"<EMAIL>')
      body.gsub!(/"external-id":"[^"]+/, '"external-id":"<EXTERNAL_ID>')
      
      # Add recording metadata
      interaction.response.headers['X-VCR-Recorded-At'] = Time.current.iso8601
      interaction.response.headers['X-VCR-Market-Status'] = market_open? ? 'open' : 'closed'
    end
  end
  
  # Ignore certain dynamic parameters
  config.before_playback do |interaction|
    # Normalize timestamps in URLs if needed
    interaction.request.uri.gsub!(/timestamp=\d+/, 'timestamp=NORMALIZED')
  end
end
```

### 1.3 Market Hours Helper
```ruby
# spec/support/market_hours_helper.rb
module MarketHoursHelper
  def market_open?(time = Time.current)
    # Convert to ET (Eastern Time)
    et_time = time.in_time_zone('America/New_York')
    
    # Check if weekend
    return false if et_time.saturday? || et_time.sunday?
    
    # Check if US market holiday (simplified - expand as needed)
    holidays = [
      Date.new(et_time.year, 1, 1),   # New Year's Day
      Date.new(et_time.year, 7, 4),   # Independence Day
      Date.new(et_time.year, 12, 25), # Christmas
      # Add more holidays as needed
    ]
    return false if holidays.include?(et_time.to_date)
    
    # Check market hours (9:30 AM - 4:00 PM ET)
    market_open = et_time.change(hour: 9, min: 30)
    market_close = et_time.change(hour: 16, min: 0)
    
    et_time >= market_open && et_time <= market_close
  end
  
  def skip_outside_market_hours
    unless market_open? || VCR.current_cassette
      skip "Test requires market hours or existing cassette"
    end
  end
  
  def next_market_open_time
    time = Time.current.in_time_zone('America/New_York')
    
    # If it's before 9:30 AM on a weekday, return today's open
    if !time.saturday? && !time.sunday? && time.hour < 9 || (time.hour == 9 && time.min < 30)
      return time.change(hour: 9, min: 30)
    end
    
    # Otherwise, find next weekday
    loop do
      time = time.tomorrow
      break if !time.saturday? && !time.sunday?
    end
    
    time.change(hour: 9, min: 30)
  end
end

RSpec.configure do |config|
  config.include MarketHoursHelper
end
```

## Phase 2: Proof of Concept - Session Class (Week 1)

### 2.1 Convert Session Tests
```ruby
# spec/tastytrade/session_vcr_spec.rb
require 'spec_helper'

RSpec.describe Tastytrade::Session, :vcr do
  let(:sandbox_credentials) do
    {
      username: ENV['TASTYTRADE_SANDBOX_USERNAME'],
      password: ENV['TASTYTRADE_SANDBOX_PASSWORD'],
      is_test: true
    }
  end
  
  describe "#login" do
    context "with valid credentials" do
      it "authenticates successfully" do
        session = described_class.new(**sandbox_credentials).login
        
        expect(session.session_token).not_to be_nil
        expect(session.user).to be_a(Tastytrade::Models::User)
        expect(session.user.email).not_to be_nil
      end
    end
    
    context "with invalid credentials" do
      it "raises InvalidCredentialsError" do
        invalid_creds = sandbox_credentials.merge(password: 'wrong_password')
        
        expect {
          described_class.new(**invalid_creds).login
        }.to raise_error(Tastytrade::InvalidCredentialsError)
      end
    end
  end
  
  describe "#validate" do
    let(:session) { described_class.new(**sandbox_credentials).login }
    
    it "validates active session" do
      expect(session.validate).to be true
    end
  end
  
  describe "#destroy" do
    let(:session) { described_class.new(**sandbox_credentials).login }
    
    it "destroys the session" do
      session.destroy
      expect(session.session_token).to be_nil
    end
  end
end
```

### 2.2 Recording Schedule
```markdown
# Recording Schedule

## Initial Recording Session
- **Date**: [Schedule a weekday]
- **Time**: 10:00 AM - 3:00 PM ET (avoiding market open/close volatility)
- **Checklist**:
  - [ ] Verify sandbox credentials work
  - [ ] Market is open
  - [ ] No US market holidays
  - [ ] VCR_MODE=rec environment variable set

## Recording Commands
```bash
# Record all cassettes
VCR_MODE=rec bundle exec rspec spec/tastytrade/session_vcr_spec.rb

# Verify cassettes work
bundle exec rspec spec/tastytrade/session_vcr_spec.rb
```

## Phase 3: Order-Related Tests (Week 2)

### 3.1 Order Placement Tests with Market Hours
```ruby
# spec/tastytrade/models/account_place_order_vcr_spec.rb
RSpec.describe "Order Placement", :vcr do
  include MarketHoursHelper
  
  let(:session) { sandbox_session } # From helper
  let(:account) { session.accounts.first }
  
  describe "placing orders" do
    context "during market hours" do
      before { skip_outside_market_hours }
      
      it "places a limit order" do
        order = Tastytrade::Order.new(
          type: Tastytrade::OrderType::LIMIT,
          time_in_force: Tastytrade::OrderTimeInForce::DAY,
          legs: build_spy_leg(100, "Buy to Open"),
          price: 430.00
        )
        
        response = account.place_order(session, order)
        
        expect(response).to be_a(Tastytrade::Models::OrderResponse)
        expect(response.order_id).not_to be_nil
      end
    end
    
    context "order validation (market independent)" do
      it "validates order without placing" do
        order = Tastytrade::Order.new(
          type: Tastytrade::OrderType::LIMIT,
          time_in_force: Tastytrade::OrderTimeInForce::DAY,
          legs: build_spy_leg(100, "Buy to Open"),
          price: 430.00
        )
        
        # Dry run doesn't require market hours
        response = account.place_order(session, order, dry_run: true)
        
        expect(response.buying_power_effect).not_to be_nil
      end
    end
  end
  
  private
  
  def build_spy_leg(quantity, action)
    Tastytrade::OrderLeg.new(
      action: action,
      symbol: "SPY",
      quantity: quantity
    )
  end
end
```

## Phase 4: Gradual Migration (Weeks 3-4)

### 4.1 Parallel Testing Strategy
```ruby
# spec/spec_helper.rb
RSpec.configure do |config|
  # Run VCR tests only when marked
  config.around(:each) do |example|
    if example.metadata[:vcr]
      example.run
    elsif example.metadata[:use_mocks]
      # Keep existing mock behavior
      VCR.turned_off { example.run }
    else
      # Default to mocks for now
      VCR.turned_off { example.run }
    end
  end
end
```

### 4.2 Migration Checklist
- [ ] Session tests converted
- [ ] Client HTTP tests converted
- [ ] Account model tests converted
- [ ] Balance retrieval tests converted
- [ ] Order placement tests converted
- [ ] Order history tests converted
- [ ] Position tests converted
- [ ] CLI tests converted (mock the API client layer)

## Phase 5: CI/CD Integration (Week 4)

### 5.1 GitHub Actions Configuration
```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    env:
      VCR_MODE: none # Never record in CI
      TASTYTRADE_SANDBOX_USERNAME: ${{ secrets.TASTYTRADE_SANDBOX_USERNAME }}
      TASTYTRADE_SANDBOX_PASSWORD: ${{ secrets.TASTYTRADE_SANDBOX_PASSWORD }}
      TASTYTRADE_SANDBOX_ACCOUNT: ${{ secrets.TASTYTRADE_SANDBOX_ACCOUNT }}
    
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 1 # Shallow clone for speed
      
      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.2'
          bundler-cache: true
      
      - name: Run tests
        run: bundle exec rspec
```

### 5.2 Cassette Maintenance
```ruby
# lib/tasks/vcr.rake
namespace :vcr do
  desc "Delete cassettes older than 30 days"
  task :clean_old do
    Dir.glob("spec/fixtures/vcr_cassettes/**/*.yml").each do |cassette|
      if File.mtime(cassette) < 30.days.ago
        puts "Deleting old cassette: #{cassette}"
        File.delete(cassette)
      end
    end
  end
  
  desc "Re-record all cassettes (run during market hours)"
  task :refresh_all do
    unless market_open?
      puts "ERROR: Market is closed. Run during market hours (9:30 AM - 4:00 PM ET)"
      puts "Next market open: #{next_market_open_time}"
      exit 1
    end
    
    ENV['VCR_MODE'] = 'rec'
    system('bundle exec rspec --tag vcr')
  end
  
  desc "Show cassette statistics"
  task :stats do
    cassettes = Dir.glob("spec/fixtures/vcr_cassettes/**/*.yml")
    total_size = cassettes.sum { |f| File.size(f) }
    
    puts "Total cassettes: #{cassettes.count}"
    puts "Total size: #{(total_size / 1024.0 / 1024.0).round(2)} MB"
    puts "Oldest cassette: #{cassettes.min_by { |f| File.mtime(f) }}"
    puts "Newest cassette: #{cassettes.max_by { |f| File.mtime(f) }}"
  end
end
```

## Phase 6: Documentation (Week 5)

### 6.1 Developer Guide
Create `docs/vcr_testing.md`:
- How to record new cassettes
- Market hours requirements
- Credential setup
- Troubleshooting guide
- Best practices

### 6.2 Git Configuration
```gitignore
# .gitignore
.env.test
.env.local

# .gitattributes  
spec/fixtures/vcr_cassettes/**/*.yml -diff
```

## Success Metrics
- [ ] All tests pass with VCR cassettes
- [ ] CI build time reduced by >50%
- [ ] Tests work offline
- [ ] No sensitive data in cassettes
- [ ] Documentation complete
- [ ] Team trained on VCR workflow

## Risk Mitigation
1. **Market Hours Dependency**: Use strict `:once` recording mode
2. **Sensitive Data Leaks**: Multiple layers of filtering
3. **Cassette Bloat**: Regular cleanup tasks
4. **API Changes**: Monthly cassette refresh schedule
5. **Team Adoption**: Comprehensive documentation and helpers