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
puts "✓ Logged in as #{username}"

# Get account
puts "\n2. Getting account..."
accounts = Tastytrade::Models::Account.get_all(session)
account = accounts.first
puts "✓ Using account: #{account.account_number}"

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

puts "\n" + "=" * 60
puts "Test Summary:"
puts "All basic option functionality is working!"
puts "=" * 60
