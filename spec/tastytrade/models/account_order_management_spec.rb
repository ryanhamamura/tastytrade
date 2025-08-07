# frozen_string_literal: true

require "spec_helper"

RSpec.describe Tastytrade::Models::Account, "#get_live_orders" do
  let(:session) { instance_double(Tastytrade::Session) }
  let(:account) { described_class.new({ "account-number" => "5WV12345" }) }

  let(:live_orders_response) do
    {
      "data" => {
        "items" => [
          {
            "id" => "12345",
            "account-number" => "5WV12345",
            "status" => "Live",
            "cancellable" => true,
            "editable" => true,
            "time-in-force" => "Day",
            "order-type" => "Limit",
            "price" => "150.50",
            "underlying-symbol" => "AAPL",
            "legs" => [
              {
                "symbol" => "AAPL",
                "action" => "Buy",
                "quantity" => 100,
                "remaining-quantity" => 100
              }
            ]
          },
          {
            "id" => "12346",
            "account-number" => "5WV12345",
            "status" => "Filled",
            "cancellable" => false,
            "editable" => false,
            "time-in-force" => "Day",
            "order-type" => "Market",
            "underlying-symbol" => "TSLA",
            "filled-at" => "2024-01-15T09:35:00.000Z",
            "legs" => [
              {
                "symbol" => "TSLA",
                "action" => "Sell",
                "quantity" => 50,
                "remaining-quantity" => 0
              }
            ]
          }
        ]
      }
    }
  end

  describe "without filters" do
    it "retrieves all live orders", :vcr do
      allow(session).to receive(:get)
        .with("/accounts/5WV12345/orders/live/", {})
        .and_return(live_orders_response)

      orders = account.get_live_orders(session)

      expect(orders).to be_an(Array)
      expect(orders.size).to eq(2)
      expect(orders.first).to be_a(Tastytrade::Models::LiveOrder)
      expect(orders.first.id).to eq("12345")
      expect(orders.first.status).to eq("Live")
      expect(orders.last.status).to eq("Filled")
    end
  end

  describe "with status filter" do
    it "includes status in request params" do
      expect(session).to receive(:get)
        .with("/accounts/5WV12345/orders/live/", { "status" => "Live" })
        .and_return({ "data" => { "items" => [] } })

      account.get_live_orders(session, status: "Live")
    end

    it "ignores invalid status values" do
      expect(session).to receive(:get)
        .with("/accounts/5WV12345/orders/live/", {})
        .and_return({ "data" => { "items" => [] } })

      account.get_live_orders(session, status: "InvalidStatus")
    end
  end

  describe "with underlying symbol filter" do
    it "includes underlying symbol in request params" do
      expect(session).to receive(:get)
        .with("/accounts/5WV12345/orders/live/", { "underlying-symbol" => "AAPL" })
        .and_return({ "data" => { "items" => [] } })

      account.get_live_orders(session, underlying_symbol: "AAPL")
    end
  end

  describe "with time filters" do
    let(:from_time) { Time.parse("2024-01-15T09:00:00Z") }
    let(:to_time) { Time.parse("2024-01-15T17:00:00Z") }

    it "includes time range in request params" do
      expect(session).to receive(:get)
        .with("/accounts/5WV12345/orders/live/",
              {
                "from-time" => from_time.iso8601,
                "to-time" => to_time.iso8601
              })
        .and_return({ "data" => { "items" => [] } })

      account.get_live_orders(session, from_time: from_time, to_time: to_time)
    end
  end
end

RSpec.describe Tastytrade::Models::Account, "#cancel_order" do
  let(:session) { instance_double(Tastytrade::Session) }
  let(:account) { described_class.new({ "account-number" => "5WV12345" }) }
  let(:order_id) { "12345" }

  describe "successful cancellation" do
    it "sends DELETE request and returns nil", :vcr do
      expect(session).to receive(:delete)
        .with("/accounts/5WV12345/orders/12345/")
        .and_return(nil)

      result = account.cancel_order(session, order_id)
      expect(result).to be_nil
    end
  end

  describe "error handling" do
    context "when order is already filled" do
      it "raises OrderAlreadyFilledError" do
        error = Tastytrade::Error.new("Order already filled")
        expect(session).to receive(:delete)
          .with("/accounts/5WV12345/orders/12345/")
          .and_raise(error)

        expect do
          account.cancel_order(session, order_id)
        end.to raise_error(Tastytrade::OrderAlreadyFilledError, /already been filled/)
      end
    end

    context "when order is not cancellable" do
      it "raises OrderNotCancellableError" do
        error = Tastytrade::Error.new("Cannot cancel order in current state")
        expect(session).to receive(:delete)
          .with("/accounts/5WV12345/orders/12345/")
          .and_raise(error)

        expect do
          account.cancel_order(session, order_id)
        end.to raise_error(Tastytrade::OrderNotCancellableError, /not in a cancellable state/)
      end
    end

    context "when other error occurs" do
      it "re-raises the original error" do
        error = Tastytrade::Error.new("Network error")
        expect(session).to receive(:delete)
          .with("/accounts/5WV12345/orders/12345/")
          .and_raise(error)

        expect do
          account.cancel_order(session, order_id)
        end.to raise_error(Tastytrade::Error, "Network error")
      end
    end
  end
end

RSpec.describe Tastytrade::Models::Account, "#replace_order" do
  let(:session) { instance_double(Tastytrade::Session) }
  let(:account) { described_class.new({ "account-number" => "5WV12345" }) }
  let(:order_id) { "12345" }
  let(:new_order) { instance_double(Tastytrade::Order) }
  let(:order_params) do
    {
      "time-in-force" => "Day",
      "order-type" => "Limit",
      "price" => "155.00",
      "legs" => [
        {
          "action" => "Buy",
          "symbol" => "AAPL",
          "quantity" => 50
        }
      ]
    }
  end

  let(:replace_response) do
    {
      "data" => {
        "id" => "12347",
        "account-number" => "5WV12345",
        "status" => "Received",
        "cancellable" => true,
        "editable" => true,
        "time-in-force" => "Day",
        "order-type" => "Limit",
        "price" => "155.00"
      }
    }
  end

  describe "successful replacement" do
    it "sends PUT request and returns OrderResponse", :vcr do
      expect(new_order).to receive(:to_api_params).and_return(order_params)
      expect(session).to receive(:put)
        .with("/accounts/5WV12345/orders/12345/", order_params)
        .and_return(replace_response)

      result = account.replace_order(session, order_id, new_order)

      expect(result).to be_a(Tastytrade::Models::OrderResponse)
      expect(result.order_id).to eq("12347")
      expect(result.status).to eq("Received")
    end
  end

  describe "error handling" do
    before do
      allow(new_order).to receive(:to_api_params).and_return(order_params)
    end

    context "when order is not editable" do
      it "raises OrderNotEditableError" do
        error = Tastytrade::Error.new("Order not editable in current state")
        expect(session).to receive(:put)
          .with("/accounts/5WV12345/orders/12345/", order_params)
          .and_raise(error)

        expect do
          account.replace_order(session, order_id, new_order)
        end.to raise_error(Tastytrade::OrderNotEditableError, /not in an editable state/)
      end
    end

    context "when quantity exceeds remaining" do
      it "raises InsufficientQuantityError" do
        error = Tastytrade::Error.new("Quantity exceeds remaining amount")
        expect(session).to receive(:put)
          .with("/accounts/5WV12345/orders/12345/", order_params)
          .and_raise(error)

        expect do
          account.replace_order(session, order_id, new_order)
        end.to raise_error(Tastytrade::InsufficientQuantityError, /exceeding remaining amount/)
      end
    end

    context "when other error occurs" do
      it "re-raises the original error" do
        error = Tastytrade::Error.new("Server error")
        expect(session).to receive(:put)
          .with("/accounts/5WV12345/orders/12345/", order_params)
          .and_raise(error)

        expect do
          account.replace_order(session, order_id, new_order)
        end.to raise_error(Tastytrade::Error, "Server error")
      end
    end
  end
end
