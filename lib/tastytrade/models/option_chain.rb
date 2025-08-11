# frozen_string_literal: true

require "bigdecimal"
require "date"

module Tastytrade
  module Models
    # Represents a collection of options organized by expiration dates with
    # comprehensive filtering and analysis capabilities.
    #
    # @example Loading an option chain
    #   chain = OptionChain.get_chain(session, "SPY")
    #   chain.expiration_dates  # => [Date<2024-03-15>, Date<2024-03-22>, ...]
    #
    # @example Filtering options
    #   # Filter by moneyness
    #   itm_options = chain.filter_by_moneyness("ITM", current_price)
    #
    #   # Filter by expiration
    #   near_term = chain.filter_by_dte(max_dte: 30)
    #
    #   # Filter by strikes around ATM
    #   focused = chain.filter_by_strikes(5, current_price)  # 5 strikes centered on ATM
    class OptionChain < Base
      attr_reader :underlying_symbol, :root_symbol, :option_chain_type,
                  :shares_per_contract, :tick_sizes, :deliverables

      # Hash of expiration dates to arrays of Option objects
      attr_reader :expirations

      def initialize(data)
        super
      end

      # Class methods for API integration
      class << self
        # Retrieves option chain data from the API
        #
        # @param session [Tastytrade::Session] Active session
        # @param symbol [String] Underlying symbol
        # @param options [Hash] Additional query parameters
        # @return [OptionChain] OptionChain object with all expirations and strikes
        #
        # @example
        #   chain = OptionChain.get_chain(session, "SPY")
        #   chain = OptionChain.get_chain(session, "AAPL", strikes: 10)
        def get_chain(session, symbol, **options)
          params = options.merge(symbol: symbol)
          response = session.get("/option-chains/#{symbol}/compact", params: params)

          # The API returns data.items array with expiration groups
          # We need to merge all items into a single chain structure
          if response["data"] && response["data"]["items"]
            merged_data = {
              "underlying-symbol" => nil,
              "root-symbol" => nil,
              "option-chain-type" => nil,
              "shares-per-contract" => nil,
              "symbols" => []
            }

            response["data"]["items"].each do |item|
              # Take metadata from first item
              if merged_data["underlying-symbol"].nil?
                merged_data["underlying-symbol"] = item["underlying-symbol"]
                merged_data["root-symbol"] = item["root-symbol"]
                merged_data["option-chain-type"] = item["option-chain-type"]
                merged_data["shares-per-contract"] = item["shares-per-contract"]
              end

              # Collect all symbols
              merged_data["symbols"] ||= []
              merged_data["symbols"].concat(item["symbols"] || [])
            end

            new(merged_data)
          else
            new(response["data"] || {})
          end
        end
      end

      # Returns all expiration dates in chronological order
      #
      # @return [Array<Date>] Sorted array of expiration dates
      def expiration_dates
        @expirations.keys.sort
      end

      # Returns all options across all expirations
      #
      # @return [Array<Option>] Flattened array of all Option objects
      def all_options
        @expirations.values.flatten
      end

      # Returns options for a specific expiration date
      #
      # @param expiration_date [Date] The expiration date to retrieve
      # @return [Array<Option>] Options expiring on the given date, empty array if none
      def options_for_expiration(expiration_date)
        @expirations[expiration_date] || []
      end

      # Returns all call options across all expirations
      #
      # @return [Array<Option>] Array of call options only
      def calls
        all_options.select(&:call?)
      end

      # Returns all put options across all expirations
      #
      # @return [Array<Option>] Array of put options only
      def puts
        all_options.select(&:put?)
      end

      # Filters the chain by expiration date or date range
      #
      # @param start_date [Date] Minimum expiration date (inclusive)
      # @param end_date [Date] Maximum expiration date (inclusive)
      # @param expiration [Date] Specific expiration date to filter for
      # @return [OptionChain] New OptionChain with filtered expirations
      #
      # @example
      #   # Single expiration
      #   chain.filter_by_expiration(expiration: Date.parse("2024-03-15"))
      #
      #   # Date range
      #   chain.filter_by_expiration(start_date: Date.today, end_date: Date.today + 30)
      def filter_by_expiration(start_date: nil, end_date: nil, expiration: nil)
        filtered = {}

        @expirations.each do |exp_date, options|
          if expiration
            next unless exp_date == expiration
          else
            next if start_date && exp_date < start_date
            next if end_date && exp_date > end_date
          end

          filtered[exp_date] = options
        end

        create_filtered_chain(filtered)
      end

      # Filters to a specified number of strikes centered around ATM
      #
      # @param num_strikes [Integer] Number of strikes to include (centered on ATM)
      # @param current_price [BigDecimal, Numeric] Current price for ATM calculation
      # @return [OptionChain] New OptionChain with filtered strikes
      #
      # @example
      #   chain.filter_by_strikes(5, BigDecimal("450"))  # 5 strikes around 450
      def filter_by_strikes(num_strikes, current_price)
        return self if current_price.nil? || num_strikes.nil?

        filtered = {}

        @expirations.each do |exp_date, options|
          sorted_strikes = options.map(&:strike_price).uniq.compact.sort
          next if sorted_strikes.empty?

          # Find ATM strike
          atm_strike = find_atm_strike(sorted_strikes, current_price)
          atm_index = sorted_strikes.index(atm_strike)
          next unless atm_index

          # Calculate range
          strikes_each_side = num_strikes / 2
          start_index = [0, atm_index - strikes_each_side].max
          end_index = [sorted_strikes.length - 1, atm_index + strikes_each_side].min

          selected_strikes = sorted_strikes[start_index..end_index]

          # Filter options by selected strikes
          filtered_options = options.select do |opt|
            selected_strikes.include?(opt.strike_price)
          end

          filtered[exp_date] = filtered_options unless filtered_options.empty?
        end

        create_filtered_chain(filtered)
      end

      # Filters options by moneyness classification
      #
      # @param moneyness [String] "ITM", "ATM", or "OTM"
      # @param current_price [BigDecimal, Numeric] Current price for moneyness calculation
      # @param atm_threshold [BigDecimal] Percentage threshold for ATM classification
      # @return [OptionChain] New OptionChain with filtered options
      #
      # @example
      #   itm_chain = chain.filter_by_moneyness("ITM", BigDecimal("450"))
      #   atm_chain = chain.filter_by_moneyness("ATM", BigDecimal("450"), atm_threshold: BigDecimal("0.02"))
      def filter_by_moneyness(moneyness, current_price, atm_threshold: BigDecimal("0.01"))
        return self if current_price.nil?

        moneyness = moneyness.to_s.upcase
        valid_moneyness = %w[ITM ATM OTM]
        return self unless valid_moneyness.include?(moneyness)

        filtered = {}

        @expirations.each do |exp_date, options|
          filtered_options = options.select do |opt|
            opt.moneyness_classification(current_price, atm_threshold: atm_threshold) == moneyness
          end

          filtered[exp_date] = filtered_options unless filtered_options.empty?
        end

        create_filtered_chain(filtered)
      end

      # Finds the strike price closest to the current price
      #
      # @param current_price [BigDecimal, Numeric] Current price of underlying
      # @return [BigDecimal, nil] ATM strike price or nil if no strikes available
      def at_the_money_strike(current_price)
        return nil if current_price.nil?

        all_strikes = all_options.map(&:strike_price).uniq.compact
        return nil if all_strikes.empty?

        find_atm_strike(all_strikes, current_price)
      end

      # Returns the nearest strike prices to the current price
      #
      # @param current_price [BigDecimal, Numeric] Current price of underlying
      # @param num_strikes [Integer] Number of strikes to return (default: 5)
      # @return [Array<BigDecimal>] Array of nearest strike prices
      def nearest_strikes(current_price, num_strikes = 5)
        return [] if current_price.nil?

        all_strikes = all_options.map(&:strike_price).uniq.compact.sort
        return all_strikes if all_strikes.length <= num_strikes

        # Find closest strike
        atm_strike = find_atm_strike(all_strikes, current_price)
        atm_index = all_strikes.index(atm_strike)
        return all_strikes.first(num_strikes) unless atm_index

        # Get strikes around ATM
        strikes_each_side = num_strikes / 2
        start_index = [0, atm_index - strikes_each_side].max
        end_index = [all_strikes.length - 1, atm_index + strikes_each_side].min

        all_strikes[start_index..end_index]
      end

      # Filters options by days to expiration
      #
      # @param min_dte [Integer] Minimum days to expiration
      # @param max_dte [Integer] Maximum days to expiration
      # @return [OptionChain] New OptionChain with filtered expirations
      #
      # @example
      #   near_term = chain.filter_by_dte(max_dte: 30)
      #   mid_term = chain.filter_by_dte(min_dte: 30, max_dte: 60)
      def filter_by_dte(min_dte: nil, max_dte: nil)
        today = Date.today
        filtered = {}

        @expirations.each do |exp_date, options|
          dte = (exp_date - today).to_i
          next if min_dte && dte < min_dte
          next if max_dte && dte > max_dte

          filtered[exp_date] = options
        end

        create_filtered_chain(filtered)
      end

      # Returns only weekly expirations
      #
      # @return [OptionChain] New OptionChain with weekly expirations only
      def weekly_expirations
        filter_expirations_by_type("Weekly")
      end

      # Returns only monthly (regular) expirations
      #
      # @return [OptionChain] New OptionChain with monthly expirations only
      def monthly_expirations
        filter_expirations_by_type("Regular")
      end

      # Returns only quarterly expirations
      #
      # @return [OptionChain] New OptionChain with quarterly expirations only
      def quarterly_expirations
        filter_expirations_by_type("Quarterly")
      end

      private

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
        @expirations = {}

        # Handle different possible response formats

        # For compact chain format with just symbols
        if @data["symbols"].is_a?(Array) && !@data["symbols"].empty?
          # Parse symbols to create minimal Option objects
          @data["symbols"].each do |symbol|
            next unless symbol.is_a?(String)

            # Parse the OCC symbol format: SPY   250811C00400000
            # Format: ROOT YYMMDD[C/P]SSSSSCCC
            if symbol =~ /^(\S+)\s+(\d{6})([CP])(\d{8})$/
              root = $1
              date_str = $2
              option_type = $3 == "C" ? "Call" : "Put"
              strike_str = $4

              # Parse date (YYMMDD format)
              year = "20" + date_str[0..1]
              month = date_str[2..3]
              day = date_str[4..5]
              exp_date = Date.parse("#{year}-#{month}-#{day}") rescue nil

              # Parse strike (format: SSSSSCCC where last 3 are decimals)
              strike_price = (strike_str.to_i / 1000.0).to_s

              if exp_date
                # Create minimal option data
                option_data = {
                  "symbol" => symbol.strip,
                  "root-symbol" => root,
                  "underlying-symbol" => @underlying_symbol,
                  "option-type" => option_type,
                  "expiration-date" => exp_date.to_s,
                  "strike-price" => strike_price
                }

                option = Option.new(option_data)
                @expirations[exp_date] ||= []
                @expirations[exp_date] << option
              end
            end
          end
        else
          # Original logic for full option data
          items = @data["items"] || @data["options"] || []

          if items.is_a?(Array)
            # Flat array of options - group by expiration
            items.each do |option_data|
              option = Option.new(option_data)
              exp_date = option.expiration_date
              next unless exp_date

              @expirations[exp_date] ||= []
              @expirations[exp_date] << option
            end
          elsif items.is_a?(Hash)
            # Already grouped by expiration
            items.each do |exp_str, options_array|
              exp_date = Date.parse(exp_str.to_s)
              @expirations[exp_date] = options_array.map { |opt_data| Option.new(opt_data) }
            end
          end
        end

        # Handle nested expiration structure
        if @data["expirations"]
          @data["expirations"].each do |exp_data|
            exp_date = Date.parse(exp_data["expiration-date"] || exp_data["expiration_date"])
            options = exp_data["options"] || []
            @expirations[exp_date] = options.map { |opt_data| Option.new(opt_data) }
          end
        end
      end

      def find_atm_strike(strikes, current_price)
        return nil if strikes.empty?

        # Find the strike closest to current price
        strikes.min_by { |strike| (strike - current_price).abs }
      end

      def create_filtered_chain(filtered_expirations)
        # Create a new OptionChain with filtered data
        data = {
          "underlying-symbol" => @underlying_symbol,
          "root-symbol" => @root_symbol,
          "option-chain-type" => @option_chain_type,
          "shares-per-contract" => @shares_per_contract,
          "tick-sizes" => @tick_sizes,
          "deliverables" => @deliverables
        }

        chain = self.class.new(data)
        chain.instance_variable_set(:@expirations, filtered_expirations)
        chain
      end

      def filter_expirations_by_type(type)
        filtered = {}

        @expirations.each do |exp_date, options|
          # Check if any option in this expiration has the specified type
          if options.any? { |opt| opt.expiration_type == type }
            filtered[exp_date] = options
          end
        end

        create_filtered_chain(filtered)
      end
    end
  end
end
