# frozen_string_literal: true

require "bigdecimal"
require "time"

module Tastytrade
  module Models
    # Represents a live order (open or recently closed) from the API
    class LiveOrder < Base
      attr_reader :id, :account_number, :status, :cancellable, :editable,
                  :edited, :time_in_force, :order_type, :size, :price,
                  :price_effect, :underlying_symbol, :underlying_instrument_type,
                  :stop_trigger, :legs, :gtc_date, :created_at, :updated_at,
                  :received_at, :routed_at, :filled_at, :cancelled_at,
                  :expired_at, :rejected_at, :live_at, :terminal_at,
                  :contingent_status, :confirmation_status, :reject_reason,
                  :user_tag, :preflight_check_result, :order_rule

      # Check if order can be cancelled
      def cancellable?
        @cancellable && status == "Live"
      end

      # Check if order can be replaced/edited
      def editable?
        @editable && status == "Live"
      end

      # Check if order is in a terminal state
      def terminal?
        %w[Filled Cancelled Rejected Expired].include?(status)
      end

      # Check if order is working (live in market)
      def working?
        status == "Live"
      end

      # Check if order has been filled
      def filled?
        status == "Filled"
      end

      # Check if order has been cancelled
      def cancelled?
        status == "Cancelled"
      end

      # Get remaining quantity across all legs
      def remaining_quantity
        return 0 unless @legs
        @legs.sum { |leg| leg.remaining_quantity || 0 }
      end

      # Get filled quantity across all legs
      def filled_quantity
        return 0 unless @legs
        @legs.sum { |leg| leg.filled_quantity || 0 }
      end

      private

      def parse_attributes
        parse_basic_attributes
        parse_order_details
        parse_timestamps
        parse_status_details
        parse_legs
      end

      def parse_basic_attributes
        @id = @data["id"]
        @account_number = @data["account-number"]
        @status = @data["status"]
        @cancellable = @data["cancellable"]
        @editable = @data["editable"]
        @edited = @data["edited"]
      end

      def parse_order_details
        @time_in_force = @data["time-in-force"]
        @order_type = @data["order-type"]
        @size = @data["size"]&.to_i
        @price = parse_financial_value(@data["price"])
        @price_effect = @data["price-effect"]
        @underlying_symbol = @data["underlying-symbol"]
        @underlying_instrument_type = @data["underlying-instrument-type"]
        @stop_trigger = parse_financial_value(@data["stop-trigger"])
        @gtc_date = parse_date(@data["gtc-date"])
      end

      def parse_timestamps
        @created_at = parse_time(@data["created-at"])
        @updated_at = parse_time(@data["updated-at"])
        @received_at = parse_time(@data["received-at"])
        @routed_at = parse_time(@data["routed-at"])
        @filled_at = parse_time(@data["filled-at"])
        @cancelled_at = parse_time(@data["cancelled-at"])
        @expired_at = parse_time(@data["expired-at"])
        @rejected_at = parse_time(@data["rejected-at"])
        @live_at = parse_time(@data["live-at"])
        @terminal_at = parse_time(@data["terminal-at"])
      end

      def parse_status_details
        @contingent_status = @data["contingent-status"]
        @confirmation_status = @data["confirmation-status"]
        @reject_reason = @data["reject-reason"]
        @user_tag = @data["user-tag"]
        @preflight_check_result = @data["preflight-check-result"]
        @order_rule = @data["order-rule"]
      end

      def parse_legs
        legs_data = @data["legs"] || []
        @legs = legs_data.map { |leg| LiveOrderLeg.new(leg) }
      end

      def parse_financial_value(value)
        return nil if value.nil? || value.to_s.empty?
        BigDecimal(value.to_s)
      end

      def parse_date(value)
        return nil if value.nil? || value.to_s.empty?
        Date.parse(value)
      end
    end

    # Represents a leg in a live order
    class LiveOrderLeg < Base
      attr_reader :symbol, :instrument_type, :action, :quantity,
                  :remaining_quantity, :fills, :fill_quantity, :fill_price,
                  :execution_price, :position_effect, :ratio_quantity

      # Calculate filled quantity
      def filled_quantity
        return 0 if @quantity.nil? || @remaining_quantity.nil?
        @quantity - @remaining_quantity
      end

      # Check if leg is completely filled
      def filled?
        @remaining_quantity.to_i == 0
      end

      # Check if leg is partially filled
      def partially_filled?
        !filled? && filled_quantity > 0
      end

      private

      def parse_attributes
        @symbol = @data["symbol"]
        @instrument_type = @data["instrument-type"]
        @action = @data["action"]
        @quantity = @data["quantity"]&.to_i
        @remaining_quantity = @data["remaining-quantity"]&.to_i
        @fills = parse_fills(@data["fills"] || [])
        @fill_quantity = @data["fill-quantity"]&.to_i
        @fill_price = parse_financial_value(@data["fill-price"])
        @execution_price = parse_financial_value(@data["execution-price"])
        @position_effect = @data["position-effect"]
        @ratio_quantity = @data["ratio-quantity"]&.to_i
      end

      def parse_fills(fills_data)
        fills_data.map { |fill| Fill.new(fill) }
      end

      def parse_financial_value(value)
        return nil if value.nil? || value.to_s.empty?
        BigDecimal(value.to_s)
      end
    end

    # Represents a fill execution
    class Fill < Base
      attr_reader :ext_exec_id, :ext_group_fill_id, :fill_id, :quantity,
                  :fill_price, :filled_at, :destination_venue

      private

      def parse_attributes
        @ext_exec_id = @data["ext-exec-id"]
        @ext_group_fill_id = @data["ext-group-fill-id"]
        @fill_id = @data["fill-id"]
        @quantity = @data["quantity"]&.to_i
        @fill_price = parse_financial_value(@data["fill-price"])
        @filled_at = parse_time(@data["filled-at"])
        @destination_venue = @data["destination-venue"]
      end

      def parse_financial_value(value)
        return nil if value.nil? || value.to_s.empty?
        BigDecimal(value.to_s)
      end
    end
  end
end
