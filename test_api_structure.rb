#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "tastytrade"
require "json"
require "pp"

# Detailed test to understand API response structure
session = Tastytrade::Session.new(
  username: ENV["TASTYTRADE_SANDBOX_USERNAME"],
  password: ENV["TASTYTRADE_SANDBOX_PASSWORD"],
  is_test: true
)

session.login
puts "Logged in as #{session.user.email}\n\n"

# Test compact option chain
puts "=" * 60
puts "COMPACT OPTION CHAIN API STRUCTURE"
puts "=" * 60
response = session.get("/option-chains/SPY/compact")

puts "\nTop level keys:"
pp response.keys

puts "\nData structure:"
if response["data"]
  puts "data.class: #{response["data"].class}"
  puts "data.keys: #{response["data"].keys}"

  if response["data"]["items"]
    items = response["data"]["items"]
    puts "\ndata.items.class: #{items.class}"
    puts "data.items.size: #{items.size}"

    if items.first
      puts "\nFirst item structure:"
      pp items.first

      if items.first["symbols"]
        puts "\nSymbols array (first 5):"
        pp items.first["symbols"].first(5)
      end
    end
  end
end

# Test nested option chain
puts "\n" + "=" * 60
puts "NESTED OPTION CHAIN API STRUCTURE"
puts "=" * 60
response = session.get("/option-chains/SPY/nested")

puts "\nTop level keys:"
pp response.keys

puts "\nData structure:"
if response["data"]
  puts "data.class: #{response["data"].class}"
  puts "data.keys: #{response["data"].keys}"

  if response["data"]["items"]
    items = response["data"]["items"]
    puts "\ndata.items.class: #{items.class}"
    puts "data.items.size: #{items.size}"

    if items.first
      puts "\nFirst item structure:"
      pp items.first

      if items.first["expirations"]
        puts "\nFirst expiration:"
        exp = items.first["expirations"].first
        pp exp if exp

        if exp && exp["strikes"]
          puts "\nFirst strike:"
          pp exp["strikes"].first
        end
      end
    end
  end
end
