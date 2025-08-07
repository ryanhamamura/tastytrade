# frozen_string_literal: true

require "bigdecimal"
require "time"

module Tastytrade
  # Validates orders before submission to ensure they meet all requirements.
  # Performs comprehensive checks including symbol validation, quantity constraints,
  # price validation, account permissions, buying power, and market hours.
  #
  # @example Basic usage
  #   validator = OrderValidator.new(session, account, order)
  #   validator.validate! # Raises OrderValidationError if invalid
  #
  # @example With dry-run validation
  #   validator = OrderValidator.new(session, account, order)
  #   response = validator.dry_run_validate!
  #   puts validator.warnings if validator.warnings.any?
  class OrderValidator
    # @return [Array<String>] List of validation errors
    attr_reader :errors

    # @return [Array<String>] List of validation warnings
    attr_reader :warnings

    # Common tick sizes for different price ranges
    TICK_SIZES = {
      penny: BigDecimal("0.01"),
      nickel: BigDecimal("0.05"),
      dime: BigDecimal("0.10")
    }.freeze

    # Minimum quantity constraints
    MIN_QUANTITY = 1
    MAX_QUANTITY = 999_999

    # Creates a new OrderValidator instance
    #
    # @param session [Tastytrade::Session] Active trading session
    # @param account [Tastytrade::Models::Account] Account to validate against
    # @param order [Tastytrade::Order] Order to validate
    def initialize(session, account, order)
      @session = session
      @account = account
      @order = order
      @errors = []
      @warnings = []
      @trading_status = nil
      @dry_run_response = nil
    end

    # Performs comprehensive order validation including structure, symbols,
    # quantities, prices, account permissions, market hours, and optionally
    # buying power via dry-run.
    #
    # @param skip_dry_run [Boolean] Skip the dry-run validation (for performance)
    # @return [Boolean] true if validation passes
    # @raise [OrderValidationError] if validation fails with detailed error messages
    def validate!(skip_dry_run: false)
      # Reset errors and warnings
      @errors = []
      @warnings = []

      # Run all validations
      validate_order_structure!
      validate_symbols!
      validate_quantities!
      validate_prices!
      validate_account_permissions!
      validate_market_hours!
      validate_buying_power! unless skip_dry_run

      # Raise error if any validation failed
      raise OrderValidationError, @errors if @errors.any?

      true
    end

    # Performs pre-flight validation via dry-run API call. This checks buying power,
    # margin requirements, and API-level validation rules without placing the order.
    #
    # @return [Tastytrade::Models::OrderResponse, nil] Dry-run response if successful, nil if failed
    def dry_run_validate!
      @dry_run_response = @account.place_order(@session, @order, dry_run: true)

      # Check for API-level errors
      if @dry_run_response.errors.any?
        @errors.concat(@dry_run_response.errors.map { |e| format_api_error(e) })
      end

      # Check for warnings
      if @dry_run_response.warnings.any?
        @warnings.concat(@dry_run_response.warnings)
      end

      # Check buying power effect
      if @dry_run_response.buying_power_effect
        validate_buying_power_effect!(@dry_run_response.buying_power_effect)
      end

      @dry_run_response
    rescue StandardError => e
      @errors << "Dry-run validation failed: #{e.message}"
      nil
    end

    private

    # Validate basic order structure
    def validate_order_structure!
      # Check for at least one leg
      if @order.legs.nil? || @order.legs.empty?
        @errors << "Order must have at least one leg"
      end

      # Validate order type and price consistency
      if @order.limit? && @order.price.nil?
        @errors << "Limit orders require a price"
      end

      # Validate time in force
      if @order.time_in_force.nil?
        @errors << "Time in force is required"
      end
    end

    # Validate symbols exist and are tradeable
    def validate_symbols!
      return if @order.legs.nil?

      @order.legs.each do |leg|
        validate_symbol!(leg.symbol, leg.instrument_type)
      end
    end

    # Validate a single symbol
    def validate_symbol!(symbol, instrument_type)
      return if symbol.nil? || symbol.empty?

      case instrument_type
      when "Equity"
        validate_equity_symbol!(symbol)
      when "Option"
        # TODO: Implement option symbol validation
        @warnings << "Option symbol validation not yet implemented for #{symbol}"
      when "Future"
        # TODO: Implement futures symbol validation
        @warnings << "Futures symbol validation not yet implemented for #{symbol}"
      else
        @errors << "Unknown instrument type: #{instrument_type}"
      end
    end

    # Validate equity symbol exists
    def validate_equity_symbol!(symbol)
      # Try to fetch the equity to validate it exists
      Instruments::Equity.get(@session, symbol)
    rescue StandardError => e
      @errors << "Invalid equity symbol '#{symbol}': #{e.message}"
    end

    # Validate order quantities
    def validate_quantities!
      return if @order.legs.nil?

      @order.legs.each do |leg|
        validate_quantity!(leg.quantity, leg.symbol)
      end
    end

    # Validate a single quantity
    def validate_quantity!(quantity, symbol)
      # Check minimum quantity
      if quantity.nil? || quantity < MIN_QUANTITY
        @errors << "Quantity for #{symbol} must be at least #{MIN_QUANTITY}"
      end

      # Check maximum quantity
      if quantity && quantity > MAX_QUANTITY
        @errors << "Quantity for #{symbol} exceeds maximum of #{MAX_QUANTITY}"
      end

      # Check for whole shares (no fractional shares for now)
      if quantity && quantity != quantity.to_i
        @errors << "Fractional shares not supported for #{symbol}"
      end
    end

    # Validate order prices
    def validate_prices!
      return unless @order.limit?

      validate_price!(@order.price)
    end

    # Validate a single price
    def validate_price!(price)
      return if price.nil?

      # Check for positive price
      if price <= 0
        @errors << "Price must be greater than 0"
      end

      # Check for reasonable price (not too high)
      if price > BigDecimal("999999")
        @errors << "Price exceeds reasonable limits"
      end

      # Round to appropriate tick size
      rounded_price = round_to_tick_size(price)
      if rounded_price != price
        @warnings << "Price #{price} will be rounded to #{rounded_price}"
      end
    end

    # Round price to appropriate tick size
    def round_to_tick_size(price)
      return price if price.nil?

      # Simple tick size rules (can be enhanced based on instrument/exchange)
      tick = if price < BigDecimal("1")
        TICK_SIZES[:penny]
      elsif price < BigDecimal("10")
        TICK_SIZES[:penny]
      else
        TICK_SIZES[:penny]
      end

      (price / tick).round * tick
    end

    # Validate account permissions for the order
    def validate_account_permissions!
      @trading_status ||= @account.get_trading_status(@session)

      # Check if account is restricted
      if @trading_status.restricted?
        restrictions = @trading_status.active_restrictions
        @errors << "Account has active restrictions: #{restrictions.join(", ")}"
      end

      # Check specific permissions based on order type
      @order.legs.each do |leg|
        validate_leg_permissions!(leg)
      end
    end

    # Validate permissions for a specific leg
    def validate_leg_permissions!(leg)
      @trading_status ||= @account.get_trading_status(@session)

      case leg.instrument_type
      when "Option"
        unless @trading_status.can_trade_options?
          @errors << "Account does not have options trading permissions"
        end
      when "Future"
        unless @trading_status.can_trade_futures?
          @errors << "Account does not have futures trading permissions"
        end
      when "Cryptocurrency"
        unless @trading_status.can_trade_cryptocurrency?
          @errors << "Account does not have cryptocurrency trading permissions"
        end
      end

      # Check for closing-only restrictions
      if opening_order?(leg.action) && @trading_status.is_closing_only
        @errors << "Account is restricted to closing orders only"
      end
    end

    # Check if this is an opening order
    def opening_order?(action)
      [OrderAction::BUY_TO_OPEN, OrderAction::SELL_TO_OPEN].include?(action)
    end

    # Validate market hours
    def validate_market_hours!
      # Get current time
      now = Time.now

      # Check if it's a market order during extended hours
      if @order.market? && !regular_market_hours?(now)
        @warnings << "Market orders may not be accepted outside regular trading hours"
      end

      # Basic weekday/weekend check
      if weekend?(now)
        @warnings << "Markets are closed on weekends"
      end
    end

    # Check if current time is during regular market hours (9:30 AM - 4:00 PM ET)
    def regular_market_hours?(time)
      # Convert to Eastern Time (simplified - should use proper timezone library)
      hour = time.hour
      minute = time.min

      # Rough check for market hours (9:30 AM - 4:00 PM ET)
      # Note: This is simplified and doesn't account for timezones properly
      return false if hour < 9 || hour >= 16
      return false if hour == 9 && minute < 30

      true
    end

    # Check if it's a weekend
    def weekend?(time)
      time.saturday? || time.sunday?
    end

    # Validate buying power via dry-run
    def validate_buying_power!
      # If we haven't run dry-run yet, do it now
      @dry_run_response ||= dry_run_validate!
      return if @dry_run_response.nil?

      effect = @dry_run_response.buying_power_effect
      return if effect.nil?

      validate_buying_power_effect!(effect)
    end

    # Validate buying power effect from dry-run
    def validate_buying_power_effect!(effect)
      # Check if order would result in negative buying power
      if effect.new_buying_power && effect.new_buying_power < 0
        @errors << "Insufficient buying power. Order requires #{effect.buying_power_change_amount}, " \
                   "but only #{effect.current_buying_power} available"
      end

      # Warn if using significant portion of buying power
      if effect.buying_power_usage_percentage > BigDecimal("50")
        percentage = effect.buying_power_usage_percentage.to_f.round(1)
        @warnings << "Order will use #{percentage}% of available buying power"
      end

      # Check for margin requirements
      if effect.change_in_margin_requirement && effect.change_in_margin_requirement.abs > effect.current_buying_power
        @errors << "Margin requirement of #{effect.change_in_margin_requirement.abs} exceeds available buying power"
      end
    end

    # Format API error for display
    def format_api_error(error)
      if error.is_a?(Hash)
        "#{error["domain"]}: #{error["reason"]}"
      else
        error.to_s
      end
    end
  end
end
