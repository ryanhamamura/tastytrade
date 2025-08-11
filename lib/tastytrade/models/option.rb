# frozen_string_literal: true

require "bigdecimal"
require "date"

module Tastytrade
  module Models
    # Represents an individual option contract with comprehensive attributes including
    # Greeks, pricing data, and utility methods for option analysis.
    #
    # @example Creating an option from API data
    #   option_data = session.get("/instruments/options", params: { symbols: "SPY240315C00450000" })
    #   option = Tastytrade::Models::Option.new(option_data["items"].first)
    #
    # @example Checking moneyness
    #   current_price = BigDecimal("450")
    #   option.itm?(current_price)  # => true/false
    #   option.moneyness_classification(current_price)  # => "ITM", "ATM", or "OTM"
    #
    # @example Symbol conversion
    #   Option.occ_to_streamer_symbol("SPY240315C00450000")  # => ".SPY240315C450"
    #   Option.streamer_symbol_to_occ(".SPY240315C450")      # => "SPY240315C00450000"
    class Option < Base
      # Core identifiers
      attr_reader :symbol, :root_symbol, :underlying_symbol, :streamer_symbol

      # Option specifications
      attr_reader :option_type, :expiration_date, :strike_price, :contract_size,
                  :exercise_style, :expiration_type, :settlement_type

      # Trading attributes
      attr_reader :active, :days_to_expiration, :stops_trading_at, :expires_at,
                  :option_chain_type, :shares_per_contract

      # Greeks
      attr_reader :delta, :gamma, :theta, :vega, :rho, :implied_volatility

      # Pricing
      attr_reader :bid, :ask, :last, :mark, :bid_size, :ask_size, :last_size,
                  :high_price, :low_price, :open_price, :close_price, :volume,
                  :open_interest, :intrinsic_value, :extrinsic_value

      # Option types
      # @return [String] Call option type constant
      CALL = "Call"
      # @return [String] Put option type constant
      PUT = "Put"
      # @return [Array<String>] Valid option types
      OPTION_TYPES = [CALL, PUT].freeze

      # Exercise styles
      # @return [String] American exercise style constant
      AMERICAN = "American"
      # @return [String] European exercise style constant
      EUROPEAN = "European"
      # @return [Array<String>] Valid exercise styles
      EXERCISE_STYLES = [AMERICAN, EUROPEAN].freeze

      # Class methods for API integration
      class << self
        # Search for specific option contracts by symbols
        #
        # @param session [Tastytrade::Session] Active session
        # @param symbols [Array<String>, String] Option symbol(s) to search for
        # @return [Array<Option>] Array of Option objects matching the symbols
        #
        # @example Search for a single option
        #   option = Option.search(session, "SPY240315C00450000").first
        #
        # @example Search for multiple options
        #   options = Option.search(session, ["SPY240315C00450000", "SPY240315P00450000"])
        def search(session, symbols)
          symbols = Array(symbols)
          return [] if symbols.empty?

          params = { symbols: symbols.join(",") }
          response = session.get("/instruments/options", params: params)

          # API returns data.items array with option details
          if response["data"] && response["data"]["items"]
            response["data"]["items"].map { |item| new(item) }
          else
            []
          end
        end
      end

      # Expiration types
      # @return [String] Regular (monthly) expiration type constant
      REGULAR = "Regular"
      # @return [String] Weekly expiration type constant
      WEEKLY = "Weekly"
      # @return [String] Quarterly expiration type constant
      QUARTERLY = "Quarterly"
      # @return [Array<String>] Valid expiration types
      EXPIRATION_TYPES = [REGULAR, WEEKLY, QUARTERLY].freeze

      def initialize(data)
        super
        set_streamer_symbol if @symbol && !@streamer_symbol
      end

      # Class methods for API integration
      class << self
        # Retrieves option data from the API
        #
        # @param session [Tastytrade::Session] Active session
        # @param symbols [String, Array<String>] Option symbol(s) to retrieve
        # @param options [Hash] Additional query parameters
        # @return [Array<Option>] Array of Option objects
        #
        # @example
        #   options = Option.get(session, "SPY240315C00450000")
        #   multiple = Option.get(session, ["SPY240315C00450000", "SPY240315P00450000"])
        def get(session, symbols, **options)
          symbols = Array(symbols)
          params = options.merge(symbols: symbols.join(","))
          response = session.get("/instruments/options", params: params)
          response["data"]["items"].map { |item| new(item) }
        end

        # Convert OCC symbol to streamer format
        #
        # @param occ_symbol [String] OCC format symbol (e.g., "SPY240315C00450000")
        # @return [String, nil] Streamer format symbol (e.g., ".SPY240315C450") or nil if invalid
        #
        # @example
        #   Option.occ_to_streamer_symbol("SPY240315C00450000")  # => ".SPY240315C450"
        #   Option.occ_to_streamer_symbol("AAPL240315P00175500") # => ".AAPL240315P175.5"
        def occ_to_streamer_symbol(occ_symbol)
          return nil if occ_symbol.nil?

          # Parse OCC format: SYMBOL + YYMMDD + C/P + 00000000 (strike * 1000)
          match = occ_symbol.match(/^(.+?)(\d{6})([CP])(\d{8})$/)
          return nil unless match

          root = match[1]
          date = match[2]
          type = match[3]
          strike = match[4].to_i / 1000.0

          # Format strike without trailing zeros
          strike_str = strike == strike.to_i ? strike.to_i.to_s : strike.to_s.sub(/\.?0+$/, "")

          ".#{root}#{date}#{type}#{strike_str}"
        end

        # Convert streamer symbol to OCC format
        #
        # @param streamer_symbol [String] Streamer format symbol (e.g., ".SPY240315C450")
        # @return [String, nil] OCC format symbol (e.g., "SPY240315C00450000") or nil if invalid
        #
        # @example
        #   Option.streamer_symbol_to_occ(".SPY240315C450")      # => "SPY240315C00450000"
        #   Option.streamer_symbol_to_occ(".AAPL240315P175.5")   # => "AAPL240315P00175500"
        def streamer_symbol_to_occ(streamer_symbol)
          return nil if streamer_symbol.nil?

          # Remove leading dot if present
          symbol = streamer_symbol.sub(/^\./, "")

          # Parse streamer format: SYMBOL + YYMMDD + C/P + strike
          match = symbol.match(/^(.+?)(\d{6})([CP])(\d+\.?\d*)$/)
          return nil unless match

          root = match[1]
          date = match[2]
          type = match[3]
          strike = (match[4].to_f * 1000).to_i

          # Pad strike to 8 digits
          "#{root}#{date}#{type}#{strike.to_s.rjust(8, "0")}"
        end
      end

      # Instance methods

      # @return [Boolean] true if this is a call option
      def call?
        @option_type == CALL
      end

      # @return [Boolean] true if this is a put option
      def put?
        @option_type == PUT
      end

      # Checks if the option has expired
      #
      # @return [Boolean] true if expiration date is in the past, false otherwise
      def expired?
        return false if @expiration_date.nil?

        @expiration_date < Date.today
      end

      # Calculates days remaining until expiration
      #
      # @return [Integer, nil] Number of days until expiration, 0 if expired, nil if no expiration date
      def days_until_expiration
        return 0 if expired?
        return nil if @expiration_date.nil?

        (@expiration_date - Date.today).to_i
      end

      # Checks if option is in-the-money
      #
      # @param current_price [BigDecimal, Numeric] Current price of underlying
      # @return [Boolean, nil] true if ITM, false if not, nil if price is nil
      #
      # @example
      #   option.itm?(BigDecimal("450"))  # => true/false
      def itm?(current_price)
        return nil if current_price.nil? || @strike_price.nil?

        if call?
          current_price > @strike_price
        else
          current_price < @strike_price
        end
      end

      # Checks if option is out-of-the-money
      #
      # @param current_price [BigDecimal, Numeric] Current price of underlying
      # @return [Boolean, nil] true if OTM, false if not, nil if price is nil
      def otm?(current_price)
        return nil if current_price.nil? || @strike_price.nil?

        !itm?(current_price) && !atm?(current_price)
      end

      # Checks if option is at-the-money
      #
      # @param current_price [BigDecimal, Numeric] Current price of underlying
      # @param threshold [BigDecimal] Percentage threshold for ATM classification (default: 0.01 = 1%)
      # @return [Boolean, nil] true if ATM, false if not, nil if price is nil
      #
      # @example
      #   option.atm?(BigDecimal("450"))                              # => true/false
      #   option.atm?(BigDecimal("450"), threshold: BigDecimal("0.02")) # 2% threshold
      def atm?(current_price, threshold: BigDecimal("0.01"))
        return nil if current_price.nil? || @strike_price.nil?

        price_diff = (@strike_price - current_price).abs
        price_diff <= (current_price * threshold)
      end

      # Returns moneyness classification as a string
      #
      # @param current_price [BigDecimal, Numeric] Current price of underlying
      # @param atm_threshold [BigDecimal] Percentage threshold for ATM classification
      # @return [String, nil] "ITM", "ATM", "OTM", or nil if price is nil
      def moneyness_classification(current_price, atm_threshold: BigDecimal("0.01"))
        return nil if current_price.nil? || @strike_price.nil?

        if atm?(current_price, threshold: atm_threshold)
          "ATM"
        elsif itm?(current_price)
          "ITM"
        else
          "OTM"
        end
      end

      # Calculates the intrinsic value of the option
      #
      # @param current_price [BigDecimal, Numeric] Current price of underlying
      # @return [BigDecimal] Intrinsic value (always >= 0)
      def calculate_intrinsic_value(current_price)
        return BigDecimal("0") if current_price.nil? || @strike_price.nil?

        if call?
          [current_price - @strike_price, BigDecimal("0")].max
        else
          [@strike_price - current_price, BigDecimal("0")].max
        end
      end

      # Calculates the extrinsic (time) value of the option
      #
      # @param current_price [BigDecimal, Numeric] Current price of underlying
      # @return [BigDecimal, nil] Extrinsic value or nil if mark price is unavailable
      def calculate_extrinsic_value(current_price)
        return nil if @mark.nil? || current_price.nil?

        intrinsic = calculate_intrinsic_value(current_price)
        @mark - intrinsic
      end

      # Returns a human-readable display format for the option symbol
      #
      # @return [String] Formatted option symbol (e.g., "SPY 03/15/24 C 450.0")
      #
      # @example
      #   option.display_symbol  # => "SPY 03/15/24 C 450.0"
      def display_symbol
        return @symbol if @expiration_date.nil? || @strike_price.nil?

        exp_str = @expiration_date.strftime("%m/%d/%y")
        type_char = call? ? "C" : "P"
        strike_str = @strike_price.to_s("F")

        "#{@root_symbol} #{exp_str} #{type_char} #{strike_str}"
      end

      private

      def parse_attributes
        @symbol = @data["symbol"]
        @root_symbol = @data["root-symbol"] || @data["root_symbol"]
        @underlying_symbol = @data["underlying-symbol"] || @data["underlying_symbol"]
        @streamer_symbol = @data["streamer-symbol"] || @data["streamer_symbol"]

        @option_type = @data["option-type"] || @data["option_type"]
        @expiration_date = parse_date(@data["expiration-date"] || @data["expiration_date"])
        @strike_price = parse_financial_value(@data["strike-price"] || @data["strike_price"])
        @contract_size = @data["contract-size"] || @data["contract_size"] || 100
        @exercise_style = @data["exercise-style"] || @data["exercise_style"]
        @expiration_type = @data["expiration-type"] || @data["expiration_type"]
        @settlement_type = @data["settlement-type"] || @data["settlement_type"]

        @active = @data["active"]
        @days_to_expiration = @data["days-to-expiration"] || @data["days_to_expiration"]
        @stops_trading_at = parse_time(@data["stops-trading-at"] || @data["stops_trading_at"])
        @expires_at = parse_time(@data["expires-at"] || @data["expires_at"])
        @option_chain_type = @data["option-chain-type"] || @data["option_chain_type"]
        @shares_per_contract = @data["shares-per-contract"] || @data["shares_per_contract"] || 100

        parse_greeks
        parse_pricing
      end

      def parse_greeks
        @delta = parse_financial_value(@data["delta"])
        @gamma = parse_financial_value(@data["gamma"])
        @theta = parse_financial_value(@data["theta"])
        @vega = parse_financial_value(@data["vega"])
        @rho = parse_financial_value(@data["rho"])
        @implied_volatility = parse_financial_value(@data["implied-volatility"] || @data["implied_volatility"])
      end

      def parse_pricing
        @bid = parse_financial_value(@data["bid"])
        @ask = parse_financial_value(@data["ask"])
        @last = parse_financial_value(@data["last"])
        @mark = parse_financial_value(@data["mark"])
        @bid_size = @data["bid-size"] || @data["bid_size"]
        @ask_size = @data["ask-size"] || @data["ask_size"]
        @last_size = @data["last-size"] || @data["last_size"]

        @high_price = parse_financial_value(@data["high-price"] || @data["high_price"])
        @low_price = parse_financial_value(@data["low-price"] || @data["low_price"])
        @open_price = parse_financial_value(@data["open-price"] || @data["open_price"])
        @close_price = parse_financial_value(@data["close-price"] || @data["close_price"])

        @volume = @data["volume"]
        @open_interest = @data["open-interest"] || @data["open_interest"]
        @intrinsic_value = parse_financial_value(@data["intrinsic-value"] || @data["intrinsic_value"])
        @extrinsic_value = parse_financial_value(@data["extrinsic-value"] || @data["extrinsic_value"])
      end

      def parse_financial_value(value)
        return nil if value.nil? || value.to_s.empty?

        BigDecimal(value.to_s)
      end

      def parse_date(value)
        return nil if value.nil? || value.to_s.empty?

        Date.parse(value.to_s)
      end

      def set_streamer_symbol
        @streamer_symbol = self.class.occ_to_streamer_symbol(@symbol)
      end

      # Alias for days_to_expiration for convenience
      alias_method :dte, :days_to_expiration

      # Convert option to hash for JSON serialization
      def to_h
        {
          symbol: symbol,
          display_symbol: display_symbol,
          underlying_symbol: underlying_symbol,
          option_type: option_type,
          strike_price: strike_price,
          expiration_date: expiration_date,
          days_to_expiration: days_to_expiration,
          bid: bid,
          ask: ask,
          delta: delta,
          gamma: gamma,
          theta: theta,
          vega: vega,
          rho: rho,
          implied_volatility: implied_volatility,
          volume: volume,
          open_interest: open_interest
        }.compact
      end
    end
  end
end
