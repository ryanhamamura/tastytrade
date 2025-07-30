# frozen_string_literal: true

module Tastytrade
  module Models
    # Represents a Tastytrade account
    class Account < Base
      attr_reader :account_number, :nickname, :account_type_name,
                  :opened_at, :is_closed, :day_trader_status,
                  :is_futures_approved, :margin_or_cash, :is_foreign,
                  :created_at, :external_id, :closed_at, :funding_date,
                  :investment_objective, :suitable_options_level,
                  :is_test_drive

      class << self
        # Get all accounts for the authenticated user
        #
        # @param session [Tastytrade::Session] Active session
        # @param include_closed [Boolean] Include closed accounts
        # @return [Array<Account>] List of accounts
        def get_all(session, include_closed: false)
          params = include_closed ? { "include-closed" => true } : {}
          response = session.get("/customers/me/accounts/", params)
          response["data"]["items"].map { |item| new(item) }
        end

        # Get a specific account by account number
        #
        # @param session [Tastytrade::Session] Active session
        # @param account_number [String] Account number
        # @return [Account] Account instance
        def get(session, account_number)
          response = session.get("/accounts/#{account_number}/")
          new(response["data"])
        end
      end

      # Get account balances
      #
      # @param session [Tastytrade::Session] Active session
      # @return [Hash] Account balance data
      def get_balances(session)
        session.get("/accounts/#{account_number}/balances/")["data"]
      end

      # Get current positions
      #
      # @param session [Tastytrade::Session] Active session
      # @return [Array<Hash>] Position data
      def get_positions(session)
        response = session.get("/accounts/#{account_number}/positions/")
        response["data"]["items"]
      end

      # Get trading status
      #
      # @param session [Tastytrade::Session] Active session
      # @return [Hash] Trading status data
      def get_trading_status(session)
        session.get("/accounts/#{account_number}/trading-status/")["data"]
      end

      def closed?
        @is_closed == true
      end

      def futures_approved?
        @is_futures_approved == true
      end

      def test_drive?
        @is_test_drive == true
      end

      def foreign?
        @is_foreign == true
      end

      private

      def parse_attributes
        parse_basic_attributes
        parse_status_attributes
        parse_optional_attributes
      end

      def parse_basic_attributes
        @account_number = @data["account-number"]
        @nickname = @data["nickname"]
        @account_type_name = @data["account-type-name"]
        @opened_at = parse_time(@data["opened-at"])
        @margin_or_cash = @data["margin-or-cash"]
        @created_at = parse_time(@data["created-at"])
      end

      def parse_status_attributes
        @is_closed = @data["is-closed"]
        @day_trader_status = @data["day-trader-status"]
        @is_futures_approved = @data["is-futures-approved"]
        @is_foreign = @data["is-foreign"]
        @is_test_drive = @data["is-test-drive"]
      end

      def parse_optional_attributes
        @external_id = @data["external-id"]
        @closed_at = parse_time(@data["closed-at"])
        @funding_date = parse_date(@data["funding-date"])
        @investment_objective = @data["investment-objective"]
        @suitable_options_level = @data["suitable-options-level"]
      end

      def parse_date(value)
        return nil if value.nil? || value.empty?

        Date.parse(value)
      rescue ArgumentError
        nil
      end
    end
  end
end
