# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Order Management Integration", :vcr, integration: true do
  let(:username) { ENV["TASTYTRADE_USERNAME"] || "test_user" }
  let(:password) { ENV["TASTYTRADE_PASSWORD"] || "test_pass" }
  let(:session) do
    s = Tastytrade::Session.new(username: username, password: password, is_test: true)
    s.login
    s
  end
  let(:account) do
    accounts = Tastytrade::Models::Account.get_all(session)
    accounts.reject(&:closed?).first
  end

  describe "Order Lifecycle" do
    context "during market hours", market_hours: true do
      it "can place, list, modify, and cancel an order" do
        skip "This test requires market hours and a funded sandbox account"

        # Step 1: Place a limit order
        symbol = "SPY"
        quantity = 1

        # Get current market price
        equity = Tastytrade::Instruments::Equity.get_equity(session, symbol)
        expect(equity).not_to be_nil

        # Set limit price well below market to avoid execution
        limit_price = BigDecimal("100.00")

        leg = Tastytrade::OrderLeg.new(
          action: Tastytrade::OrderAction::BUY_TO_OPEN,
          symbol: symbol,
          quantity: quantity
        )

        order = Tastytrade::Order.new(
          type: Tastytrade::OrderType::LIMIT,
          legs: leg,
          price: limit_price
        )

        # Place the order
        response = account.place_order(session, order, dry_run: false)
        expect(response).to be_a(Tastytrade::Models::OrderResponse)
        expect(response.order_id).not_to be_nil
        order_id = response.order_id

        # Step 2: List orders and verify our order is there
        live_orders = account.get_live_orders(session)
        our_order = live_orders.find { |o| o.id == order_id }
        expect(our_order).not_to be_nil
        expect(our_order.status).to eq("Live")
        expect(our_order.cancellable?).to be true
        expect(our_order.editable?).to be true

        # Step 3: Replace the order with a new price
        new_limit_price = BigDecimal("101.00")
        new_order = Tastytrade::Order.new(
          type: Tastytrade::OrderType::LIMIT,
          legs: leg,
          price: new_limit_price
        )

        replace_response = account.replace_order(session, order_id, new_order)
        expect(replace_response).to be_a(Tastytrade::Models::OrderResponse)
        new_order_id = replace_response.order_id

        # Verify the replacement
        sleep 1 # Allow time for order to be processed
        updated_orders = account.get_live_orders(session)
        replaced_order = updated_orders.find { |o| o.id == new_order_id }
        expect(replaced_order).not_to be_nil
        expect(replaced_order.price).to eq(new_limit_price)

        # Step 4: Cancel the order
        account.cancel_order(session, new_order_id)

        # Verify cancellation
        sleep 1 # Allow time for cancellation to be processed
        final_orders = account.get_live_orders(session)
        cancelled_order = final_orders.find { |o| o.id == new_order_id }

        if cancelled_order
          expect(cancelled_order.status).to eq("Cancelled")
        end
      end
    end

    context "outside market hours" do
      it "handles order placement errors gracefully" do
        skip "This test is for documentation purposes"

        # Attempting to place a market order outside market hours should fail
        leg = Tastytrade::OrderLeg.new(
          action: Tastytrade::OrderAction::BUY_TO_OPEN,
          symbol: "AAPL",
          quantity: 1
        )

        order = Tastytrade::Order.new(
          type: Tastytrade::OrderType::MARKET,
          legs: leg
        )

        expect do
          account.place_order(session, order, dry_run: false)
        end.to raise_error(Tastytrade::MarketClosedError)
      end
    end
  end

  describe "Order Status Filtering" do
    it "can filter orders by status" do
      skip "Requires existing orders in the account"

      # Get all orders
      all_orders = account.get_live_orders(session)

      # Filter by Live status
      live_orders = account.get_live_orders(session, status: "Live")
      live_orders.each do |order|
        expect(order.status).to eq("Live")
      end

      # Filter by Filled status
      filled_orders = account.get_live_orders(session, status: "Filled")
      filled_orders.each do |order|
        expect(order.status).to eq("Filled")
      end
    end

    it "can filter orders by symbol" do
      skip "Requires existing orders in the account"

      symbol = "SPY"
      filtered_orders = account.get_live_orders(session, underlying_symbol: symbol)

      filtered_orders.each do |order|
        expect(order.underlying_symbol).to eq(symbol)
      end
    end
  end

  describe "Partial Fill Handling" do
    it "correctly calculates filled and remaining quantities" do
      skip "Requires a partially filled order"

      orders = account.get_live_orders(session)
      partially_filled = orders.find { |o| o.legs.any?(&:partially_filled?) }

      if partially_filled
        leg = partially_filled.legs.find(&:partially_filled?)
        expect(leg.filled_quantity).to be > 0
        expect(leg.remaining_quantity).to be > 0
        expect(leg.filled_quantity + leg.remaining_quantity).to eq(leg.quantity)
      end
    end
  end

  describe "Error Handling" do
    it "raises appropriate errors for invalid operations" do
      # Try to cancel a non-existent order
      expect do
        account.cancel_order(session, "INVALID_ORDER_ID")
      end.to raise_error(Tastytrade::Error)

      # Try to replace a non-existent order
      leg = Tastytrade::OrderLeg.new(
        action: Tastytrade::OrderAction::BUY_TO_OPEN,
        symbol: "AAPL",
        quantity: 1
      )

      order = Tastytrade::Order.new(
        type: Tastytrade::OrderType::LIMIT,
        legs: leg,
        price: BigDecimal("150.00")
      )

      expect do
        account.replace_order(session, "INVALID_ORDER_ID", order)
      end.to raise_error(Tastytrade::Error)
    end
  end
end
