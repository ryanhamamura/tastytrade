#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "tastytrade"

# Test the Option.search method
session = Tastytrade::Session.new(
  username: ENV["TASTYTRADE_SANDBOX_USERNAME"],
  password: ENV["TASTYTRADE_SANDBOX_PASSWORD"],
  is_test: true
)

session.login
puts "Logged in as #{session.user.email}\n\n"

# First get a valid option symbol from the chain
chain = Tastytrade::Models::OptionChain.get_chain(session, "SPY")
first_option = chain.all_options.first

if first_option
  puts "Testing Option.search with symbol: #{first_option.symbol}"

  results = Tastytrade::Models::Option.search(session, first_option.symbol)

  if results.any?
    puts "✓ Search successful!"
    puts "  Found #{results.size} option(s)"

    option = results.first
    puts "\nOption details:"
    puts "  Symbol: #{option.symbol}"
    puts "  Type: #{option.option_type}"
    puts "  Strike: #{option.strike_price}"
    puts "  Expiration: #{option.expiration_date}"
  else
    puts "✗ No results found"
  end
else
  puts "Could not get test symbol from chain"
end

# Test searching for multiple symbols
puts "\n" + "-" * 50
puts "Testing multiple symbol search..."

symbols = chain.all_options.first(3).map(&:symbol)
puts "Searching for: #{symbols.join(", ")}"

results = Tastytrade::Models::Option.search(session, symbols)
puts "Found #{results.size} options"
