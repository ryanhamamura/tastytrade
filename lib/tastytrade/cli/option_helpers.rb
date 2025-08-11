# frozen_string_literal: true

module Tastytrade
  # Helper methods for option chain display and formatting
  #
  # This module provides utility methods for formatting option-related data,
  # including moneyness calculations, spread analysis, and display formatting.
  # These helpers are used by the OptionChainFormatter and CLI option commands.
  #
  # @example Including in a class
  #   class MyFormatter
  #     include Tastytrade::OptionHelpers
  #
  #     def display_option(option)
  #       puts option_moneyness(option.strike, 450.0, "Call")
  #       puts format_option_volume(option.volume)
  #     end
  #   end
  #
  # @example Calculating bid-ask spread
  #   spread = bid_ask_spread(5.50, 5.55)  # => 0.05
  #   spread_pct = bid_ask_spread_percentage(5.50, 5.55)  # => 0.91
  module OptionHelpers
      # Format a number as currency with proper decimal places
      #
      # @param amount [BigDecimal, Float, nil] Amount to format
      # @param decimals [Integer] Number of decimal places
      # @return [String] Formatted currency string
    def format_option_currency(amount, decimals: 2)
      return "-" if amount.nil? || amount == 0
      "$#{"%.#{decimals}f" % amount.to_f}"
    end

      # Determine option moneyness classification
      #
      # @param strike_price [BigDecimal, Float] Strike price
      # @param current_price [BigDecimal, Float] Current underlying price
      # @param option_type [String] "Call" or "Put"
      # @return [String] "ITM", "ATM", or "OTM"
    def option_moneyness(strike_price, current_price, option_type)
      return "Unknown" unless current_price && strike_price

      diff_pct = ((strike_price - current_price) / current_price * 100).abs

      # Consider ATM if within 1% of current price
      return "ATM" if diff_pct <= 1.0

      if option_type.upcase == "CALL"
        strike_price < current_price ? "ITM" : "OTM"
      else # PUT
        strike_price > current_price ? "ITM" : "OTM"
      end
    end

      # Find the at-the-money strike from a list of strikes
      #
      # @param strikes [Array<BigDecimal, Float>] List of strike prices
      # @param current_price [BigDecimal, Float] Current underlying price
      # @return [BigDecimal, Float] ATM strike price
    def find_atm_strike(strikes, current_price)
      return strikes[strikes.size / 2] unless current_price
      strikes.min_by { |strike| (strike - current_price).abs }
    end

      # Format volume with K/M suffixes for large numbers
      #
      # @param volume [Integer, nil] Volume to format
      # @return [String] Formatted volume string
    def format_option_volume(volume)
      return "-" unless volume && volume > 0

      case volume
      when 0...1000
        volume.to_s
      when 1000...1_000_000
        "#{(volume / 1000.0).round(1)}K"
      else
        "#{(volume / 1_000_000.0).round(1)}M"
      end
    end

      # Calculate bid-ask spread
      #
      # @param bid [BigDecimal, Float] Bid price
      # @param ask [BigDecimal, Float] Ask price
      # @return [Float, nil] Spread amount or nil if invalid
    def bid_ask_spread(bid, ask)
      return nil unless bid && ask && bid > 0 && ask > 0
      (ask - bid).to_f
    end

      # Calculate bid-ask spread percentage
      #
      # @param bid [BigDecimal, Float] Bid price
      # @param ask [BigDecimal, Float] Ask price
      # @return [Float, nil] Spread percentage or nil if invalid
    def bid_ask_spread_percentage(bid, ask)
      spread = bid_ask_spread(bid, ask)
      return nil unless spread

      mid = (bid + ask) / 2.0
      (spread / mid * 100).round(2)
    end

      # Format Greeks value with appropriate precision
      #
      # @param value [Float, nil] Greek value
      # @param precision [Integer] Decimal places
      # @return [String] Formatted Greek value
    def format_greek_value(value, precision: 4)
      return "-" unless value
      format("%.#{precision}f", value)
    end

      # Format Greek values with type-specific precision
      #
      # @param value [Float, nil] Greek value to format
      # @param greek_type [Symbol] Type of Greek (:delta, :gamma, :theta, :vega, :rho)
      # @return [String] Formatted Greek string
    def format_greek(value, greek_type)
      return "-" unless value

      case greek_type
      when :delta
        format("%.3f", value)
      when :gamma, :theta, :vega, :rho
        format("%.4f", value)
      else
        format("%.4f", value)
      end
    end

      # Format currency values
      #
      # @param amount [Float, BigDecimal, nil] Amount to format
      # @return [String] Formatted currency string
    def format_currency(amount)
      return "-" unless amount
      "$#{"%.2f" % amount.to_f}"
    end

      # Format volume numbers with K/M suffixes
      #
      # @param volume [Integer, nil] Volume to format
      # @return [String] Formatted volume string
    def format_volume(volume)
      return "-" unless volume && volume > 0

      if volume >= 1_000_000
        "#{"%.1f" % (volume / 1_000_000.0)}M"
      elsif volume >= 1_000
        "#{"%.1f" % (volume / 1_000.0)}K"
      else
        volume.to_s
      end
    end

      # Format implied volatility as percentage
      #
      # @param iv [Float, nil] Implied volatility (as decimal)
      # @return [String] Formatted IV percentage
    def format_iv_percentage(iv)
      return "-" unless iv
      "#{"%.1f" % (iv * 100)}%"
    end

      # Format implied volatility as percentage (alias)
      #
      # @param iv [Float, nil] Implied volatility (as decimal)
      # @return [String] Formatted IV percentage
    def format_implied_volatility(iv)
      return "-" unless iv
      "#{(iv * 100).round(1)}%"
    end

      # Calculate days to expiration
      #
      # @param expiration_date [Date, String] Expiration date
      # @return [Integer] Days to expiration
    def calculate_dte(expiration_date)
      exp_date = expiration_date.is_a?(Date) ? expiration_date : Date.parse(expiration_date.to_s)
      (exp_date - Date.today).to_i
    end

      # Determine if market is open
      #
      # @param time [Time] Time to check (default: current time)
      # @return [Boolean] True if market is open
    def market_open?(time = Time.now)
      # US Market hours: 9:30 AM - 4:00 PM EST
      return false if time.saturday? || time.sunday?

      # Convert to EST
      est_time = time.getlocal("-05:00")
      hour = est_time.hour
      min = est_time.min

      # Market hours: 9:30 AM - 4:00 PM
      return false if hour < 9 || hour >= 16
      return false if hour == 9 && min < 30

      true
    end

      # Format option symbol for display
      #
      # @param symbol [String] Option symbol (OCC or custom format)
      # @return [String] Formatted symbol for display
    def format_option_symbol(symbol)
      return "-" unless symbol

      # If it's an OCC symbol, try to shorten it
      if symbol.match?(/^.+\d{6}[CP]\d{8}$/)
        # Extract components for shorter display
        match = symbol.match(/^(.+?)(\d{6})([CP])(\d{8})$/)
        if match
          root = match[1]
          date = match[2]
          type = match[3]
          strike = (match[4].to_i / 1000.0)
          strike_str = strike == strike.to_i ? strike.to_i.to_s : strike.to_s
          return "#{root} #{date}#{type}#{strike_str}"
        end
      end

      symbol
    end
  end
end
