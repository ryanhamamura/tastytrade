# frozen_string_literal: true

require "bigdecimal"

module Tastytrade
  module Models
    # Represents the buying power effect from a dry-run order or order placement
    class BuyingPowerEffect < Base
      attr_reader :change_in_margin_requirement, :change_in_buying_power,
                  :current_buying_power, :new_buying_power,
                  :isolated_order_margin_requirement, :is_spread,
                  :impact, :effect

      # Calculate the buying power usage percentage for this order
      def buying_power_usage_percentage
        return BigDecimal("0") if current_buying_power.nil? || current_buying_power.zero?

        impact_amount = impact || change_in_buying_power&.abs || BigDecimal("0")
        ((impact_amount / current_buying_power) * 100).round(2)
      end

      # Check if this order would use more than the specified percentage of buying power
      def exceeds_threshold?(threshold_percentage)
        buying_power_usage_percentage > BigDecimal(threshold_percentage.to_s)
      end

      # Get the absolute value of the buying power change
      def buying_power_change_amount
        change_in_buying_power&.abs || impact&.abs || BigDecimal("0")
      end

      # Check if this is a debit (reduces buying power)
      def debit?
        effect == "Debit" || (change_in_buying_power && change_in_buying_power < 0)
      end

      # Check if this is a credit (increases buying power)
      def credit?
        effect == "Credit" || (change_in_buying_power && change_in_buying_power > 0)
      end

      private

      def parse_attributes
        @change_in_margin_requirement = parse_decimal(@data["change-in-margin-requirement"])
        @change_in_buying_power = parse_decimal(@data["change-in-buying-power"])
        @current_buying_power = parse_decimal(@data["current-buying-power"])
        @new_buying_power = parse_decimal(@data["new-buying-power"])
        @isolated_order_margin_requirement = parse_decimal(@data["isolated-order-margin-requirement"])
        @is_spread = @data["is-spread"]
        @impact = parse_decimal(@data["impact"])
        @effect = @data["effect"]
      end

      def parse_decimal(value)
        return nil if value.nil? || value.to_s.empty?
        BigDecimal(value.to_s)
      end
    end
  end
end
