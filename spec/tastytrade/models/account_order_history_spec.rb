# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Tastytrade::Models::Account#get_order_history" do
  let(:session) { instance_double(Tastytrade::Session) }
  let(:account_number) { "5WZ38925" }
  let(:account) { Tastytrade::Models::Account.new("account-number" => account_number) }

  let(:order_history_response) do
    {
      "data" => {
        "items" => [
          {
            "id" => "12345",
            "account-number" => account_number,
            "status" => "Filled",
            "cancellable" => false,
            "editable" => false,
            "time-in-force" => "Day",
            "order-type" => "Limit",
            "underlying-symbol" => "AAPL",
            "price" => "150.00",
            "created-at" => "2024-01-01T10:00:00Z",
            "filled-at" => "2024-01-01T10:05:00Z",
            "legs" => [
              {
                "symbol" => "AAPL",
                "instrument-type" => "Equity",
                "action" => "Buy to Open",
                "quantity" => 100,
                "remaining-quantity" => 0
              }
            ]
          },
          {
            "id" => "12346",
            "account-number" => account_number,
            "status" => "Cancelled",
            "cancellable" => false,
            "editable" => false,
            "time-in-force" => "Day",
            "order-type" => "Market",
            "underlying-symbol" => "MSFT",
            "created-at" => "2024-01-02T14:30:00Z",
            "cancelled-at" => "2024-01-02T14:35:00Z",
            "legs" => [
              {
                "symbol" => "MSFT",
                "instrument-type" => "Equity",
                "action" => "Sell to Close",
                "quantity" => 50,
                "remaining-quantity" => 50
              }
            ]
          }
        ]
      }
    }
  end

  context "without filters" do
    it "retrieves all historical orders" do
      expect(session).to receive(:get)
        .with("/accounts/#{account_number}/orders/", {})
        .and_return(order_history_response)

      orders = account.get_order_history(session)

      expect(orders).to be_an(Array)
      expect(orders.size).to eq(2)
      expect(orders.first).to be_a(Tastytrade::Models::LiveOrder)
      expect(orders.first.id).to eq("12345")
      expect(orders.first.status).to eq("Filled")
      expect(orders.last.id).to eq("12346")
      expect(orders.last.status).to eq("Cancelled")
    end
  end

  context "with status filter" do
    it "includes status in request params" do
      expect(session).to receive(:get)
        .with("/accounts/#{account_number}/orders/", { "status" => "Filled" })
        .and_return(order_history_response)

      account.get_order_history(session, status: "Filled")
    end

    it "ignores invalid status values" do
      expect(session).to receive(:get)
        .with("/accounts/#{account_number}/orders/", {})
        .and_return(order_history_response)

      account.get_order_history(session, status: "InvalidStatus")
    end
  end

  context "with underlying symbol filter" do
    it "includes underlying symbol in request params" do
      expect(session).to receive(:get)
        .with("/accounts/#{account_number}/orders/", { "underlying-symbol" => "AAPL" })
        .and_return(order_history_response)

      account.get_order_history(session, underlying_symbol: "AAPL")
    end
  end

  context "with time filters" do
    it "includes time range in request params" do
      from_time = Time.parse("2024-01-01T00:00:00Z")
      to_time = Time.parse("2024-01-31T23:59:59Z")

      expect(session).to receive(:get)
        .with("/accounts/#{account_number}/orders/", {
                "from-time" => from_time.iso8601,
                "to-time" => to_time.iso8601
              })
        .and_return(order_history_response)

      account.get_order_history(session, from_time: from_time, to_time: to_time)
    end
  end

  context "with pagination" do
    it "includes pagination parameters" do
      expect(session).to receive(:get)
        .with("/accounts/#{account_number}/orders/", {
                "page-offset" => 100,
                "page-limit" => 50
              })
        .and_return(order_history_response)

      account.get_order_history(session, page_offset: 100, page_limit: 50)
    end
  end

  context "with multiple filters" do
    it "combines all filters in request" do
      from_time = Time.parse("2024-01-01T00:00:00Z")
      to_time = Time.parse("2024-01-31T23:59:59Z")

      expect(session).to receive(:get)
        .with("/accounts/#{account_number}/orders/", {
                "status" => "Filled",
                "underlying-symbol" => "AAPL",
                "from-time" => from_time.iso8601,
                "to-time" => to_time.iso8601,
                "page-limit" => 100
              })
        .and_return(order_history_response)

      account.get_order_history(
        session,
        status: "Filled",
        underlying_symbol: "AAPL",
        from_time: from_time,
        to_time: to_time,
        page_limit: 100
      )
    end
  end
end

RSpec.describe "Tastytrade::Models::Account#get_order" do
  let(:session) { instance_double(Tastytrade::Session) }
  let(:account_number) { "5WZ38925" }
  let(:account) { Tastytrade::Models::Account.new("account-number" => account_number) }
  let(:order_id) { "12345" }

  let(:order_response) do
    {
      "data" => {
        "id" => order_id,
        "account-number" => account_number,
        "status" => "Live",
        "cancellable" => true,
        "editable" => true,
        "time-in-force" => "GTC",
        "order-type" => "Limit",
        "underlying-symbol" => "AAPL",
        "price" => "150.00",
        "created-at" => "2024-01-01T10:00:00Z",
        "legs" => [
          {
            "symbol" => "AAPL",
            "instrument-type" => "Equity",
            "action" => "Buy to Open",
            "quantity" => 100,
            "remaining-quantity" => 100
          }
        ]
      }
    }
  end

  it "retrieves a specific order by ID" do
    expect(session).to receive(:get)
      .with("/accounts/#{account_number}/orders/#{order_id}/")
      .and_return(order_response)

    order = account.get_order(session, order_id)

    expect(order).to be_a(Tastytrade::Models::LiveOrder)
    expect(order.id).to eq(order_id)
    expect(order.status).to eq("Live")
    expect(order.underlying_symbol).to eq("AAPL")
    expect(order.cancellable?).to be true
    expect(order.editable?).to be true
  end

  context "when order doesn't exist" do
    it "raises an error" do
      error_response = {
        "error" => {
          "code" => "order_not_found",
          "message" => "Order not found"
        }
      }

      expect(session).to receive(:get)
        .with("/accounts/#{account_number}/orders/#{order_id}/")
        .and_raise(Tastytrade::Error.new("Order not found"))

      expect {
        account.get_order(session, order_id)
      }.to raise_error(Tastytrade::Error, "Order not found")
    end
  end
end
