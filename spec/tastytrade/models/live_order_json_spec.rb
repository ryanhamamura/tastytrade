# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Tastytrade::Models::LiveOrder#to_h" do
  let(:order_data) do
    {
      "id" => "12345",
      "account-number" => "5WZ38925",
      "status" => "Live",
      "cancellable" => true,
      "editable" => true,
      "edited" => false,
      "time-in-force" => "Day",
      "order-type" => "Limit",
      "size" => 100,
      "price" => "150.50",
      "price-effect" => "Debit",
      "underlying-symbol" => "AAPL",
      "underlying-instrument-type" => "Equity",
      "stop-trigger" => "148.00",
      "gtc-date" => "2024-12-31",
      "created-at" => "2024-01-01T10:00:00Z",
      "updated-at" => "2024-01-01T10:05:00Z",
      "received-at" => "2024-01-01T10:00:01Z",
      "routed-at" => "2024-01-01T10:00:02Z",
      "live-at" => "2024-01-01T10:00:03Z",
      "legs" => [
        {
          "symbol" => "AAPL",
          "instrument-type" => "Equity",
          "action" => "Buy to Open",
          "quantity" => 100,
          "remaining-quantity" => 75,
          "fill-price" => "150.25",
          "fills" => [
            {
              "ext-exec-id" => "EXT123",
              "fill-id" => "FILL123",
              "quantity" => 25,
              "fill-price" => "150.25",
              "filled-at" => "2024-01-01T10:03:00Z",
              "destination-venue" => "NASDAQ"
            }
          ]
        }
      ]
    }
  end

  let(:order) { Tastytrade::Models::LiveOrder.new(order_data) }

  it "converts order to hash format" do
    hash = order.to_h

    expect(hash).to be_a(Hash)
    expect(hash[:id]).to eq("12345")
    expect(hash[:account_number]).to eq("5WZ38925")
    expect(hash[:status]).to eq("Live")
    expect(hash[:cancellable]).to be true
    expect(hash[:editable]).to be true
    expect(hash[:edited]).to be false
    expect(hash[:time_in_force]).to eq("Day")
    expect(hash[:order_type]).to eq("Limit")
    expect(hash[:size]).to eq(100)
    expect(hash[:price]).to eq("150.5")
    expect(hash[:price_effect]).to eq("Debit")
    expect(hash[:underlying_symbol]).to eq("AAPL")
    expect(hash[:underlying_instrument_type]).to eq("Equity")
    expect(hash[:stop_trigger]).to eq("148.0")
    expect(hash[:gtc_date]).to eq("2024-12-31")
    expect(hash[:remaining_quantity]).to eq(75)
    expect(hash[:filled_quantity]).to eq(25)
  end

  it "includes timestamp fields in ISO8601 format" do
    hash = order.to_h

    expect(hash[:created_at]).to eq("2024-01-01T10:00:00Z")
    expect(hash[:updated_at]).to eq("2024-01-01T10:05:00Z")
    expect(hash[:received_at]).to eq("2024-01-01T10:00:01Z")
    expect(hash[:routed_at]).to eq("2024-01-01T10:00:02Z")
    expect(hash[:live_at]).to eq("2024-01-01T10:00:03Z")
  end

  it "includes leg information" do
    hash = order.to_h

    expect(hash[:legs]).to be_an(Array)
    expect(hash[:legs].size).to eq(1)

    leg = hash[:legs].first
    expect(leg[:symbol]).to eq("AAPL")
    expect(leg[:instrument_type]).to eq("Equity")
    expect(leg[:action]).to eq("Buy to Open")
    expect(leg[:quantity]).to eq(100)
    expect(leg[:remaining_quantity]).to eq(75)
    expect(leg[:filled_quantity]).to eq(25)
    expect(leg[:fill_price]).to eq("150.25")
  end

  it "includes fill information" do
    hash = order.to_h
    leg = hash[:legs].first
    fills = leg[:fills]

    expect(fills).to be_an(Array)
    expect(fills.size).to eq(1)

    fill = fills.first
    expect(fill[:ext_exec_id]).to eq("EXT123")
    expect(fill[:fill_id]).to eq("FILL123")
    expect(fill[:quantity]).to eq(25)
    expect(fill[:fill_price]).to eq("150.25")
    expect(fill[:filled_at]).to eq("2024-01-01T10:03:00Z")
    expect(fill[:destination_venue]).to eq("NASDAQ")
  end

  it "excludes nil values from hash" do
    minimal_order_data = {
      "id" => "12345",
      "status" => "Live",
      "legs" => []
    }
    minimal_order = Tastytrade::Models::LiveOrder.new(minimal_order_data)
    hash = minimal_order.to_h

    expect(hash).not_to have_key(:price)
    expect(hash).not_to have_key(:stop_trigger)
    expect(hash).not_to have_key(:gtc_date)
    expect(hash).not_to have_key(:filled_at)
    expect(hash).not_to have_key(:cancelled_at)
  end

  it "can be serialized to JSON" do
    hash = order.to_h
    json = JSON.generate(hash)
    parsed = JSON.parse(json)

    expect(parsed["id"]).to eq("12345")
    expect(parsed["status"]).to eq("Live")
    expect(parsed["legs"]).to be_an(Array)
  end
end
