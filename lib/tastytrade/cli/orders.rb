# frozen_string_literal: true

require "thor"
require "tty-table"
require "tty-prompt"
require "time"

module Tastytrade
  class CLI < Thor
    # Thor subcommand for order management
    class Orders < Thor
      include Tastytrade::CLIHelpers

      desc "list", "List live orders (open and orders from last 24 hours)"
      option :status, type: :string, desc: "Filter by status (Live, Filled, Cancelled, etc.)"
      option :symbol, type: :string, desc: "Filter by underlying symbol"
      option :all, type: :boolean, default: false, desc: "Show orders for all accounts"
      def list
        require_authentication!

        accounts = if options[:all]
          Tastytrade::Models::Account.get_all(current_session)
        else
          [current_account || select_account_interactively]
        end

        return unless accounts.all?

        all_orders = []
        accounts.each do |account|
          next if account.closed?

          info "Fetching orders for account #{account.account_number}..." if options[:all]
          orders = account.get_live_orders(
            current_session,
            status: options[:status],
            underlying_symbol: options[:symbol]
          )
          all_orders.concat(orders.map { |order| [account, order] })
        end

        if all_orders.empty?
          info "No orders found"
          return
        end

        # Sort by created_at desc (most recent first)
        all_orders.sort! { |a, b| (b[1].created_at || Time.now) <=> (a[1].created_at || Time.now) }

        # Fetch market data for unique symbols
        unique_symbols = all_orders.map { |_, order| order.underlying_symbol }.uniq.compact
        market_data = fetch_market_data(unique_symbols) if unique_symbols.any?

        display_orders(all_orders, market_data, show_account: options[:all])
      end

      desc "cancel ORDER_ID", "Cancel an order"
      option :account, type: :string, desc: "Account number (uses default if not specified)"
      def cancel(order_id)
        require_authentication!

        account = if options[:account]
          Tastytrade::Models::Account.get(current_session, options[:account])
        else
          current_account || select_account_interactively
        end

        return unless account

        # First, fetch the order to display it
        orders = account.get_live_orders(current_session)
        order = orders.find { |o| o.id == order_id }

        unless order
          error "Order #{order_id} not found"
          exit 1
        end

        unless order.cancellable?
          error "Order #{order_id} is not cancellable (status: #{order.status})"
          exit 1
        end

        # Display order details
        puts ""
        puts "Order to cancel:"
        puts "  Order ID: #{order.id}"
        puts "  Symbol: #{order.underlying_symbol}"
        puts "  Type: #{order.order_type}"
        puts "  Status: #{order.status}"
        puts "  Price: #{format_currency(order.price)}" if order.price

        if order.legs.any?
          leg = order.legs.first
          puts "  Action: #{leg.action} #{leg.quantity} shares"
          if leg.partially_filled?
            puts "  Filled: #{leg.filled_quantity} of #{leg.quantity} shares"
          end
        end

        puts ""
        unless prompt.yes?("Are you sure you want to cancel this order?")
          info "Cancellation aborted"
          return
        end

        info "Cancelling order #{order_id}..."

        begin
          account.cancel_order(current_session, order_id)
          success "Order #{order_id} cancelled successfully"
        rescue Tastytrade::OrderAlreadyFilledError => e
          error "Cannot cancel: #{e.message}"
          exit 1
        rescue Tastytrade::OrderNotCancellableError => e
          error "Cannot cancel: #{e.message}"
          exit 1
        rescue Tastytrade::Error => e
          error "Failed to cancel order: #{e.message}"
          exit 1
        end
      end

      desc "replace ORDER_ID", "Replace/modify an existing order"
      option :account, type: :string, desc: "Account number (uses default if not specified)"
      option :price, type: :numeric, desc: "New price for the order"
      option :quantity, type: :numeric, desc: "New quantity (cannot exceed remaining)"
      def replace(order_id)
        require_authentication!

        account = if options[:account]
          Tastytrade::Models::Account.get(current_session, options[:account])
        else
          current_account || select_account_interactively
        end

        return unless account

        # Fetch the order to modify
        orders = account.get_live_orders(current_session)
        order = orders.find { |o| o.id == order_id }

        unless order
          error "Order #{order_id} not found"
          exit 1
        end

        unless order.editable?
          error "Order #{order_id} is not editable (status: #{order.status})"
          exit 1
        end

        # Display current order details
        puts ""
        puts "Current order:"
        puts "  Order ID: #{order.id}"
        puts "  Symbol: #{order.underlying_symbol}"
        puts "  Type: #{order.order_type}"
        puts "  Status: #{order.status}"
        puts "  Current Price: #{format_currency(order.price)}" if order.price

        leg = order.legs.first if order.legs.any?
        if leg
          puts "  Action: #{leg.action} #{leg.quantity} shares"
          puts "  Remaining: #{leg.remaining_quantity} shares"
          if leg.partially_filled?
            puts "  Filled: #{leg.filled_quantity} shares"
          end
        end

        # Interactive prompts for new values if not provided
        new_price = if options[:price]
          BigDecimal(options[:price].to_s)
        elsif order.order_type == "Limit"
          puts ""
          current_price_str = order.price ? order.price.to_s("F") : "N/A"
          price_input = prompt.ask("New price (current: #{current_price_str}):",
                                    default: current_price_str,
                                    convert: :float)
          BigDecimal(price_input.to_s) if price_input
        else
          order.price
        end

        new_quantity = if options[:quantity]
          options[:quantity].to_i
        elsif leg
          puts ""
          max_qty = leg.remaining_quantity
          quantity_input = prompt.ask("New quantity (current: #{max_qty}, max: #{max_qty}):",
                                       default: max_qty,
                                       convert: :int) do |q|
            q.in("1-#{leg.remaining_quantity}")
            q.messages[:range?] = "Quantity must be between 1 and #{leg.remaining_quantity}"
          end
          quantity_input
        else
          nil
        end

        # Show summary of changes
        puts ""
        puts "Order modifications:"
        if new_price && order.price != new_price
          puts "  Price: #{format_currency(order.price)} → #{format_currency(new_price)}"
        end
        if new_quantity && leg && leg.remaining_quantity != new_quantity
          puts "  Quantity: #{leg.remaining_quantity} → #{new_quantity}"
        end

        puts ""
        unless prompt.yes?("Proceed with these changes?")
          info "Replacement cancelled"
          return
        end

        # Create new order with modifications
        begin
          # Recreate the order with new parameters
          action = if leg
            case leg.action.downcase
            when "buy", "buy to open"
              Tastytrade::OrderAction::BUY_TO_OPEN
            when "sell", "sell to close"
              Tastytrade::OrderAction::SELL_TO_CLOSE
            else
              leg.action
            end
          end

          new_leg = Tastytrade::OrderLeg.new(
            action: action,
            symbol: leg.symbol,
            quantity: new_quantity || leg.remaining_quantity
          )

          order_type = case order.order_type.downcase
                       when "market"
                         Tastytrade::OrderType::MARKET
                       when "limit"
                         Tastytrade::OrderType::LIMIT
                       else
                         order.order_type
          end

          new_order = Tastytrade::Order.new(
            type: order_type,
            legs: new_leg,
            price: new_price
          )

          info "Replacing order #{order_id}..."
          response = account.replace_order(current_session, order_id, new_order)

          success "Order replaced successfully!"
          puts ""
          puts "New Order Details:"
          puts "  Order ID: #{response.order_id}"
          puts "  Status: #{response.status}"
          puts "  Price: #{format_currency(new_price)}" if new_price

        rescue Tastytrade::OrderNotEditableError => e
          error "Cannot replace: #{e.message}"
          exit 1
        rescue Tastytrade::InsufficientQuantityError => e
          error "Cannot replace: #{e.message}"
          exit 1
        rescue Tastytrade::Error => e
          error "Failed to replace order: #{e.message}"
          exit 1
        end
      end

      private

      def display_orders(orders_with_accounts, market_data, show_account: false)
        headers = ["Order ID", "Symbol", "Action", "Qty", "Filled", "Type", "Price", "Status", "Time"]
        headers.unshift("Account") if show_account

        rows = orders_with_accounts.map do |account, order|
          leg = order.legs.first if order.legs.any?

          row = [
            order.id,
            order.underlying_symbol || "N/A",
            leg ? leg.action : "N/A",
            leg ? leg.quantity.to_s : "N/A",
            leg ? "#{leg.filled_quantity}/#{leg.quantity}" : "N/A",
            order.order_type || "N/A",
            order.price ? format_currency(order.price) : "N/A",
            colorize_status(order.status),
            format_time(order.created_at)
          ]

          row.unshift(account.account_number) if show_account
          row
        end

        table = TTY::Table.new(headers, rows)
        puts table.render(:unicode, padding: [0, 1], alignments: [:left])

        # Show market data if available
        if market_data && !market_data.empty?
          puts ""
          puts "Current Market Prices:"
          market_data.each do |symbol, data|
            if data
              bid = format_currency(data[:bid])
              ask = format_currency(data[:ask])
              last = format_currency(data[:last])
              puts "  #{symbol}: Bid: #{bid} | Ask: #{ask} | Last: #{last}"
            end
          end
        end
      end

      def fetch_market_data(symbols)
        return {} if symbols.empty?

        market_data = {}
        symbols.each do |symbol|
          begin
            equity = Tastytrade::Instruments::Equity.get_equity(current_session, symbol)
            if equity
              # Fetch quote data for the equity
              # This is a placeholder - actual implementation would fetch real-time quotes
              market_data[symbol] = {
                bid: nil,  # Would fetch from market data API
                ask: nil,  # Would fetch from market data API
                last: nil  # Would fetch from market data API
              }
            end
          rescue Tastytrade::Error
            # Silently skip if we can't fetch market data
          end
        end
        market_data
      end

      def colorize_status(status)
        case status
        when "Live"
          pastel.green(status)
        when "Filled"
          pastel.blue(status)
        when "Cancelled", "Rejected", "Expired"
          pastel.red(status)
        when "Received", "Routed"
          pastel.yellow(status)
        else
          status
        end
      end

      def format_time(time)
        return "N/A" unless time
        time.strftime("%m/%d %H:%M")
      end

      def format_currency(amount)
        return "N/A" unless amount
        "$#{amount.to_s("F")}"
      end

      def current_session
        @current_session ||= begin
          # Try to get session from parent CLI instance
          if defined?(parent_options) && parent_options
            parent_options[:current_session]
          else
            SessionManager.load_session
          end
        end
      end

      def current_account
        @current_account ||= begin
          if current_session
            accounts = Tastytrade::Models::Account.get_all(current_session)
            accounts.reject(&:closed?).first
          end
        end
      end

      def select_account_interactively
        accounts = Tastytrade::Models::Account.get_all(current_session)
        active_accounts = accounts.reject(&:closed?)

        if active_accounts.empty?
          error "No active accounts found"
          nil
        elsif active_accounts.size == 1
          active_accounts.first
        else
          choices = active_accounts.map do |acc|
            {
              name: "#{acc.account_number} - #{acc.nickname || acc.account_type_name}",
              value: acc
            }
          end
          prompt.select("Select an account:", choices)
        end
      end

      def require_authentication!
        unless current_session
          error "You must be logged in to use this command"
          error "Run: tastytrade login"
          exit 1
        end
      end

      def prompt
        @prompt ||= TTY::Prompt.new
      end

      def pastel
        @pastel ||= Pastel.new
      end
    end
  end
end
