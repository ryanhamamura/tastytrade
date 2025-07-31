# frozen_string_literal: true

require "bigdecimal"

module Tastytrade
  module Models
    # Represents a current position in an account
    class CurrentPosition < Base
      attr_reader :account_number, :symbol, :instrument_type, :underlying_symbol,
                  :quantity, :quantity_direction, :close_price, :average_open_price,
                  :average_yearly_market_close_price, :average_daily_market_close_price,
                  :multiplier, :cost_effect, :is_suppressed, :is_frozen,
                  :realized_day_gain, :realized_today, :created_at, :updated_at,
                  :mark, :mark_price, :restricted_quantity, :expires_at,
                  :root_symbol, :option_expiration_type, :strike_price,
                  :option_type, :contract_size, :exercise_style

      def initialize(data)
        super
        @account_number = data["account-number"]
        @symbol = data["symbol"]
        @instrument_type = data["instrument-type"]
        @underlying_symbol = data["underlying-symbol"]

        # Quantity information
        @quantity = parse_decimal(data["quantity"])
        @quantity_direction = data["quantity-direction"]
        @restricted_quantity = parse_decimal(data["restricted-quantity"])

        # Price information
        @close_price = parse_decimal(data["close-price"])
        @average_open_price = parse_decimal(data["average-open-price"])
        @average_yearly_market_close_price = parse_decimal(data["average-yearly-market-close-price"])
        @average_daily_market_close_price = parse_decimal(data["average-daily-market-close-price"])
        @mark = parse_decimal(data["mark"])
        @mark_price = parse_decimal(data["mark-price"])

        # Position details
        @multiplier = data["multiplier"]&.to_i || 1
        @cost_effect = data["cost-effect"]
        @is_suppressed = data["is-suppressed"] || false
        @is_frozen = data["is-frozen"] || false

        # Realized gains
        @realized_day_gain = parse_decimal(data["realized-day-gain"])
        @realized_today = parse_decimal(data["realized-today"])

        # Timestamps
        @created_at = parse_time(data["created-at"])
        @updated_at = parse_time(data["updated-at"])
        @expires_at = parse_time(data["expires-at"])

        # Option-specific fields
        @root_symbol = data["root-symbol"]
        @option_expiration_type = data["option-expiration-type"]
        @strike_price = parse_decimal(data["strike-price"])
        @option_type = data["option-type"]
        @contract_size = data["contract-size"]&.to_i
        @exercise_style = data["exercise-style"]
      end

      # Check if this is a long position
      def long?
        quantity_direction == "Long"
      end

      # Check if this is a short position
      def short?
        quantity_direction == "Short"
      end

      # Check if position is closed (zero quantity)
      def closed?
        quantity_direction == "Zero" || quantity.zero?
      end

      # Check if this is an equity position
      def equity?
        instrument_type == "Equity"
      end

      # Check if this is an option position
      def option?
        instrument_type == "Equity Option"
      end

      # Check if this is a futures position
      def futures?
        instrument_type == "Future"
      end

      # Check if this is a futures option position
      def futures_option?
        instrument_type == "Future Option"
      end

      # Calculate position value (quantity * price * multiplier)
      def position_value
        return BigDecimal("0") if closed?
        price = mark_price.zero? ? close_price : mark_price
        quantity.abs * price * multiplier
      end

      # Calculate unrealized P&L
      def unrealized_pnl
        return BigDecimal("0") if closed? || average_open_price.zero?

        current_price = mark_price.zero? ? close_price : mark_price
        if long?
          (current_price - average_open_price) * quantity * multiplier
        else
          (average_open_price - current_price) * quantity.abs * multiplier
        end
      end

      # Calculate unrealized P&L percentage
      def unrealized_pnl_percentage
        return BigDecimal("0") if closed? || average_open_price.zero?

        cost_basis = average_open_price * quantity.abs * multiplier
        return BigDecimal("0") if cost_basis.zero?

        (unrealized_pnl / cost_basis * 100).round(2)
      end

      # Calculate total P&L (realized + unrealized)
      def total_pnl
        realized_today + unrealized_pnl
      end

      # Get display symbol (simplified for options)
      def display_symbol
        if option?
          # Format: ROOT MM/DD/YY C/P STRIKE
          return symbol unless expires_at && strike_price && option_type

          exp_date = expires_at.strftime("%m/%d/%y")
          type_char = option_type == "Call" ? "C" : "P"
          strike_str = strike_price.to_s("F")
          "#{root_symbol} #{exp_date} #{type_char} #{strike_str}"
        else
          symbol
        end
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
