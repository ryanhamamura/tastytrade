# frozen_string_literal: true

require "bigdecimal"
require "date"

module Tastytrade
  module Models
    # Represents a hierarchical option chain structure with nested Expiration and Strike models,
    # providing a more structured approach to option chain data organization.
    #
    # @example Loading a nested chain
    #   chain = NestedOptionChain.get(session, "SPY")
    #   chain.expirations.each do |expiration|
    #     puts "#{expiration.expiration_date}: #{expiration.strikes.count} strikes"
    #   end
    #
    # @example Finding options by strike and expiration
    #   symbols = chain.option_symbols_for_strike(BigDecimal("450"), Date.parse("2024-03-15"))
    #   call_symbol = symbols[:call]  # => "SPY240315C00450000"
    #   put_symbol = symbols[:put]    # => "SPY240315P00450000"
    class NestedOptionChain < Base
      attr_reader :underlying_symbol, :root_symbol, :option_chain_type,
                  :shares_per_contract, :tick_sizes, :deliverables, :expirations

      # Represents a single strike price with associated call and put option symbols
      class Strike
        attr_reader :strike_price, :call, :put, :call_streamer_symbol, :put_streamer_symbol

        def initialize(data)
          @strike_price = parse_financial_value(data["strike-price"] || data["strike_price"])
          @call = data["call"]
          @put = data["put"]
          @call_streamer_symbol = data["call-streamer-symbol"] || data["call_streamer_symbol"]
          @put_streamer_symbol = data["put-streamer-symbol"] || data["put_streamer_symbol"]
        end

        private

        def parse_financial_value(value)
          return nil if value.nil? || value.to_s.empty?

          BigDecimal(value.to_s)
        end
      end

      # Represents an expiration date with all available strikes
      class Expiration
        attr_reader :expiration_date, :days_to_expiration, :expiration_type,
                    :settlement_type, :strikes

        def initialize(data)
          @expiration_date = parse_date(data["expiration-date"] || data["expiration_date"])
          @days_to_expiration = data["days-to-expiration"] || data["days_to_expiration"]
          @expiration_type = data["expiration-type"] || data["expiration_type"]
          @settlement_type = data["settlement-type"] || data["settlement_type"]

          parse_strikes(data)
        end

        # @return [Boolean] true if this is a weekly expiration
        def weekly?
          @expiration_type == "Weekly"
        end

        # @return [Boolean] true if this is a monthly (regular) expiration
        def monthly?
          @expiration_type == "Regular"
        end

        # @return [Boolean] true if this is a quarterly expiration
        def quarterly?
          @expiration_type == "Quarterly"
        end

        private

        def parse_date(value)
          return nil if value.nil? || value.to_s.empty?

          Date.parse(value.to_s)
        end

        def parse_strikes(data)
          strikes_data = data["strikes"] || []
          @strikes = strikes_data.map { |strike_data| Strike.new(strike_data) }
        end
      end

      def initialize(data)
        super
      end

      # Class methods for API integration
      class << self
        # Retrieves nested option chain data from the API
        #
        # @param session [Tastytrade::Session] Active session
        # @param symbol [String] Underlying symbol
        # @param options [Hash] Additional query parameters
        # @return [NestedOptionChain] NestedOptionChain object with hierarchical structure
        #
        # @example
        #   chain = NestedOptionChain.get(session, "SPY")
        def get(session, symbol, **options)
          params = options.merge(symbol: symbol)
          response = session.get("/option-chains/#{symbol}/nested", params: params)

          # The API returns data.items array with a single item containing the full chain
          if response["data"] && response["data"]["items"] && response["data"]["items"].first
            new(response["data"]["items"].first)
          else
            new(response["data"] || {})
          end
        end
      end

      # Returns all expiration dates in chronological order
      #
      # @return [Array<Date>] Sorted array of expiration dates
      def expiration_dates
        @expirations.map(&:expiration_date).compact.sort
      end

      # Returns all unique strike prices across all expirations
      #
      # @return [Array<BigDecimal>] Sorted array of unique strike prices
      def all_strikes
        @expirations.flat_map { |exp| exp.strikes.map(&:strike_price) }.uniq.compact.sort
      end

      # Finds an expiration by date
      #
      # @param date [Date] The expiration date to find
      # @return [Expiration, nil] The Expiration object or nil if not found
      def find_expiration(date)
        @expirations.find { |exp| exp.expiration_date == date }
      end

      # Returns only weekly expirations
      #
      # @return [Array<Expiration>] Array of weekly Expiration objects
      def weekly_expirations
        filtered_expirations = @expirations.select(&:weekly?)
        create_filtered_chain(filtered_expirations)
      end

      # Returns only monthly (regular) expirations
      #
      # @return [NestedOptionChain] New chain with monthly expirations only
      def monthly_expirations
        filtered_expirations = @expirations.select(&:monthly?)
        create_filtered_chain(filtered_expirations)
      end

      # Returns only quarterly expirations
      #
      # @return [NestedOptionChain] New chain with quarterly expirations only
      def quarterly_expirations
        filtered_expirations = @expirations.select(&:quarterly?)
        create_filtered_chain(filtered_expirations)
      end

      # Filters expirations by days to expiration range
      #
      # @param min_dte [Integer] Minimum days to expiration
      # @param max_dte [Integer] Maximum days to expiration
      # @return [Array<Expiration>] Filtered array of Expiration objects
      #
      # @example
      #   near_term = chain.filter_by_dte(max_dte: 30)
      #   mid_term = chain.filter_by_dte(min_dte: 30, max_dte: 60)
      def filter_by_dte(min_dte: nil, max_dte: nil)
        filtered_expirations = @expirations.select do |exp|
          dte = exp.days_to_expiration
          next false if dte.nil?
          next false if min_dte && dte < min_dte
          next false if max_dte && dte > max_dte

          true
        end

        create_filtered_chain(filtered_expirations)
      end

      # Returns the expiration closest to today's date
      #
      # @return [Expiration, nil] The nearest Expiration object
      def nearest_expiration
        today = Date.today
        @expirations.min_by do |exp|
          next Float::INFINITY if exp.expiration_date.nil?

          (exp.expiration_date - today).abs
        end
      end

      # Returns strikes for a specific expiration date
      #
      # @param expiration_date [Date] The expiration date
      # @return [Array<Strike>] Array of Strike objects for the expiration
      def strikes_for_expiration(expiration_date)
        exp = find_expiration(expiration_date)
        exp&.strikes || []
      end

      # Finds the strike price closest to the current price
      #
      # @param current_price [BigDecimal, Numeric] Current price of underlying
      # @param expiration_date [Date, nil] Optional specific expiration date
      # @return [BigDecimal, nil] ATM strike price or nil if not found
      #
      # @example
      #   atm = chain.at_the_money_strike(BigDecimal("450"))
      #   atm_for_exp = chain.at_the_money_strike(BigDecimal("450"), Date.parse("2024-03-15"))
      def at_the_money_strike(current_price, expiration_date = nil)
        return nil if current_price.nil?

        if expiration_date
          strikes = strikes_for_expiration(expiration_date)
          strike_prices = strikes.map(&:strike_price).compact
        else
          strike_prices = all_strikes
        end

        return nil if strike_prices.empty?

        # Find closest strike to current price
        strike_prices.min_by { |strike| (strike - current_price).abs }
      end

      # Returns call and put symbols for a specific strike and expiration
      #
      # @param strike_price [BigDecimal, Numeric] The strike price
      # @param expiration_date [Date] The expiration date
      # @return [Hash] Hash with :call and :put keys containing option symbols
      #
      # @example
      #   symbols = chain.option_symbols_for_strike(BigDecimal("450"), Date.parse("2024-03-15"))
      #   symbols[:call]  # => "SPY240315C00450000"
      #   symbols[:put]   # => "SPY240315P00450000"
      def option_symbols_for_strike(strike_price, expiration_date)
        exp = find_expiration(expiration_date)
        return { call: nil, put: nil } unless exp

        strike = exp.strikes.find { |s| s.strike_price == strike_price }
        return { call: nil, put: nil } unless strike

        { call: strike.call, put: strike.put }
      end

      private

      def create_filtered_chain(filtered_expirations)
        # Create a new chain with filtered expirations
        filtered_data = @data.dup
        # Keep the expirations as objects - they'll be parsed in initialize
        filtered_data["expirations"] = filtered_expirations

        # Create new instance, but we need to bypass normal initialization
        # Instead, create a minimal data structure that will work
        new_chain = self.class.allocate
        new_chain.instance_variable_set(:@data, filtered_data)
        new_chain.instance_variable_set(:@underlying_symbol, @underlying_symbol)
        new_chain.instance_variable_set(:@root_symbol, @root_symbol)
        new_chain.instance_variable_set(:@option_chain_type, @option_chain_type)
        new_chain.instance_variable_set(:@shares_per_contract, @shares_per_contract)
        new_chain.instance_variable_set(:@tick_sizes, @tick_sizes)
        new_chain.instance_variable_set(:@deliverables, @deliverables)
        new_chain.instance_variable_set(:@expirations, filtered_expirations)
        new_chain
      end

      def parse_attributes
        @underlying_symbol = @data["underlying-symbol"] || @data["underlying_symbol"]
        @root_symbol = @data["root-symbol"] || @data["root_symbol"]
        @option_chain_type = @data["option-chain-type"] || @data["option_chain_type"]
        @shares_per_contract = @data["shares-per-contract"] || @data["shares_per_contract"] || 100
        @tick_sizes = @data["tick-sizes"] || @data["tick_sizes"] || []
        @deliverables = @data["deliverables"] || []

        parse_expirations
      end

      def parse_expirations
        expirations_data = @data["expirations"] || []
        @expirations = expirations_data.map { |exp_data| Expiration.new(exp_data) }
      end
    end
  end
end
