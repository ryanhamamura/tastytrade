# frozen_string_literal: true

require "bigdecimal"

module Tastytrade
  # Order action constants
  module OrderAction
    BUY_TO_OPEN = "Buy to Open"
    SELL_TO_CLOSE = "Sell to Close"
    SELL_TO_OPEN = "Sell to Open"
    BUY_TO_CLOSE = "Buy to Close"
  end

  # Order type constants
  module OrderType
    MARKET = "Market"
    LIMIT = "Limit"
    STOP = "Stop"
  end

  # Order time in force constants
  module OrderTimeInForce
    DAY = "Day"
    GTC = "GTC"
  end

  # Price effect constants
  module PriceEffect
    DEBIT = "Debit"
    CREDIT = "Credit"
  end

  # Represents a single leg of an order
  class OrderLeg
    attr_reader :action, :symbol, :quantity, :instrument_type, :position_effect

    OCC_SYMBOL_PATTERN = /\A[A-Z0-9]+\s\d{6}[CP]\d{8}\z/

    def initialize(action:, symbol:, quantity:, instrument_type: "Equity", position_effect: nil)
      validate_action!(action)
      validate_symbol!(symbol, instrument_type)
      validate_position_effect!(position_effect) if position_effect

      @action = action
      @symbol = symbol
      @quantity = quantity.to_i
      @instrument_type = instrument_type
      @position_effect = position_effect || auto_detect_position_effect(action)
    end

    def to_api_params
      params = {
        "action" => @action,
        "symbol" => @symbol,
        "quantity" => @quantity,
        "instrument-type" => @instrument_type
      }

      params["position-effect"] = @position_effect if @position_effect && @instrument_type == "Option"

      params
    end

    private

    def validate_action!(action)
      valid_actions = [
        OrderAction::BUY_TO_OPEN,
        OrderAction::SELL_TO_CLOSE,
        OrderAction::SELL_TO_OPEN,
        OrderAction::BUY_TO_CLOSE
      ]

      unless valid_actions.include?(action)
        raise ArgumentError, "Invalid action: #{action}. Must be one of: #{valid_actions.join(", ")}"
      end
    end

    def validate_symbol!(symbol, instrument_type)
      return unless instrument_type == "Option"

      unless symbol.match?(OCC_SYMBOL_PATTERN)
        raise ArgumentError, "Invalid OCC option symbol format: #{symbol}. Expected format: 'AAPL 240119C00150000'"
      end
    end

    def validate_position_effect!(position_effect)
      valid_effects = ["Opening", "Closing", "Auto"]
      unless valid_effects.include?(position_effect)
        raise ArgumentError, "Invalid position effect: #{position_effect}. Must be one of: #{valid_effects.join(", ")}"
      end
    end

    def auto_detect_position_effect(action)
      case action
      when OrderAction::BUY_TO_OPEN, OrderAction::SELL_TO_OPEN
        "Opening"
      when OrderAction::BUY_TO_CLOSE, OrderAction::SELL_TO_CLOSE
        "Closing"
      else
        "Auto"
      end
    end
  end

  # Represents an order to be placed
  class Order
    attr_reader :type, :time_in_force, :legs, :price

    def initialize(type:, time_in_force: OrderTimeInForce::DAY, legs:, price: nil)
      validate_type!(type)
      validate_time_in_force!(time_in_force)
      validate_price!(type, price)

      @type = type
      @time_in_force = time_in_force
      @legs = Array(legs)
      @price = price ? BigDecimal(price.to_s) : nil
    end

    def market?
      @type == OrderType::MARKET
    end

    def limit?
      @type == OrderType::LIMIT
    end

    def stop?
      @type == OrderType::STOP
    end

    # Validates this order for a specific account using the OrderValidator.
    # Performs comprehensive checks including symbol existence, quantity constraints,
    # price validation, account permissions, and optionally buying power.
    #
    # @param session [Tastytrade::Session] Active session
    # @param account [Tastytrade::Models::Account] Account to validate against
    # @param skip_dry_run [Boolean] Skip dry-run validation for performance
    # @return [Boolean] true if valid
    # @raise [OrderValidationError] if validation fails with detailed error messages
    #
    # @example
    #   order.validate!(session, account)  # Full validation including dry-run
    #   order.validate!(session, account, skip_dry_run: true)  # Skip buying power check
    def validate!(session, account, skip_dry_run: false)
      validator = OrderValidator.new(session, account, self)
      validator.validate!(skip_dry_run: skip_dry_run)
    end

    # Performs a dry-run validation of the order. This submits the order to the API
    # in dry-run mode to check buying power, margin requirements, and get warnings
    # without actually placing the order.
    #
    # @param session [Tastytrade::Session] Active session
    # @param account [Tastytrade::Models::Account] Account to validate against
    # @return [Tastytrade::Models::OrderResponse] Dry-run response with buying power effect
    #
    # @example
    #   response = order.dry_run(session, account)
    #   puts response.buying_power_effect
    #   puts response.warnings
    def dry_run(session, account)
      account.place_order(session, self, dry_run: true)
    end

    def to_api_params
      params = {
        "order-type" => @type,
        "time-in-force" => @time_in_force,
        "legs" => @legs.map(&:to_api_params)
      }

      # Add price for limit orders
      # API expects string representation without negative sign
      if limit? && @price
        params["price"] = @price.to_s("F")
        params["price-effect"] = determine_price_effect
      end

      params
    end

    private

    def determine_price_effect
      # Determine price effect based on the first leg's action
      # Buy actions result in debit, sell actions result in credit
      first_leg = @legs.first
      return PriceEffect::DEBIT unless first_leg

      case first_leg.action
      when OrderAction::BUY_TO_OPEN, OrderAction::BUY_TO_CLOSE
        PriceEffect::DEBIT
      when OrderAction::SELL_TO_OPEN, OrderAction::SELL_TO_CLOSE
        PriceEffect::CREDIT
      else
        PriceEffect::DEBIT # Default to debit
      end
    end

    def validate_type!(type)
      valid_types = [OrderType::MARKET, OrderType::LIMIT, OrderType::STOP]
      unless valid_types.include?(type)
        raise ArgumentError, "Invalid order type: #{type}. Must be one of: #{valid_types.join(", ")}"
      end
    end

    def validate_time_in_force!(time_in_force)
      valid_tifs = [OrderTimeInForce::DAY, OrderTimeInForce::GTC]
      unless valid_tifs.include?(time_in_force)
        raise ArgumentError, "Invalid time in force: #{time_in_force}. Must be one of: #{valid_tifs.join(", ")}"
      end
    end

    def validate_price!(type, price)
      if type == OrderType::LIMIT && price.nil?
        raise ArgumentError, "Price is required for limit orders"
      end

      if price && price.to_f <= 0
        raise ArgumentError, "Price must be greater than 0"
      end
    end
  end
end
