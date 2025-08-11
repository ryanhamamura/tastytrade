# frozen_string_literal: true

require_relative "order"
require_relative "models/option"
require "bigdecimal"

module Tastytrade
  # Builder class for creating option orders with validation and automatic leg construction
  #
  # Provides methods for building single-leg and multi-leg option orders with proper
  # action sequencing, premium calculations, and validation. Handles complex strategies
  # like spreads, strangles, straddles, and iron condors.
  #
  # @example Basic usage
  #   builder = OptionOrderBuilder.new(session, account)
  #   order = builder.buy_call(option, 1, price: 2.50)
  #
  # @example Multi-leg strategy
  #   spread = builder.vertical_spread(long_option, short_option, 1)
  #   straddle = builder.straddle(put_option, call_option, 1)
  class OptionOrderBuilder
    # Raised when an invalid strategy is requested
    class InvalidStrategyError < StandardError; end

    # Raised when an invalid option is provided
    class InvalidOptionError < StandardError; end

    POSITION_EFFECTS = {
      opening: "Opening",
      closing: "Closing",
      auto: "Auto"
    }.freeze

    attr_reader :session, :account

    def initialize(session, account)
      @session = session
      @account = account
    end

    def buy_call(option, quantity, price: nil, time_in_force: OrderTimeInForce::DAY, position_effect: :auto)
      validate_option!(option)
      create_single_leg_order(
        option: option,
        quantity: quantity,
        action: OrderAction::BUY_TO_OPEN,
        price: price,
        time_in_force: time_in_force,
        position_effect: position_effect
      )
    end

    def sell_call(option, quantity, price: nil, time_in_force: OrderTimeInForce::DAY, position_effect: :auto)
      validate_option!(option)
      create_single_leg_order(
        option: option,
        quantity: quantity,
        action: OrderAction::SELL_TO_OPEN,
        price: price,
        time_in_force: time_in_force,
        position_effect: position_effect
      )
    end

    def buy_put(option, quantity, price: nil, time_in_force: OrderTimeInForce::DAY, position_effect: :auto)
      validate_option!(option)
      create_single_leg_order(
        option: option,
        quantity: quantity,
        action: OrderAction::BUY_TO_OPEN,
        price: price,
        time_in_force: time_in_force,
        position_effect: position_effect
      )
    end

    def sell_put(option, quantity, price: nil, time_in_force: OrderTimeInForce::DAY, position_effect: :auto)
      validate_option!(option)
      create_single_leg_order(
        option: option,
        quantity: quantity,
        action: OrderAction::SELL_TO_OPEN,
        price: price,
        time_in_force: time_in_force,
        position_effect: position_effect
      )
    end

    def close_position(option, quantity, price: nil, time_in_force: OrderTimeInForce::DAY)
      validate_option!(option)

      action = determine_closing_action(option, quantity)

      create_single_leg_order(
        option: option,
        quantity: quantity.abs,
        action: action,
        price: price,
        time_in_force: time_in_force,
        position_effect: :closing
      )
    end

    def vertical_spread(
      long_option,
      short_option,
      quantity,
      price: nil,
      time_in_force: OrderTimeInForce::DAY
    )
      validate_vertical_spread!(long_option, short_option)

      legs = [
        build_option_leg(long_option, quantity, OrderAction::BUY_TO_OPEN),
        build_option_leg(short_option, quantity, OrderAction::SELL_TO_OPEN)
      ]

      order_type = price ? OrderType::LIMIT : OrderType::MARKET

      Order.new(
        type: order_type,
        time_in_force: time_in_force,
        legs: legs,
        price: price
      )
    end

    def iron_condor(
      put_short,
      put_long,
      call_short,
      call_long,
      quantity,
      price: nil,
      time_in_force: OrderTimeInForce::DAY
    )
      validate_iron_condor!(put_short, put_long, call_short, call_long)

      legs = [
        build_option_leg(put_short, quantity, OrderAction::SELL_TO_OPEN),
        build_option_leg(put_long, quantity, OrderAction::BUY_TO_OPEN),
        build_option_leg(call_short, quantity, OrderAction::SELL_TO_OPEN),
        build_option_leg(call_long, quantity, OrderAction::BUY_TO_OPEN)
      ]

      order_type = price ? OrderType::LIMIT : OrderType::MARKET

      Order.new(
        type: order_type,
        time_in_force: time_in_force,
        legs: legs,
        price: price
      )
    end

    def strangle(
      put_option,
      call_option,
      quantity,
      action: OrderAction::BUY_TO_OPEN,
      price: nil,
      time_in_force: OrderTimeInForce::DAY
    )
      validate_strangle!(put_option, call_option)

      legs = [
        build_option_leg(put_option, quantity, action),
        build_option_leg(call_option, quantity, action)
      ]

      order_type = price ? OrderType::LIMIT : OrderType::MARKET

      Order.new(
        type: order_type,
        time_in_force: time_in_force,
        legs: legs,
        price: price
      )
    end

    def straddle(
      put_option,
      call_option,
      quantity,
      action: OrderAction::BUY_TO_OPEN,
      price: nil,
      time_in_force: OrderTimeInForce::DAY
    )
      validate_option!(put_option)
      validate_option!(call_option)

      # Ensure both options have same strike and expiration
      if put_option.strike_price != call_option.strike_price
        raise InvalidStrategyError, "Put and call must have same strike price for straddle"
      end

      if put_option.expiration_date != call_option.expiration_date
        raise InvalidStrategyError, "Put and call must have same expiration for straddle"
      end

      legs = [
        build_option_leg(put_option, quantity, action),
        build_option_leg(call_option, quantity, action)
      ]

      order_type = price ? OrderType::LIMIT : OrderType::MARKET

      Order.new(
        type: order_type,
        time_in_force: time_in_force,
        legs: legs,
        price: price
      )
    end

    def calculate_net_premium(order)
      return BigDecimal("0") unless order.legs

      total = BigDecimal("0")

      order.legs.each do |leg|
        option = Models::Option.get(session, leg.symbol)

        multiplier = case leg.action
                     when OrderAction::BUY_TO_OPEN, OrderAction::BUY_TO_CLOSE
                       BigDecimal("-1")
                     when OrderAction::SELL_TO_OPEN, OrderAction::SELL_TO_CLOSE
                       BigDecimal("1")
                     else
                       BigDecimal("0")
        end

        mid_price = (option.ask + option.bid) / 2
        total += mid_price * leg.quantity * multiplier * 100
      end

      total
    end

    private

    def validate_option!(option)
      raise InvalidOptionError, "Option cannot be nil" if option.nil?
      # Allow test doubles, real Option objects, or objects with option-like attributes
      unless option.is_a?(Models::Option) ||
             option.respond_to?(:symbol) ||
             option.respond_to?(:strike_price) ||
             option.respond_to?(:expired?)
        raise InvalidOptionError, "Invalid option type: #{option.class}"
      end
      raise InvalidOptionError, "Option is expired" if option.respond_to?(:expired?) && option.expired?
    end

    def validate_vertical_spread!(long_option, short_option)
      validate_option!(long_option)
      validate_option!(short_option)

      unless long_option.option_type == short_option.option_type
        raise InvalidStrategyError, "Options must be same type (both calls or both puts)"
      end

      unless long_option.expiration_date == short_option.expiration_date
        raise InvalidStrategyError, "Options must have same expiration date"
      end

      unless long_option.underlying_symbol == short_option.underlying_symbol
        raise InvalidStrategyError, "Options must have same underlying symbol"
      end
    end

    def validate_iron_condor!(put_short, put_long, call_short, call_long)
      [put_short, put_long, call_short, call_long].each { |opt| validate_option!(opt) }

      unless put_short.option_type == "P" && put_long.option_type == "P"
        raise InvalidStrategyError, "Put options must be puts"
      end

      unless call_short.option_type == "C" && call_long.option_type == "C"
        raise InvalidStrategyError, "Call options must be calls"
      end

      unless [put_short, put_long, call_short, call_long].map(&:expiration_date).uniq.size == 1
        raise InvalidStrategyError, "All options must have same expiration date"
      end

      unless [put_short, put_long, call_short, call_long].map(&:underlying_symbol).uniq.size == 1
        raise InvalidStrategyError, "All options must have same underlying symbol"
      end

      unless put_long.strike_price < put_short.strike_price
        raise InvalidStrategyError, "Long put strike must be lower than short put strike"
      end

      unless call_long.strike_price > call_short.strike_price
        raise InvalidStrategyError, "Long call strike must be higher than short call strike"
      end
    end

    def validate_strangle!(put_option, call_option)
      validate_option!(put_option)
      validate_option!(call_option)

      unless put_option.option_type == "P" && call_option.option_type == "C"
        raise InvalidStrategyError, "Strangle requires a put and a call"
      end

      unless put_option.expiration_date == call_option.expiration_date
        raise InvalidStrategyError, "Options must have same expiration date"
      end

      unless put_option.underlying_symbol == call_option.underlying_symbol
        raise InvalidStrategyError, "Options must have same underlying symbol"
      end

      if put_option.strike_price == call_option.strike_price
        raise InvalidStrategyError, "Strangle requires different strike prices (use straddle for same strikes)"
      end
    end

    def create_single_leg_order(option:, quantity:, action:, price:, time_in_force:, position_effect:)
      leg = build_option_leg(option, quantity, action, position_effect)
      order_type = price ? OrderType::LIMIT : OrderType::MARKET

      Order.new(
        type: order_type,
        time_in_force: time_in_force,
        legs: [leg],
        price: price
      )
    end

    def build_option_leg(option, quantity, action, position_effect = :auto)
      # Clean up the symbol - remove extra spaces
      symbol = option.symbol.gsub(/\s+/, " ").strip if option.symbol

      OrderLeg.new(
        action: action,
        symbol: symbol,
        quantity: quantity,
        instrument_type: "Option",
        position_effect: POSITION_EFFECTS[position_effect]
      )
    end

    def determine_closing_action(option, quantity)
      if quantity > 0
        option.option_type == "C" ? OrderAction::SELL_TO_CLOSE : OrderAction::SELL_TO_CLOSE
      else
        option.option_type == "C" ? OrderAction::BUY_TO_CLOSE : OrderAction::BUY_TO_CLOSE
      end
    end

    def build_option_symbol(underlying, expiration, option_type)
      exp_str = expiration.strftime("%y%m%d")
      strike_str = format("%08d", (underlying[:strike] * 1000).to_i)
      "#{underlying[:symbol]} #{exp_str}#{option_type}#{strike_str}"
    end
  end
end
