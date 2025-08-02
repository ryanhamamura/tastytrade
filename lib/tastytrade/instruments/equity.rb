# frozen_string_literal: true

module Tastytrade
  module Instruments
    # Represents an equity instrument
    class Equity
      attr_reader :symbol, :description, :exchange, :cusip, :active

      def initialize(data = {})
        @symbol = data["symbol"]
        @description = data["description"]
        @exchange = data["exchange"]
        @cusip = data["cusip"]
        @active = data["active"]
      end

      # Get equity information for a symbol
      #
      # @param session [Tastytrade::Session] Active session
      # @param symbol [String] Equity symbol
      # @return [Equity] Equity instrument
      def self.get(session, symbol)
        response = session.get("/instruments/equities/#{symbol}")
        new(response["data"])
      end

      # Create an order leg for this equity
      #
      # @param action [String] Order action (from OrderAction module)
      # @param quantity [Integer] Number of shares
      # @return [OrderLeg] Order leg for this equity
      def build_leg(action:, quantity:)
        OrderLeg.new(
          action: action,
          symbol: @symbol,
          quantity: quantity,
          instrument_type: "Equity"
        )
      end
    end
  end
end
