# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Tastytrade::Models::Account#place_order" do
  # Pure Ruby tests (no API calls)
  describe "order object construction (pure Ruby)" do
    let(:account) { Tastytrade::Models::Account.new("account-number" => "5WX12345") }

    let(:order_leg) do
      Tastytrade::OrderLeg.new(
        action: Tastytrade::OrderAction::BUY_TO_OPEN,
        symbol: "AAPL",
        quantity: 100
      )
    end

    let(:market_order) do
      Tastytrade::Order.new(
        type: Tastytrade::OrderType::MARKET,
        legs: order_leg
      )
    end

    let(:limit_order) do
      Tastytrade::Order.new(
        type: Tastytrade::OrderType::LIMIT,
        legs: order_leg,
        price: 150.50
      )
    end

    it "creates valid market order" do
      expect(market_order.type).to eq(Tastytrade::OrderType::MARKET)
      expect(market_order.legs).to eq(order_leg)
    end

    it "creates valid limit order" do
      expect(limit_order.type).to eq(Tastytrade::OrderType::LIMIT)
      expect(limit_order.price).to eq(150.50)
    end
  end

  # Real API tests using VCR
  describe "API order placement", :vcr do
    let(:username) { ENV.fetch("TASTYTRADE_SANDBOX_USERNAME", nil) }
    let(:password) { ENV.fetch("TASTYTRADE_SANDBOX_PASSWORD", nil) }
    let(:account_number) { ENV.fetch("TASTYTRADE_SANDBOX_ACCOUNT", nil) }
    let(:session) do
      sess = Tastytrade::Session.new(username: username, password: password, is_test: true)
      sess.login if username && password
      sess
    end
    let(:account) { Tastytrade::Models::Account.get(session, account_number) }

    before do
      skip "Missing sandbox credentials" unless username && password && account_number
    end

    describe "successful order placement" do
      it "places a limit order with cleanup" do
        with_market_hours_check("account/place_limit_order") do
          with_test_order(session, account, limit_test_order(price: 1.00)) do |order_response|
            expect(order_response).to be_a(Tastytrade::Models::OrderResponse)
            expect(order_response.order_id).not_to be_nil
            expect(order_response.status).not_to be_nil
          end
        end
      end

      it "places multiple orders with cleanup" do
        with_market_hours_check("account/place_multiple_orders") do
          with_test_orders(session, account, 2) do |orders|
            expect(orders).to be_an(Array)
            expect(orders.size).to eq(2)

            orders.each do |order|
              expect(order.order_id).not_to be_nil
              expect(order.status).not_to be_nil
            end
          end
        end
      end

      it "handles dry run orders" do
        with_market_hours_check("account/place_order_dry_run") do
          order = limit_test_order(price: 1.00)

          response = account.place_order(session, order, dry_run: true)

          expect(response).to be_a(Tastytrade::Models::OrderResponse)
          expect(response.buying_power_effect).to be_a(Tastytrade::Models::BuyingPowerEffect)
          expect(response.buying_power_effect.impact).to be_a(BigDecimal)
          # Dry run doesn't create real order, so no order_id
          expect(response.order_id).to be_nil
        end
      end
    end

    describe "order validation" do
      it "validates order before placement by default" do
        with_market_hours_check("account/place_order_with_validation") do
          # Create an order that might fail validation
          invalid_leg = Tastytrade::OrderLeg.new(
            action: Tastytrade::OrderAction::BUY_TO_OPEN,
            symbol: "INVALID_SYMBOL_12345",
            quantity: 1
          )

          invalid_order = Tastytrade::Order.new(
            type: Tastytrade::OrderType::LIMIT,
            legs: invalid_leg,
            price: 1.00
          )

          # This should raise a validation error
          expect {
            account.place_order(session, invalid_order)
          }.to raise_error(Tastytrade::OrderValidationError)
        end
      end

      it "skips validation when requested" do
        with_market_hours_check("account/place_order_skip_validation") do
          with_test_order(session, account) do |order_response|
            # Order was placed with skip_validation: true (in helper)
            expect(order_response.order_id).not_to be_nil
          end
        end
      end
    end

    describe "order cancellation" do
      it "cancels an open order" do
        with_market_hours_check("account/cancel_order") do
          # Place order
          order = limit_test_order(price: 0.01)  # Very low price to avoid fill
          order_response = account.place_order(session, order, skip_validation: true)

          expect(order_response.order_id).not_to be_nil

          # Cancel order
          result = account.cancel_order(session, order_response.order_id)
          expect(result).to be_nil  # cancel_order returns nil on success

          # Verify order is cancelled
          cancelled_order = account.get_order(session, order_response.order_id)
          expect(["CANCELLED", "CANCEL_PENDING"]).to include(cancelled_order.status.upcase)
        end
      end
    end

    describe "order replacement" do
      it "replaces an existing order" do
        with_market_hours_check("account/replace_order") do
          # Place initial order
          initial_order = limit_test_order(price: 0.01)
          initial_response = account.place_order(session, initial_order, skip_validation: true)

          expect(initial_response.order_id).not_to be_nil

          begin
            # Create replacement order with different price
            replacement_order = limit_test_order(price: 0.02)

            # Replace the order
            replace_response = account.replace_order(
              session,
              initial_response.order_id,
              replacement_order
            )

            expect(replace_response).to be_a(Tastytrade::Models::OrderResponse)
            expect(replace_response.order_id).not_to be_nil
            # New order should have different ID
            expect(replace_response.order_id).not_to eq(initial_response.order_id)
          ensure
            # Cleanup both orders if they exist
            [initial_response.order_id, replace_response&.order_id].compact.each do |order_id|
              begin
                account.cancel_order(session, order_id)
              rescue Tastytrade::Error
                # Order might already be cancelled or filled
              end
            end
          end
        end
      end
    end

    describe "order retrieval" do
      it "gets a specific order by ID" do
        with_market_hours_check("account/get_order") do
          with_test_order(session, account) do |order_response|
            fetched_order = account.get_order(session, order_response.order_id)

            expect(fetched_order).to be_a(Tastytrade::Models::LiveOrder)
            expect(fetched_order.id).to eq(order_response.order_id)
          end
        end
      end
    end

    describe "error handling" do
      it "handles insufficient funds gracefully" do
        with_market_hours_check("account/place_order_insufficient_funds") do
          # Try to place a very expensive order
          expensive_leg = Tastytrade::OrderLeg.new(
            action: Tastytrade::OrderAction::BUY_TO_OPEN,
            symbol: "SPY",
            quantity: 100000  # Very large quantity
          )

          expensive_order = Tastytrade::Order.new(
            type: Tastytrade::OrderType::MARKET,
            legs: expensive_leg
          )

          # This should fail with insufficient funds
          expect {
            account.place_order(session, expensive_order, skip_validation: true)
          }.to raise_error(Tastytrade::Error)
        end
      end
    end
  end
end
