# frozen_string_literal: true

require "spec_helper"

RSpec.describe Tastytrade::Models::LiveOrder do
  let(:live_order_data) do
    {
      "id" => "12345",
      "account-number" => "5WV12345",
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
      "created-at" => "2024-01-15T09:30:00.000Z",
      "updated-at" => "2024-01-15T09:30:05.000Z",
      "received-at" => "2024-01-15T09:30:00.000Z",
      "live-at" => "2024-01-15T09:30:05.000Z",
      "legs" => [
        {
          "symbol" => "AAPL",
          "instrument-type" => "Equity",
          "action" => "Buy",
          "quantity" => 100,
          "remaining-quantity" => 100,
          "fills" => []
        }
      ]
    }
  end

  let(:filled_order_data) do
    live_order_data.merge(
      "status" => "Filled",
      "cancellable" => false,
      "editable" => false,
      "filled-at" => "2024-01-15T09:35:00.000Z",
      "terminal-at" => "2024-01-15T09:35:00.000Z",
      "legs" => [
        {
          "symbol" => "AAPL",
          "instrument-type" => "Equity",
          "action" => "Buy",
          "quantity" => 100,
          "remaining-quantity" => 0,
          "fill-quantity" => 100,
          "fill-price" => "150.45",
          "fills" => [
            {
              "ext-exec-id" => "exec123",
              "fill-id" => "fill123",
              "quantity" => 100,
              "fill-price" => "150.45",
              "filled-at" => "2024-01-15T09:35:00.000Z"
            }
          ]
        }
      ]
    )
  end

  let(:partially_filled_order_data) do
    live_order_data.merge(
      "legs" => [
        {
          "symbol" => "AAPL",
          "instrument-type" => "Equity",
          "action" => "Buy",
          "quantity" => 100,
          "remaining-quantity" => 60,
          "fill-quantity" => 40,
          "fill-price" => "150.48",
          "fills" => [
            {
              "ext-exec-id" => "exec124",
              "fill-id" => "fill124",
              "quantity" => 40,
              "fill-price" => "150.48",
              "filled-at" => "2024-01-15T09:32:00.000Z"
            }
          ]
        }
      ]
    )
  end

  describe "#initialize" do
    subject(:live_order) { described_class.new(live_order_data) }

    it "parses basic attributes correctly" do
      expect(live_order.id).to eq("12345")
      expect(live_order.account_number).to eq("5WV12345")
      expect(live_order.status).to eq("Live")
      expect(live_order.cancellable).to be true
      expect(live_order.editable).to be true
      expect(live_order.edited).to be false
    end

    it "parses order details correctly" do
      expect(live_order.time_in_force).to eq("Day")
      expect(live_order.order_type).to eq("Limit")
      expect(live_order.size).to eq(100)
      expect(live_order.price).to eq(BigDecimal("150.50"))
      expect(live_order.price_effect).to eq("Debit")
      expect(live_order.underlying_symbol).to eq("AAPL")
      expect(live_order.underlying_instrument_type).to eq("Equity")
    end

    it "parses timestamps correctly" do
      expect(live_order.created_at).to be_a(Time)
      expect(live_order.updated_at).to be_a(Time)
      expect(live_order.received_at).to be_a(Time)
      expect(live_order.live_at).to be_a(Time)
    end

    it "parses legs correctly" do
      expect(live_order.legs).to be_an(Array)
      expect(live_order.legs.size).to eq(1)
      leg = live_order.legs.first
      expect(leg).to be_a(Tastytrade::Models::LiveOrderLeg)
      expect(leg.symbol).to eq("AAPL")
      expect(leg.action).to eq("Buy")
      expect(leg.quantity).to eq(100)
      expect(leg.remaining_quantity).to eq(100)
    end
  end

  describe "status check methods" do
    context "with a live order" do
      subject(:live_order) { described_class.new(live_order_data) }

      it "#cancellable? returns true" do
        expect(live_order.cancellable?).to be true
      end

      it "#editable? returns true" do
        expect(live_order.editable?).to be true
      end

      it "#terminal? returns false" do
        expect(live_order.terminal?).to be false
      end

      it "#working? returns true" do
        expect(live_order.working?).to be true
      end

      it "#filled? returns false" do
        expect(live_order.filled?).to be false
      end

      it "#cancelled? returns false" do
        expect(live_order.cancelled?).to be false
      end
    end

    context "with a filled order" do
      subject(:filled_order) { described_class.new(filled_order_data) }

      it "#cancellable? returns false" do
        expect(filled_order.cancellable?).to be false
      end

      it "#editable? returns false" do
        expect(filled_order.editable?).to be false
      end

      it "#terminal? returns true" do
        expect(filled_order.terminal?).to be true
      end

      it "#working? returns false" do
        expect(filled_order.working?).to be false
      end

      it "#filled? returns true" do
        expect(filled_order.filled?).to be true
      end
    end
  end

  describe "quantity methods" do
    context "with an unfilled order" do
      subject(:order) { described_class.new(live_order_data) }

      it "#remaining_quantity returns total remaining" do
        expect(order.remaining_quantity).to eq(100)
      end

      it "#filled_quantity returns 0" do
        expect(order.filled_quantity).to eq(0)
      end
    end

    context "with a partially filled order" do
      subject(:order) { described_class.new(partially_filled_order_data) }

      it "#remaining_quantity returns correct value" do
        expect(order.remaining_quantity).to eq(60)
      end

      it "#filled_quantity returns correct value" do
        expect(order.filled_quantity).to eq(40)
      end
    end

    context "with a filled order" do
      subject(:order) { described_class.new(filled_order_data) }

      it "#remaining_quantity returns 0" do
        expect(order.remaining_quantity).to eq(0)
      end

      it "#filled_quantity returns total quantity" do
        expect(order.filled_quantity).to eq(100)
      end
    end
  end
end

RSpec.describe Tastytrade::Models::LiveOrderLeg do
  let(:unfilled_leg_data) do
    {
      "symbol" => "AAPL",
      "instrument-type" => "Equity",
      "action" => "Buy",
      "quantity" => 100,
      "remaining-quantity" => 100,
      "fills" => []
    }
  end

  let(:partially_filled_leg_data) do
    {
      "symbol" => "AAPL",
      "instrument-type" => "Equity",
      "action" => "Buy",
      "quantity" => 100,
      "remaining-quantity" => 60,
      "fill-quantity" => 40,
      "fill-price" => "150.48",
      "fills" => [
        {
          "ext-exec-id" => "exec124",
          "fill-id" => "fill124",
          "quantity" => 40,
          "fill-price" => "150.48",
          "filled-at" => "2024-01-15T09:32:00.000Z"
        }
      ]
    }
  end

  describe "#filled_quantity" do
    it "calculates correctly for unfilled leg" do
      leg = described_class.new(unfilled_leg_data)
      expect(leg.filled_quantity).to eq(0)
    end

    it "calculates correctly for partially filled leg" do
      leg = described_class.new(partially_filled_leg_data)
      expect(leg.filled_quantity).to eq(40)
    end
  end

  describe "#filled?" do
    it "returns false for unfilled leg" do
      leg = described_class.new(unfilled_leg_data)
      expect(leg.filled?).to be false
    end

    it "returns false for partially filled leg" do
      leg = described_class.new(partially_filled_leg_data)
      expect(leg.filled?).to be false
    end
  end

  describe "#partially_filled?" do
    it "returns false for unfilled leg" do
      leg = described_class.new(unfilled_leg_data)
      expect(leg.partially_filled?).to be false
    end

    it "returns true for partially filled leg" do
      leg = described_class.new(partially_filled_leg_data)
      expect(leg.partially_filled?).to be true
    end
  end
end
