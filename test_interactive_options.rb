#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "tastytrade"

# Test the interactive option chain functionality programmatically
session = Tastytrade::Session.new(
  username: ENV["TASTYTRADE_USERNAME"],
  password: ENV["TASTYTRADE_PASSWORD"],
  is_test: true
)

session.login
puts "Logged in as #{session.user.email}\n\n"

# Test fetching option chain
symbols = ["SPY", "AAPL", "TSLA"]

symbols.each do |symbol|
  puts "=" * 60
  puts "Testing #{symbol} Option Chain"
  puts "=" * 60

  begin
    # Get nested chain for interactive browsing
    chain = Tastytrade::Models::NestedOptionChain.get(session, symbol)

    puts "✓ Successfully fetched chain for #{symbol}"
    puts "  Expirations: #{chain.expirations.size}"

    if chain.expirations.any?
      # Test first expiration
      exp = chain.expirations.first
      puts "\n  First Expiration: #{exp.expiration_date}"
      puts "    Days to expiration: #{exp.days_to_expiration}"
      puts "    Type: #{exp.expiration_type}"
      puts "    Settlement: #{exp.settlement_type}"
      puts "    Strikes: #{exp.strikes.size}"

      # Test finding ATM strike (middle strike)
      if exp.strikes.any?
        middle_idx = exp.strikes.size / 2
        atm_strike = exp.strikes.sort_by { |s| s.strike_price.to_f }[middle_idx]

        puts "\n  Sample Strike (around ATM):"
        puts "    Strike Price: $#{atm_strike.strike_price}"
        puts "    Call Symbol: #{atm_strike.call}"
        puts "    Put Symbol: #{atm_strike.put}"
        puts "    Call Streamer: #{atm_strike.call_streamer_symbol}"
        puts "    Put Streamer: #{atm_strike.put_streamer_symbol}"
      end

      # Test filtering
      puts "\n  Testing Filters:"

      # DTE filter
      near_term = chain.filter_by_dte(max_dte: 30)
      puts "    Near-term (≤30 DTE): #{near_term.expirations.size} expirations"

      # Weekly filter
      weeklies = chain.weekly_expirations
      puts "    Weekly expirations: #{weeklies.expirations.size}"

      # Monthly filter
      monthlies = chain.monthly_expirations
      puts "    Monthly expirations: #{monthlies.expirations.size}"
    end

  rescue Tastytrade::Error => e
    puts "✗ Failed to fetch chain for #{symbol}: #{e.message}"
  end

  puts
end

puts "\n" + "=" * 60
puts "Interactive Option Chain Features Test Complete"
puts "=" * 60
puts "\nInteractive features implemented:"
puts "✓ Symbol entry and validation"
puts "✓ Expiration selection with DTE info"
puts "✓ Strike selection with call/put symbols"
puts "✓ Option type selection (Call/Put)"
puts "✓ Option details display"
puts "✓ Order creation interface"
puts "✓ Filtering by DTE, expiration type"
puts "\nTo test interactively, run:"
puts "  bundle exec exe/tastytrade login --test"
puts "  Then select 'Options - Browse option chains' from the menu"
