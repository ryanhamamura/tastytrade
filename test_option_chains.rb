#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "tastytrade"
require "pp"

# Test script to verify option chain API endpoints
# Run with: ruby test_option_chains.rb

# Use sandbox environment for testing
puts "Using credentials:"
puts "  Username: #{ENV["TASTYTRADE_SANDBOX_USERNAME"]}"
puts "  Password: #{"*" * (ENV["TASTYTRADE_SANDBOX_PASSWORD"]&.length || 0)}"
puts "  Sandbox mode: true"
puts ""

session = Tastytrade::Session.new(
  username: ENV["TASTYTRADE_SANDBOX_USERNAME"] || ENV["TT_USERNAME"],
  password: ENV["TASTYTRADE_SANDBOX_PASSWORD"] || ENV["TT_PASSWORD"],
  is_test: true
)

begin
  puts "Logging in to Tastytrade API..."
  session.login
  puts "✓ Logged in successfully as #{session.user.email}"
  puts "-" * 50

  # Test 1: Compact Option Chain
  puts "\n1. Testing Compact Option Chain (OptionChain.get_chain)"
  begin
    # First get raw response to understand structure
    raw_response = session.get("/option-chains/SPY/compact")
    puts "  Raw response structure:"
    puts "    Keys: #{raw_response.keys.join(", ")}"
    puts "    Data keys: #{raw_response["data"].keys.join(", ")}" if raw_response["data"].is_a?(Hash)

    # Check the actual data structure
    if raw_response["data"] && raw_response["data"]["items"]
      items = raw_response["data"]["items"]
      puts "    Items count: #{items.size}"
      if items.first
        puts "    First item keys: #{items.first.keys.join(", ")}"
        puts "    Sample item: #{items.first.inspect[0..200]}..."
      end
    end

    chain = Tastytrade::Models::OptionChain.get_chain(session, "SPY")
    puts "✓ Compact chain retrieved successfully"
    puts "  Underlying: #{chain.underlying_symbol}"
    puts "  Expirations: #{chain.expirations.keys.size}"
    puts "  First expiration: #{chain.expirations.keys.first}"
    puts "  Options in first expiration: #{chain.expirations.values.first&.size}"
  rescue => e
    puts "✗ Failed: #{e.class} - #{e.message}"
    puts "  Endpoint: /option-chains/SPY/compact"
    puts "  Backtrace: #{e.backtrace.first(3).join("\n")}"
  end

  # Test 2: Nested Option Chain
  puts "\n2. Testing Nested Option Chain (NestedOptionChain.get)"
  begin
    # First get raw response to understand structure
    raw_response = session.get("/option-chains/SPY/nested")
    puts "  Raw response structure:"
    puts "    Keys: #{raw_response.keys.join(", ")}"
    puts "    Data keys: #{raw_response["data"].keys.join(", ")}" if raw_response["data"].is_a?(Hash)

    nested_chain = Tastytrade::Models::NestedOptionChain.get(session, "SPY")
    puts "✓ Nested chain retrieved successfully"
    puts "  Underlying: #{nested_chain.underlying_symbol}"
    puts "  Expirations: #{nested_chain.expirations.size}"
    if nested_chain.expirations.first
      exp = nested_chain.expirations.first
      puts "  First expiration: #{exp.expiration_date}"
      puts "  Strikes in first expiration: #{exp.strikes.size}"
    end
  rescue => e
    puts "✗ Failed: #{e.class} - #{e.message}"
    puts "  Endpoint: /option-chains/SPY/nested"
  end

  # Test 3: Check what actual endpoints the API expects
  puts "\n3. Testing raw API endpoints to find correct paths"

  # Try different endpoint variations
  test_endpoints = [
    "/option-chains/SPY/compact",
    "/option-chains/SPY/nested",
    "/instruments/option-chains/SPY/compact",
    "/instruments/option-chains/SPY/nested",
    "/api/option-chains/SPY/compact",
    "/api/option-chains/SPY/nested"
  ]

  puts "\nTrying different endpoint paths:"
  test_endpoints.each do |endpoint|
    begin
      response = session.get(endpoint)
      puts "✓ #{endpoint} - SUCCESS"
      puts "  Response keys: #{response.keys.join(", ")}" if response.is_a?(Hash)
      break # Found working endpoint
    rescue => e
      puts "✗ #{endpoint} - #{e.message.split("\n").first}"
    end
  end

rescue Tastytrade::Error => e
  puts "ERROR: #{e.message}"
  puts "Make sure you have valid sandbox credentials set in environment variables:"
  puts "  TASTYTRADE_SANDBOX_USERNAME"
  puts "  TASTYTRADE_SANDBOX_PASSWORD"
end
