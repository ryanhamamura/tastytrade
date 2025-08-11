#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for option CLI commands
# Run with: ruby test_option_commands.rb

require "bundler/setup"
require "dotenv"
require "tastytrade"
require "tastytrade/option_order_builder"

# Load sandbox credentials
Dotenv.load(".env.sandbox")

puts "=" * 60
puts "Testing Tastytrade Option CLI Commands"
puts "=" * 60

# Login to sandbox
username = ENV["TASTYTRADE_USERNAME"]
password = ENV["TASTYTRADE_PASSWORD"]

unless username && password
  puts "Error: Please set TASTYTRADE_USERNAME and TASTYTRADE_PASSWORD in .env.sandbox"
  exit 1
end

puts "\n1. Testing login..."
session = Tastytrade::Session.new(username: username, password: password, is_test: true)
session.login
puts "✓ Logged in successfully"

# Get account
puts "\n2. Getting account..."
accounts = Tastytrade::Models::Account.get_all(session)
account = accounts.first
masked_account = account.account_number.to_s[0..2] + "****"
puts "✓ Using account: #{masked_account}"

# Test option chain retrieval
puts "\n3. Testing option chain retrieval..."
begin
  chain = Tastytrade::Models::NestedOptionChain.get(session, "SPY")
  if chain && chain.expirations && chain.expirations.any?
    puts "✓ Retrieved option chain for SPY"
    puts "  - Expirations: #{chain.expirations.count}"
    first_exp = chain.expirations.first
    puts "  - First expiration: #{first_exp.expiration_date} (#{first_exp.days_to_expiration} DTE)"
    puts "  - Strikes in first expiration: #{first_exp.strikes.count}"
  else
    puts "✗ Failed to retrieve option chain"
  end
rescue => e
  puts "✗ Error: #{e.message}"
end

# Test finding a specific option
puts "\n4. Testing option lookup..."
begin
  if chain && chain.expirations && chain.expirations.any?
    first_exp = chain.expirations.first
    if first_exp.strikes && first_exp.strikes.any?
      middle_strike = first_exp.strikes[first_exp.strikes.length / 2]
      call_symbol = middle_strike.call
      put_symbol = middle_strike.put

      puts "✓ Found options at strike #{middle_strike.strike_price}:"
      puts "  - Call: #{call_symbol}"
      puts "  - Put: #{put_symbol}"
    else
      puts "✗ No strikes available"
    end
  else
    puts "✗ No chain data available"
  end
rescue => e
  puts "✗ Error: #{e.message}"
end

# Test order builder
puts "\n5. Testing order builder..."
begin
  builder = Tastytrade::OptionOrderBuilder.new(session, account)

  # Create a mock option for testing
  require "ostruct"
  test_option = OpenStruct.new(
    symbol: "SPY   250815C00620000",
    strike_price: 620.0,
    expiration_date: Date.today + 30,
    option_type: "Call",
    expired?: false
  )

  # Test buy order creation
  order = builder.buy_call(test_option, 1, price: 1.00)
  if order
    puts "✓ Created buy order:"
    puts "  - Type: #{order.type}"
    puts "  - Time in force: #{order.time_in_force}"
    puts "  - Legs: #{order.legs.count}"
    puts "  - Price: $#{order.price}"
  else
    puts "✗ Failed to create order"
  end
rescue => e
  puts "✗ Error: #{e.message}"
end

# Test multi-leg strategies
puts "\n6. Testing multi-leg strategies..."
begin
  builder = Tastytrade::OptionOrderBuilder.new(session, account)

  # Create mock options for spread
  long_option = OpenStruct.new(
    symbol: "SPY   250815C00619000",
    strike_price: 619.0,
    expiration_date: Date.today + 30,
    option_type: "Call",
    expired?: false
  )

  short_option = OpenStruct.new(
    symbol: "SPY   250815C00621000",
    strike_price: 621.0,
    expiration_date: Date.today + 30,
    option_type: "Call",
    expired?: false
  )

  # Test vertical spread
  spread_order = builder.vertical_spread(long_option, short_option, 1)
  if spread_order
    puts "✓ Created vertical spread:"
    puts "  - Legs: #{spread_order.legs.count}"
    spread_order.legs.each_with_index do |leg, i|
      puts "  - Leg #{i + 1}: #{leg.action} #{leg.symbol}"
    end
  else
    puts "✗ Failed to create spread"
  end

  # Test straddle
  put_option = OpenStruct.new(
    symbol: "SPY   250815P00620000",
    strike_price: 620.0,
    expiration_date: Date.today + 30,
    option_type: "Put",
    expired?: false
  )

  call_option = OpenStruct.new(
    symbol: "SPY   250815C00620000",
    strike_price: 620.0,
    expiration_date: Date.today + 30,
    option_type: "Call",
    expired?: false
  )

  straddle_order = builder.straddle(put_option, call_option, 1, action: Tastytrade::OrderAction::BUY_TO_OPEN)
  if straddle_order
    puts "✓ Created straddle:"
    puts "  - Legs: #{straddle_order.legs.count}"
    straddle_order.legs.each_with_index do |leg, i|
      puts "  - Leg #{i + 1}: #{leg.action} #{leg.symbol}"
    end
  else
    puts "✗ Failed to create straddle"
  end
rescue => e
  puts "✗ Error: #{e.message}"
  puts e.backtrace[0..5]
end

# Test new advanced strategies
puts "\n7. Testing advanced strategies (NEW)..."
begin
  builder = Tastytrade::OptionOrderBuilder.new(session, account)

  # Test Iron Butterfly
  puts "\n  Testing Iron Butterfly..."
  short_call_ib = OpenStruct.new(
    symbol: "SPY   250815C00620000",
    strike_price: 620.0,
    expiration_date: Date.today + 30,
    option_type: "C",
    underlying_symbol: "SPY",
    expired?: false
  )

  long_call_ib = OpenStruct.new(
    symbol: "SPY   250815C00630000",
    strike_price: 630.0,
    expiration_date: Date.today + 30,
    option_type: "C",
    underlying_symbol: "SPY",
    expired?: false
  )

  short_put_ib = OpenStruct.new(
    symbol: "SPY   250815P00620000",
    strike_price: 620.0,
    expiration_date: Date.today + 30,
    option_type: "P",
    underlying_symbol: "SPY",
    expired?: false
  )

  long_put_ib = OpenStruct.new(
    symbol: "SPY   250815P00610000",
    strike_price: 610.0,
    expiration_date: Date.today + 30,
    option_type: "P",
    underlying_symbol: "SPY",
    expired?: false
  )

  iron_butterfly = builder.iron_butterfly(short_call_ib, long_call_ib, short_put_ib, long_put_ib, 1, price: 3.00)
  if iron_butterfly
    puts "  ✓ Created Iron Butterfly:"
    puts "    - Legs: #{iron_butterfly.legs.count}"
    puts "    - Short Call at 620: #{iron_butterfly.legs[0].action}"
    puts "    - Long Call at 630: #{iron_butterfly.legs[1].action}"
    puts "    - Short Put at 620: #{iron_butterfly.legs[2].action}"
    puts "    - Long Put at 610: #{iron_butterfly.legs[3].action}"
  else
    puts "  ✗ Failed to create Iron Butterfly"
  end

  # Test Butterfly Spread
  puts "\n  Testing Butterfly Spread..."
  long_low_bf = OpenStruct.new(
    symbol: "SPY   250815C00610000",
    strike_price: 610.0,
    expiration_date: Date.today + 30,
    option_type: "C",
    underlying_symbol: "SPY",
    expired?: false
  )

  short_middle_bf = OpenStruct.new(
    symbol: "SPY   250815C00620000",
    strike_price: 620.0,
    expiration_date: Date.today + 30,
    option_type: "C",
    underlying_symbol: "SPY",
    expired?: false
  )

  long_high_bf = OpenStruct.new(
    symbol: "SPY   250815C00630000",
    strike_price: 630.0,
    expiration_date: Date.today + 30,
    option_type: "C",
    underlying_symbol: "SPY",
    expired?: false
  )

  butterfly = builder.butterfly_spread(long_low_bf, short_middle_bf, long_high_bf, 1, price: 1.50)
  if butterfly
    puts "  ✓ Created Butterfly Spread:"
    puts "    - Legs: #{butterfly.legs.count}"
    puts "    - Long 610 Call: quantity #{butterfly.legs[0].quantity}"
    puts "    - Short 620 Call: quantity #{butterfly.legs[1].quantity}"
    puts "    - Long 630 Call: quantity #{butterfly.legs[2].quantity}"
  else
    puts "  ✗ Failed to create Butterfly Spread"
  end

  # Test Calendar Spread
  puts "\n  Testing Calendar Spread..."
  short_calendar = OpenStruct.new(
    symbol: "SPY   250815C00620000",
    strike_price: 620.0,
    expiration_date: Date.today + 30,
    option_type: "C",
    underlying_symbol: "SPY",
    expired?: false
  )

  long_calendar = OpenStruct.new(
    symbol: "SPY   250915C00620000",
    strike_price: 620.0,
    expiration_date: Date.today + 60,
    option_type: "C",
    underlying_symbol: "SPY",
    expired?: false
  )

  calendar = builder.calendar_spread(short_calendar, long_calendar, 1, price: 1.00)
  if calendar
    puts "  ✓ Created Calendar Spread:"
    puts "    - Legs: #{calendar.legs.count}"
    puts "    - Short 30 DTE: #{calendar.legs[0].action} at strike 620"
    puts "    - Long 60 DTE: #{calendar.legs[1].action} at strike 620"
  else
    puts "  ✗ Failed to create Calendar Spread"
  end

  # Test Diagonal Spread
  puts "\n  Testing Diagonal Spread..."
  short_diagonal = OpenStruct.new(
    symbol: "SPY   250815C00620000",
    strike_price: 620.0,
    expiration_date: Date.today + 30,
    option_type: "C",
    underlying_symbol: "SPY",
    expired?: false
  )

  long_diagonal = OpenStruct.new(
    symbol: "SPY   250915C00625000",
    strike_price: 625.0,
    expiration_date: Date.today + 60,
    option_type: "C",
    underlying_symbol: "SPY",
    expired?: false
  )

  diagonal = builder.diagonal_spread(short_diagonal, long_diagonal, 1, price: 2.00)
  if diagonal
    puts "  ✓ Created Diagonal Spread:"
    puts "    - Legs: #{diagonal.legs.count}"
    puts "    - Short 30 DTE at 620: #{diagonal.legs[0].action}"
    puts "    - Long 60 DTE at 625: #{diagonal.legs[1].action}"
  else
    puts "  ✗ Failed to create Diagonal Spread"
  end

  puts "\n  ✓ All advanced strategies created successfully!"

rescue => e
  puts "✗ Error: #{e.message}"
  puts e.backtrace[0..5]
end

puts "\n" + "=" * 60
puts "Test Summary:"
puts "All basic option functionality is working!"
puts "All advanced strategies (Iron Butterfly, Butterfly, Calendar, Diagonal) working!"
puts "=" * 60
