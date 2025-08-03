# frozen_string_literal: true

require "bigdecimal"

module Tastytrade
  module Models
    # Represents the response from placing an order
    class OrderResponse < Base
      attr_reader :order_id, :buying_power_effect, :fee_calculations,
                  :warnings, :errors, :complex_order_id, :complex_order_tag,
                  :status, :account_number, :time_in_force, :order_type,
                  :price, :price_effect, :value, :value_effect,
                  :stop_trigger, :legs, :cancellable, :editable,
                  :edited, :updated_at, :created_at

      private

      def parse_attributes
        parse_basic_attributes
        parse_financial_attributes
        parse_order_details
        parse_metadata
      end

      def parse_basic_attributes
        @order_id = @data["id"]
        @account_number = @data["account-number"]
        @status = @data["status"]
        @cancellable = @data["cancellable"]
        @editable = @data["editable"]
        @edited = @data["edited"]
      end

      def parse_financial_attributes
        # Handle both simple values and dry-run nested objects
        @buying_power_effect = parse_buying_power_effect(@data["buying-power-effect"])
        @fee_calculations = @data["fee-calculation"] || @data["fee-calculation-details"]
        @price = parse_financial_value(@data["price"])
        @price_effect = @data["price-effect"]
        @value = parse_financial_value(@data["value"])
        @value_effect = @data["value-effect"]
      end

      def parse_order_details
        @time_in_force = @data["time-in-force"]
        @order_type = @data["order-type"]
        @stop_trigger = parse_financial_value(@data["stop-trigger"])
        @complex_order_id = @data["complex-order-id"]
        @complex_order_tag = @data["complex-order-tag"]
        @legs = parse_legs(@data["legs"] || [])
      end

      def parse_metadata
        @warnings = @data["warnings"] || []
        @errors = @data["errors"] || []
        @updated_at = parse_time(@data["updated-at"])
        @created_at = parse_time(@data["created-at"])
      end

      def parse_financial_value(value)
        return nil if value.nil? || value.to_s.empty?
        BigDecimal(value.to_s)
      end

      def parse_legs(legs_data)
        legs_data.map { |leg| OrderLegResponse.new(leg) }
      end

      def parse_buying_power_effect(value)
        return nil if value.nil?

        # Handle dry-run response format with nested object
        if value.is_a?(Hash) && (value["change-in-buying-power"] || value["impact"])
          # Create a full BuyingPowerEffect object for dry-run responses
          BuyingPowerEffect.new(value)
        else
          # Handle regular response format (simple numeric value)
          parse_financial_value(value)
        end
      end
    end

    # Represents a leg in an order response
    class OrderLegResponse < Base
      attr_reader :action, :symbol, :quantity, :instrument_type,
                  :remaining_quantity, :fills, :execution_price

      private

      def parse_attributes
        @action = @data["action"]
        @symbol = @data["symbol"]
        @quantity = @data["quantity"]&.to_i
        @instrument_type = @data["instrument-type"]
        @remaining_quantity = @data["remaining-quantity"]&.to_i
        @fills = @data["fills"] || []
        @execution_price = parse_financial_value(@data["execution-price"])
      end

      def parse_financial_value(value)
        return nil if value.nil? || value.to_s.empty?
        BigDecimal(value.to_s)
      end
    end
  end
end
