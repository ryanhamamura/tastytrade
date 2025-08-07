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
          response["data"]["items"].map { |item| new(item["account"]) }
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
      # @return [AccountBalance] Account balance object
      def get_balances(session)
        response = session.get("/accounts/#{account_number}/balances/")
        AccountBalance.new(response["data"])
      end

      # Get current positions
      #
      # @param session [Tastytrade::Session] Active session
      # @param symbol [String, nil] Filter by symbol
      # @param underlying_symbol [String, nil] Filter by underlying symbol
      # @param include_closed [Boolean] Include closed positions
      # @return [Array<CurrentPosition>] Position objects
      def get_positions(session, symbol: nil, underlying_symbol: nil, include_closed: false)
        params = {}
        params["symbol"] = symbol if symbol
        params["underlying-symbol"] = underlying_symbol if underlying_symbol
        params["include-closed"] = include_closed if include_closed

        response = session.get("/accounts/#{account_number}/positions/", params)
        response["data"]["items"].map { |item| CurrentPosition.new(item) }
      end

      # Get trading status
      #
      # @param session [Tastytrade::Session] Active session
      # @return [Tastytrade::Models::TradingStatus] Trading status object
      def get_trading_status(session)
        response = session.get("/accounts/#{account_number}/trading-status/")
        TradingStatus.new(response["data"])
      end

      # Place an order
      #
      # @param session [Tastytrade::Session] Active session
      # @param order [Tastytrade::Order] Order to place
      # @param dry_run [Boolean] Whether to simulate the order without placing it
      # @param skip_validation [Boolean] Skip pre-submission validation (use with caution)
      # @return [OrderResponse] Response from order placement
      # @raise [OrderValidationError] if validation fails
      def place_order(session, order, dry_run: false, skip_validation: false)
        # Validate the order unless explicitly skipped or it's a dry-run
        unless skip_validation || dry_run
          validator = OrderValidator.new(session, self, order)
          validator.validate!
        end

        endpoint = "/accounts/#{account_number}/orders"
        endpoint += "/dry-run" if dry_run

        response = session.post(endpoint, order.to_api_params)
        OrderResponse.new(response["data"])
      end

      # Get transaction history
      #
      # @param session [Tastytrade::Session] Active session
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
      def get_transactions(session, **options)
        Transaction.get_all(session, account_number, **options)
      end

      # Get live orders (open and orders from last 24 hours)
      #
      # @param session [Tastytrade::Session] Active session
      # @param status [String, nil] Filter by order status
      # @param underlying_symbol [String, nil] Filter by underlying symbol
      # @param from_time [Time, nil] Start time for order history
      # @param to_time [Time, nil] End time for order history
      # @return [Array<LiveOrder>] Array of live orders
      def get_live_orders(session, status: nil, underlying_symbol: nil, from_time: nil, to_time: nil)
        params = {}
        params["status"] = status if status && OrderStatus.valid?(status)
        params["underlying-symbol"] = underlying_symbol if underlying_symbol
        params["from-time"] = from_time.iso8601 if from_time
        params["to-time"] = to_time.iso8601 if to_time

        response = session.get("/accounts/#{account_number}/orders/live/", params)
        response["data"]["items"].map { |item| LiveOrder.new(item) }
      end

      # Get order history for this account (beyond 24 hours)
      #
      # @param session [Tastytrade::Session] Active session
      # @param status [String, nil] Filter by order status
      # @param underlying_symbol [String, nil] Filter by underlying symbol
      # @param from_time [Time, nil] Start time for order history
      # @param to_time [Time, nil] End time for order history
      # @param page_offset [Integer, nil] Pagination offset
      # @param page_limit [Integer, nil] Number of results per page (default 250, max 1000)
      # @return [Array<LiveOrder>] Array of historical orders
      def get_order_history(session, status: nil, underlying_symbol: nil, from_time: nil, to_time: nil,
                           page_offset: nil, page_limit: nil)
        params = {}
        params["status"] = status if status && OrderStatus.valid?(status)
        params["underlying-symbol"] = underlying_symbol if underlying_symbol
        params["from-time"] = from_time.iso8601 if from_time
        params["to-time"] = to_time.iso8601 if to_time
        params["page-offset"] = page_offset if page_offset
        params["page-limit"] = page_limit if page_limit

        response = session.get("/accounts/#{account_number}/orders/", params)
        response["data"]["items"].map { |item| LiveOrder.new(item) }
      end

      # Get a specific order by ID
      #
      # @param session [Tastytrade::Session] Active session
      # @param order_id [String] Order ID to retrieve
      # @return [LiveOrder] The requested order
      def get_order(session, order_id)
        response = session.get("/accounts/#{account_number}/orders/#{order_id}/")
        LiveOrder.new(response["data"])
      end

      # Cancel an order
      #
      # @param session [Tastytrade::Session] Active session
      # @param order_id [String] Order ID to cancel
      # @return [void]
      # @raise [OrderNotCancellableError] if order cannot be cancelled
      # @raise [OrderAlreadyFilledError] if order has already been filled
      def cancel_order(session, order_id)
        session.delete("/accounts/#{account_number}/orders/#{order_id}/")
        nil
      rescue Tastytrade::Error => e
        handle_cancel_error(e)
      end

      # Replace an existing order
      #
      # @param session [Tastytrade::Session] Active session
      # @param order_id [String] Order ID to replace
      # @param new_order [Tastytrade::Order] New order to replace with
      # @return [OrderResponse] Response from order replacement
      # @raise [OrderNotEditableError] if order cannot be edited
      # @raise [InsufficientQuantityError] if trying to replace more than remaining quantity
      def replace_order(session, order_id, new_order)
        response = session.put("/accounts/#{account_number}/orders/#{order_id}/",
                                new_order.to_api_params)
        OrderResponse.new(response["data"])
      rescue Tastytrade::Error => e
        handle_replace_error(e)
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

      def handle_cancel_error(error)
        if error.message.include?("already filled") || error.message.include?("Filled")
          raise OrderAlreadyFilledError, "Order has already been filled and cannot be cancelled"
        elsif error.message.include?("not cancellable") || error.message.include?("Cannot cancel")
          raise OrderNotCancellableError, "Order is not in a cancellable state"
        else
          raise error
        end
      end

      def handle_replace_error(error)
        if error.message.include?("not editable") || error.message.include?("Cannot edit")
          raise OrderNotEditableError, "Order is not in an editable state"
        elsif error.message.include?("insufficient quantity") || error.message.include?("exceeds remaining")
          raise InsufficientQuantityError, "Cannot replace order with quantity exceeding remaining amount"
        else
          raise error
        end
      end

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
