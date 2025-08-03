# frozen_string_literal: true

require "bigdecimal"

module Tastytrade
  module Models
    # Represents account balance information from the API
    class AccountBalance < Base
      attr_reader :account_number, :cash_balance, :long_equity_value, :short_equity_value,
                  :long_derivative_value, :short_derivative_value, :net_liquidating_value,
                  :equity_buying_power, :derivative_buying_power, :day_trading_buying_power,
                  :available_trading_funds, :margin_equity, :pending_cash,
                  :pending_margin_interest, :effective_trading_funds, :updated_at

      def initialize(data)
        super
        @account_number = data["account-number"]

        # Convert all monetary values to BigDecimal for precision
        @cash_balance = parse_decimal(data["cash-balance"])
        @long_equity_value = parse_decimal(data["long-equity-value"])
        @short_equity_value = parse_decimal(data["short-equity-value"])
        @long_derivative_value = parse_decimal(data["long-derivative-value"])
        @short_derivative_value = parse_decimal(data["short-derivative-value"])
        @net_liquidating_value = parse_decimal(data["net-liquidating-value"])
        @equity_buying_power = parse_decimal(data["equity-buying-power"])
        @derivative_buying_power = parse_decimal(data["derivative-buying-power"])
        @day_trading_buying_power = parse_decimal(data["day-trading-buying-power"])
        @available_trading_funds = parse_decimal(data["available-trading-funds"])
        @margin_equity = parse_decimal(data["margin-equity"])
        @pending_cash = parse_decimal(data["pending-cash"])
        @pending_margin_interest = parse_decimal(data["pending-margin-interest"])
        @effective_trading_funds = parse_decimal(data["effective-trading-funds"])

        @updated_at = parse_time(data["updated-at"])
      end

      # Calculate buying power usage as a percentage
      def buying_power_usage_percentage
        return BigDecimal("0") if equity_buying_power.zero?

        used_buying_power = equity_buying_power - available_trading_funds
        ((used_buying_power / equity_buying_power) * 100).round(2)
      end

      # Check if buying power usage is above warning threshold
      def high_buying_power_usage?(threshold = 80)
        buying_power_usage_percentage > threshold
      end

      # Calculate total equity value (long + short)
      def total_equity_value
        long_equity_value + short_equity_value
      end

      # Calculate total derivative value (long + short)
      def total_derivative_value
        long_derivative_value + short_derivative_value
      end

      # Calculate total market value (equity + derivatives)
      def total_market_value
        total_equity_value + total_derivative_value
      end

      # Calculate derivative buying power usage percentage
      def derivative_buying_power_usage_percentage
        return BigDecimal("0") if derivative_buying_power.zero?

        used_derivative_buying_power = derivative_buying_power - available_trading_funds
        ((used_derivative_buying_power / derivative_buying_power) * 100).round(2)
      end

      # Calculate day trading buying power usage percentage
      def day_trading_buying_power_usage_percentage
        return BigDecimal("0") if day_trading_buying_power.zero?

        used_day_trading_buying_power = day_trading_buying_power - available_trading_funds
        ((used_day_trading_buying_power / day_trading_buying_power) * 100).round(2)
      end

      # Get the minimum buying power across all types
      def minimum_buying_power
        [equity_buying_power, derivative_buying_power, day_trading_buying_power].min
      end

      # Check if account has sufficient buying power for a given amount
      def sufficient_buying_power?(amount, buying_power_type: :equity)
        bp = case buying_power_type
             when :equity then equity_buying_power
             when :derivative then derivative_buying_power
             when :day_trading then day_trading_buying_power
             else equity_buying_power
        end

        bp >= BigDecimal(amount.to_s)
      end

      # Calculate buying power impact as percentage
      def buying_power_impact_percentage(amount, buying_power_type: :equity)
        bp = case buying_power_type
             when :equity then equity_buying_power
             when :derivative then derivative_buying_power
             when :day_trading then day_trading_buying_power
             else equity_buying_power
        end

        return BigDecimal("0") if bp.zero?
        ((BigDecimal(amount.to_s) / bp) * 100).round(2)
      end

      private

      # Parse string value to BigDecimal, handling nil and empty strings
      def parse_decimal(value)
        return BigDecimal("0") if value.nil? || value.to_s.empty?
        BigDecimal(value.to_s)
      end
    end
  end
end
