# frozen_string_literal: true

require_relative "order"
require_relative "models/option"
require "bigdecimal"

module Tastytrade
  # Builder class for creating option orders with validation and automatic leg construction
  #
  # Provides methods for building single-leg and multi-leg option orders with proper
  # action sequencing, premium calculations, and validation. Handles complex strategies
  # like spreads, strangles, straddles, iron condors, iron butterflies, butterfly spreads,
  # calendar spreads, and diagonal spreads.
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

    # Creates a buy call order
    #
    # @param option [Models::Option] The call option to buy
    # @param quantity [Integer] Number of contracts to buy
    # @param price [BigDecimal, nil] Limit price (nil for market order)
    # @param time_in_force [OrderTimeInForce] Order time in force (default: DAY)
    # @param position_effect [Symbol] Position effect (:opening, :closing, :auto)
    # @return [Order] The constructed buy call order
    # @raise [InvalidOptionError] if option is invalid or expired
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

    # Creates a sell call order
    #
    # @param option [Models::Option] The call option to sell
    # @param quantity [Integer] Number of contracts to sell
    # @param price [BigDecimal, nil] Limit price (nil for market order)
    # @param time_in_force [OrderTimeInForce] Order time in force (default: DAY)
    # @param position_effect [Symbol] Position effect (:opening, :closing, :auto)
    # @return [Order] The constructed sell call order
    # @raise [InvalidOptionError] if option is invalid or expired
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

    # Creates a buy put order
    #
    # @param option [Models::Option] The put option to buy
    # @param quantity [Integer] Number of contracts to buy
    # @param price [BigDecimal, nil] Limit price (nil for market order)
    # @param time_in_force [OrderTimeInForce] Order time in force (default: DAY)
    # @param position_effect [Symbol] Position effect (:opening, :closing, :auto)
    # @return [Order] The constructed buy put order
    # @raise [InvalidOptionError] if option is invalid or expired
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

    # Creates a sell put order
    #
    # @param option [Models::Option] The put option to sell
    # @param quantity [Integer] Number of contracts to sell
    # @param price [BigDecimal, nil] Limit price (nil for market order)
    # @param time_in_force [OrderTimeInForce] Order time in force (default: DAY)
    # @param position_effect [Symbol] Position effect (:opening, :closing, :auto)
    # @return [Order] The constructed sell put order
    # @raise [InvalidOptionError] if option is invalid or expired
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

    # Creates an order to close an existing option position
    #
    # @param option [Models::Option] The option position to close
    # @param quantity [Integer] Number of contracts to close (positive or negative)
    # @param price [BigDecimal, nil] Limit price (nil for market order)
    # @param time_in_force [OrderTimeInForce] Order time in force (default: DAY)
    # @return [Order] The constructed closing order
    # @raise [InvalidOptionError] if option is invalid or expired
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

    # Creates a vertical spread order (bull or bear spread)
    #
    # @param long_option [Models::Option] The long option leg
    # @param short_option [Models::Option] The short option leg
    # @param quantity [Integer] Number of spreads to create
    # @param price [BigDecimal, nil] Net debit/credit limit price (nil for market)
    # @param time_in_force [OrderTimeInForce] Order time in force (default: DAY)
    # @return [Order] The constructed vertical spread order
    # @raise [InvalidStrategyError] if options don't meet spread requirements
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

    # Creates an iron condor order (4-leg neutral strategy)
    #
    # @param put_short [Models::Option] Short put at lower strike
    # @param put_long [Models::Option] Long put at even lower strike
    # @param call_short [Models::Option] Short call at higher strike
    # @param call_long [Models::Option] Long call at even higher strike
    # @param quantity [Integer] Number of iron condors to create
    # @param price [BigDecimal, nil] Net credit limit price (nil for market)
    # @param time_in_force [OrderTimeInForce] Order time in force (default: DAY)
    # @return [Order] The constructed iron condor order
    # @raise [InvalidStrategyError] if options don't meet iron condor requirements
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

    # Creates an iron butterfly order (4-leg neutral strategy)
    #
    # An iron butterfly consists of:
    # - Short ATM call and put (short straddle at center strike)
    # - Long OTM call (higher strike)
    # - Long OTM put (lower strike)
    #
    # This is a neutral strategy that profits from low volatility and time decay.
    # Maximum profit occurs when the underlying expires at the center strike.
    #
    # @param short_call [Models::Option] Short call option at center strike
    # @param long_call [Models::Option] Long call option at higher strike (wing)
    # @param short_put [Models::Option] Short put option at center strike
    # @param long_put [Models::Option] Long put option at lower strike (wing)
    # @param quantity [Integer] Number of iron butterflies to create
    # @param price [BigDecimal, nil] Net credit limit price (nil for market order)
    # @param time_in_force [OrderTimeInForce] Order time in force (default: DAY)
    #
    # @return [Order] The constructed iron butterfly order
    #
    # @raise [InvalidStrategyError] if options don't meet iron butterfly requirements:
    #   - Short call and put must have same strike (center)
    #   - Wing widths must be equal
    #   - All options must have same expiration
    #   - All options must have same underlying
    #
    # @example Create an iron butterfly with 10-point wings
    #   short_call = option_at_strike(620, :call)
    #   long_call = option_at_strike(630, :call)
    #   short_put = option_at_strike(620, :put)
    #   long_put = option_at_strike(610, :put)
    #   order = builder.iron_butterfly(short_call, long_call, short_put, long_put, 1, price: 3.00)
    def iron_butterfly(
      short_call,
      long_call,
      short_put,
      long_put,
      quantity,
      price: nil,
      time_in_force: OrderTimeInForce::DAY
    )
      validate_iron_butterfly!(short_call, long_call, short_put, long_put)

      legs = [
        build_option_leg(short_call, quantity, OrderAction::SELL_TO_OPEN),
        build_option_leg(long_call, quantity, OrderAction::BUY_TO_OPEN),
        build_option_leg(short_put, quantity, OrderAction::SELL_TO_OPEN),
        build_option_leg(long_put, quantity, OrderAction::BUY_TO_OPEN)
      ]

      order_type = price ? OrderType::LIMIT : OrderType::MARKET

      Order.new(
        type: order_type,
        time_in_force: time_in_force,
        legs: legs,
        price: price
      )
    end

    # Creates a butterfly spread order (3-leg strategy with 1-2-1 ratio)
    #
    # A butterfly spread consists of:
    # - 1 long option at lower strike
    # - 2 short options at middle strike
    # - 1 long option at higher strike
    #
    # This creates a profit zone centered around the middle strike with limited risk.
    # Can be constructed with all calls or all puts.
    #
    # @param long_low [Models::Option] Long option at lower strike
    # @param short_middle [Models::Option] Short option at middle strike (sold 2x)
    # @param long_high [Models::Option] Long option at higher strike
    # @param quantity [Integer] Number of butterflies (middle leg gets 2x quantity)
    # @param price [BigDecimal, nil] Net debit limit price (nil for market order)
    # @param time_in_force [OrderTimeInForce] Order time in force (default: DAY)
    #
    # @return [Order] The constructed butterfly spread order
    #
    # @raise [InvalidStrategyError] if options don't meet butterfly requirements:
    #   - All options must be same type (all calls or all puts)
    #   - Wings must be equidistant from center
    #   - All options must have same expiration
    #   - All options must have same underlying
    #
    # @example Create a call butterfly with 10-point wings
    #   long_low = option_at_strike(610, :call)
    #   short_middle = option_at_strike(620, :call)
    #   long_high = option_at_strike(630, :call)
    #   order = builder.butterfly_spread(long_low, short_middle, long_high, 1, price: 1.50)
    def butterfly_spread(
      long_low,
      short_middle,
      long_high,
      quantity,
      price: nil,
      time_in_force: OrderTimeInForce::DAY
    )
      validate_butterfly_spread!(long_low, short_middle, long_high)

      legs = [
        build_option_leg(long_low, quantity, OrderAction::BUY_TO_OPEN),
        build_option_leg(short_middle, quantity * 2, OrderAction::SELL_TO_OPEN),
        build_option_leg(long_high, quantity, OrderAction::BUY_TO_OPEN)
      ]

      order_type = price ? OrderType::LIMIT : OrderType::MARKET

      Order.new(
        type: order_type,
        time_in_force: time_in_force,
        legs: legs,
        price: price
      )
    end

    # Creates a calendar spread order (time spread)
    #
    # A calendar spread consists of:
    # - Short option at near-term expiration
    # - Long option at longer-term expiration
    # - Both at the same strike price
    #
    # This strategy profits from time decay differential between the two options.
    # Also known as a horizontal spread or time spread.
    #
    # @param short_option [Models::Option] Short option with nearer expiration
    # @param long_option [Models::Option] Long option with farther expiration
    # @param quantity [Integer] Number of calendar spreads to create
    # @param price [BigDecimal, nil] Net debit limit price (nil for market order)
    # @param time_in_force [OrderTimeInForce] Order time in force (default: DAY)
    #
    # @return [Order] The constructed calendar spread order
    #
    # @raise [InvalidStrategyError] if options don't meet calendar spread requirements:
    #   - Options must have same strike price
    #   - Options must have different expiration dates
    #   - Short option must expire before long option
    #   - Options must be same type (both calls or both puts)
    #   - Options must have same underlying
    #
    # @example Create a call calendar spread at strike 620
    #   short_option = option_at_strike_and_dte(620, 30, :call)
    #   long_option = option_at_strike_and_dte(620, 60, :call)
    #   order = builder.calendar_spread(short_option, long_option, 1, price: 1.00)
    def calendar_spread(
      short_option,
      long_option,
      quantity,
      price: nil,
      time_in_force: OrderTimeInForce::DAY
    )
      validate_calendar_spread!(short_option, long_option)

      legs = [
        build_option_leg(short_option, quantity, OrderAction::SELL_TO_OPEN),
        build_option_leg(long_option, quantity, OrderAction::BUY_TO_OPEN)
      ]

      order_type = price ? OrderType::LIMIT : OrderType::MARKET

      Order.new(
        type: order_type,
        time_in_force: time_in_force,
        legs: legs,
        price: price
      )
    end

    # Creates a diagonal spread order (different strikes AND expirations)
    #
    # A diagonal spread combines elements of vertical and calendar spreads:
    # - Short option at near-term expiration and one strike
    # - Long option at longer-term expiration and different strike
    #
    # This strategy allows for directional bias while benefiting from time decay.
    # More flexible than pure calendar or vertical spreads.
    #
    # @param short_option [Models::Option] Short option with nearer expiration
    # @param long_option [Models::Option] Long option with farther expiration and different strike
    # @param quantity [Integer] Number of diagonal spreads to create
    # @param price [BigDecimal, nil] Net debit limit price (nil for market order)
    # @param time_in_force [OrderTimeInForce] Order time in force (default: DAY)
    #
    # @return [Order] The constructed diagonal spread order
    #
    # @raise [InvalidStrategyError] if options don't meet diagonal spread requirements:
    #   - Options must have different strike prices
    #   - Options must have different expiration dates
    #   - Short option must expire before long option
    #   - Options must be same type (both calls or both puts)
    #   - Options must have same underlying
    #
    # @example Create a bullish call diagonal spread
    #   short_option = option_at_strike_and_dte(620, 30, :call)
    #   long_option = option_at_strike_and_dte(625, 60, :call)
    #   order = builder.diagonal_spread(short_option, long_option, 1, price: 2.00)
    def diagonal_spread(
      short_option,
      long_option,
      quantity,
      price: nil,
      time_in_force: OrderTimeInForce::DAY
    )
      validate_diagonal_spread!(short_option, long_option)

      legs = [
        build_option_leg(short_option, quantity, OrderAction::SELL_TO_OPEN),
        build_option_leg(long_option, quantity, OrderAction::BUY_TO_OPEN)
      ]

      order_type = price ? OrderType::LIMIT : OrderType::MARKET

      Order.new(
        type: order_type,
        time_in_force: time_in_force,
        legs: legs,
        price: price
      )
    end

    # Creates a strangle order (different strikes, same expiration)
    #
    # @param put_option [Models::Option] The put option
    # @param call_option [Models::Option] The call option
    # @param quantity [Integer] Number of strangles to create
    # @param action [OrderAction] BUY_TO_OPEN or SELL_TO_OPEN
    # @param price [BigDecimal, nil] Net debit/credit limit price (nil for market)
    # @param time_in_force [OrderTimeInForce] Order time in force (default: DAY)
    # @return [Order] The constructed strangle order
    # @raise [InvalidStrategyError] if options don't meet strangle requirements
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

    # Creates a straddle order (same strike and expiration)
    #
    # @param put_option [Models::Option] The put option
    # @param call_option [Models::Option] The call option
    # @param quantity [Integer] Number of straddles to create
    # @param action [OrderAction] BUY_TO_OPEN or SELL_TO_OPEN
    # @param price [BigDecimal, nil] Net debit/credit limit price (nil for market)
    # @param time_in_force [OrderTimeInForce] Order time in force (default: DAY)
    # @return [Order] The constructed straddle order
    # @raise [InvalidStrategyError] if options don't meet straddle requirements
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

    # Calculates the net premium for a multi-leg option order
    #
    # @param order [Order] The order to calculate premium for
    # @return [BigDecimal] Net premium (positive for credit, negative for debit)
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

    def validate_iron_butterfly!(short_call, long_call, short_put, long_put)
      [short_call, long_call, short_put, long_put].each { |opt| validate_option!(opt) }

      unless short_call.option_type == "C" && long_call.option_type == "C"
        raise InvalidStrategyError, "Call options must be calls"
      end

      unless short_put.option_type == "P" && long_put.option_type == "P"
        raise InvalidStrategyError, "Put options must be puts"
      end

      unless [short_call, long_call, short_put, long_put].map(&:expiration_date).uniq.size == 1
        raise InvalidStrategyError, "All options must have same expiration date"
      end

      unless [short_call, long_call, short_put, long_put].map(&:underlying_symbol).uniq.size == 1
        raise InvalidStrategyError, "All options must have same underlying symbol"
      end

      unless short_call.strike_price == short_put.strike_price
        raise InvalidStrategyError, "Short call and short put must have same strike price (center strike)"
      end

      unless long_call.strike_price > short_call.strike_price
        raise InvalidStrategyError, "Long call strike must be higher than short call strike"
      end

      unless long_put.strike_price < short_put.strike_price
        raise InvalidStrategyError, "Long put strike must be lower than short put strike"
      end

      call_wing = long_call.strike_price - short_call.strike_price
      put_wing = short_put.strike_price - long_put.strike_price

      unless call_wing == put_wing
        raise InvalidStrategyError, "Wing widths must be equal (call wing: #{call_wing}, put wing: #{put_wing})"
      end
    end

    def validate_butterfly_spread!(long_low, short_middle, long_high)
      [long_low, short_middle, long_high].each { |opt| validate_option!(opt) }

      unless long_low.option_type == short_middle.option_type && short_middle.option_type == long_high.option_type
        raise InvalidStrategyError, "All options must be same type (all calls or all puts)"
      end

      unless [long_low, short_middle, long_high].map(&:expiration_date).uniq.size == 1
        raise InvalidStrategyError, "All options must have same expiration date"
      end

      unless [long_low, short_middle, long_high].map(&:underlying_symbol).uniq.size == 1
        raise InvalidStrategyError, "All options must have same underlying symbol"
      end

      unless long_low.strike_price < short_middle.strike_price
        raise InvalidStrategyError, "Low strike must be lower than middle strike"
      end

      unless short_middle.strike_price < long_high.strike_price
        raise InvalidStrategyError, "Middle strike must be lower than high strike"
      end

      lower_wing = short_middle.strike_price - long_low.strike_price
      upper_wing = long_high.strike_price - short_middle.strike_price

      unless lower_wing == upper_wing
        raise InvalidStrategyError, "Wings must be equidistant from center (lower: #{lower_wing}, upper: #{upper_wing})"
      end
    end

    def validate_calendar_spread!(short_option, long_option)
      validate_option!(short_option)
      validate_option!(long_option)

      unless short_option.option_type == long_option.option_type
        raise InvalidStrategyError, "Options must be same type (both calls or both puts)"
      end

      unless short_option.underlying_symbol == long_option.underlying_symbol
        raise InvalidStrategyError, "Options must have same underlying symbol"
      end

      unless short_option.strike_price == long_option.strike_price
        raise InvalidStrategyError, "Options must have same strike price for calendar spread"
      end

      if short_option.expiration_date == long_option.expiration_date
        raise InvalidStrategyError, "Options must have different expiration dates for calendar spread"
      end

      unless short_option.expiration_date < long_option.expiration_date
        raise InvalidStrategyError, "Short option must expire before long option"
      end
    end

    def validate_diagonal_spread!(short_option, long_option)
      validate_option!(short_option)
      validate_option!(long_option)

      unless short_option.option_type == long_option.option_type
        raise InvalidStrategyError, "Options must be same type (both calls or both puts)"
      end

      unless short_option.underlying_symbol == long_option.underlying_symbol
        raise InvalidStrategyError, "Options must have same underlying symbol"
      end

      if short_option.strike_price == long_option.strike_price
        raise InvalidStrategyError, "Options must have different strike prices for diagonal spread"
      end

      if short_option.expiration_date == long_option.expiration_date
        raise InvalidStrategyError, "Options must have different expiration dates for diagonal spread"
      end

      unless short_option.expiration_date < long_option.expiration_date
        raise InvalidStrategyError, "Short option must expire before long option"
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
