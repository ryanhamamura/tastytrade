#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "tastytrade"
require "cgi"

# Test various option-related endpoints
session = Tastytrade::Session.new(
  username: ENV["TASTYTRADE_SANDBOX_USERNAME"],
  password: ENV["TASTYTRADE_SANDBOX_PASSWORD"],
  is_test: true
)

session.login
puts "Testing option-related endpoints...\n\n"

# Get a test symbol
chain = Tastytrade::Models::OptionChain.get_chain(session, "SPY")
test_symbol = chain.all_options.first&.symbol&.strip || "SPY250811C00400000"
url_safe_symbol = CGI.escape(test_symbol)
puts "Using test symbol: #{test_symbol}"
puts "URL encoded: #{url_safe_symbol}\n\n"

endpoints = [
  "/instruments/options",
  "/options",
  "/instruments",
  "/option-symbols/#{url_safe_symbol}",
  "/instruments/#{url_safe_symbol}",
  "/instruments/equity-options",
  "/instruments/equity-options/#{url_safe_symbol}",
  "/equity-options",
  "/equity-options/#{url_safe_symbol}"
]

endpoints.each do |endpoint|
  begin
    puts "Testing: #{endpoint}"

    # Try with symbols parameter for search endpoints
    if endpoint.include?("options") && !endpoint.include?(test_symbol)
      response = session.get(endpoint, { symbols: test_symbol })
    else
      response = session.get(endpoint)
    end

    puts "  ✓ SUCCESS"
    puts "    Response keys: #{response.keys.join(", ")}"

    if response["data"]
      if response["data"].is_a?(Hash)
        puts "    Data keys: #{response["data"].keys.join(", ")}"
      elsif response["data"].is_a?(Array)
        puts "    Data is array with #{response["data"].size} items"
      end
    end
    puts ""

  rescue Tastytrade::Error => e
    puts "  ✗ FAILED: #{e.message.split("\n").first}"
    puts ""
  end
end

# Also test if options are part of instruments endpoint with type filter
puts "Testing instruments with type filter..."
begin
  response = session.get("/instruments", { symbols: test_symbol, instrument_type: "Equity Option" })
  puts "  ✓ SUCCESS with type filter"
rescue => e
  puts "  ✗ FAILED: #{e.message}"
end
