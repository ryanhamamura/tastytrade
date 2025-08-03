# frozen_string_literal: true

require "date"
require "time"
require "bigdecimal"

module Tastytrade
  module Models
    # Represents a transaction in a Tastytrade account
    class Transaction < Base
      attr_reader :id, :account_number, :symbol, :instrument_type, :underlying_symbol,
                  :transaction_type, :transaction_sub_type, :description, :action,
                  :quantity, :price, :executed_at, :transaction_date, :value,
                  :value_effect, :net_value, :net_value_effect, :is_estimated_fee,
                  :commission, :clearing_fees, :regulatory_fees, :proprietary_index_option_fees,
                  :order_id, :value_date, :reverses_id, :is_verified

      TRANSACTION_TYPES = %w[
        ACAT Assignment Balance\ Adjustment Cash\ Disbursement Cash\ Merger
        Cash\ Settled\ Assignment Cash\ Settled\ Exercise Credit\ Interest
        Debit\ Interest Deposit Dividend Exercise Expiration Fee Forward\ Split
        Futures\ Settlement Journal\ Entry Mark\ to\ Market Maturity
        Merger\ Acquisition Money\ Movement Name\ Change
        Paid\ Premium\ Lending\ Income Receive\ Deliver Reverse\ Split
        Special\ Dividend Stock\ Dividend Stock\ Loan\ Income Stock\ Merger
        Symbol\ Change Transfer Withdrawal
      ].freeze

      INSTRUMENT_TYPES = %w[
        Bond Cryptocurrency Equity Equity\ Offering Equity\ Option Future
        Future\ Option Index Unknown Warrant
      ].freeze

      # Fetch transaction history for an account
      # @param session [Tastytrade::Session] Active session
      # @param account_number [String] Account number
      # @param options [Hash] Optional filters
      # @option options [Date, String] :start_date Start date for transactions
      # @option options [Date, String] :end_date End date for transactions
      # @option options [String] :symbol Filter by symbol
      # @option options [String] :underlying_symbol Filter by underlying symbol
      # @option options [String] :instrument_type Filter by instrument type
      # @option options [Array<String>] :transaction_types Filter by transaction types
      # @option options [Integer] :per_page Number of results per page (default: 250)
      # @option options [Integer] :page_offset Page offset for pagination
      # @return [Array<Transaction>] Array of transactions
      def self.get_all(session, account_number, **options)
        params = build_params(options)
        transactions = []
        page_offset = options[:page_offset] || 0

        loop do
          current_params = params.dup
          current_params["page-offset"] = page_offset unless page_offset.zero?
          response = session.get("/accounts/#{account_number}/transactions", current_params)

          items = response.dig("data", "items") || []
          break if items.empty?

          transactions.concat(items.map { |item| new(item) })

          # Break if we've reached the requested limit or if pagination is manual
          break if options[:page_offset] || transactions.size >= (options[:per_page] || 250)

          page_offset += 1
        end

        transactions
      end

      private

      def parse_attributes
        parse_data(@data)
      end

      def self.build_params(options)
        {}.tap do |params|
          params["start-date"] = format_date(options[:start_date]) if options[:start_date]
          params["end-date"] = format_date(options[:end_date]) if options[:end_date]
          params["symbol"] = options[:symbol] if options[:symbol]
          params["underlying-symbol"] = options[:underlying_symbol] if options[:underlying_symbol]
          params["instrument-type"] = options[:instrument_type] if options[:instrument_type]
          params["type[]"] = Array(options[:transaction_types]) if options[:transaction_types]
          params["per-page"] = options[:per_page] if options[:per_page]
        end
      end

      def self.format_date(date)
        case date
        when String
          date
        when Date, DateTime, Time
          date.strftime("%Y-%m-%d")
        else
          date.to_s
        end
      end

      def parse_data(data)
        @id = data["id"]
        @account_number = data["account-number"]
        @symbol = data["symbol"]
        @instrument_type = data["instrument-type"]
        @underlying_symbol = data["underlying-symbol"]
        @transaction_type = data["transaction-type"]
        @transaction_sub_type = data["transaction-sub-type"]
        @description = data["description"]
        @action = data["action"]
        @quantity = parse_decimal(data["quantity"])
        @price = parse_decimal(data["price"])
        @executed_at = parse_datetime(data["executed-at"])
        @transaction_date = parse_date(data["transaction-date"])
        @value = parse_decimal(data["value"])
        @value_effect = data["value-effect"]
        @net_value = parse_decimal(data["net-value"])
        @net_value_effect = data["net-value-effect"]
        @is_estimated_fee = data["is-estimated-fee"]
        @commission = parse_decimal(data["commission"])
        @clearing_fees = parse_decimal(data["clearing-fees"])
        @regulatory_fees = parse_decimal(data["regulatory-fees"])
        @proprietary_index_option_fees = parse_decimal(data["proprietary-index-option-fees"])
        @order_id = data["order-id"]
        @value_date = parse_date(data["value-date"])
        @reverses_id = data["reverses-id"]
        @is_verified = data["is-verified"]
      end

      def parse_decimal(value)
        return nil if value.nil? || value.to_s.empty?
        BigDecimal(value.to_s)
      rescue ArgumentError
        nil
      end

      def parse_datetime(value)
        return nil if value.nil? || value.to_s.empty?
        Time.parse(value.to_s)
      rescue ArgumentError
        nil
      end

      def parse_date(value)
        return nil if value.nil? || value.to_s.empty?
        Date.parse(value.to_s)
      rescue ArgumentError
        nil
      end
    end
  end
end
