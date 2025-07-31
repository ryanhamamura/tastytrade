# frozen_string_literal: true

require "spec_helper"
require "bigdecimal"

RSpec.describe Tastytrade::Models::CurrentPosition do
  let(:position_data) do
    {
      "account-number" => "5WX12345",
      "symbol" => "AAPL",
      "instrument-type" => "Equity",
      "underlying-symbol" => "AAPL",
      "quantity" => "100",
      "quantity-direction" => "Long",
      "close-price" => "150.00",
      "average-open-price" => "145.00",
      "average-yearly-market-close-price" => "140.00",
      "average-daily-market-close-price" => "149.00",
      "multiplier" => 1,
      "cost-effect" => "Credit",
      "is-suppressed" => false,
      "is-frozen" => false,
      "realized-day-gain" => "200.00",
      "realized-today" => "100.00",
      "created-at" => "2024-01-10T09:00:00Z",
      "updated-at" => "2024-01-15T15:30:00Z",
      "mark" => "152.00",
      "mark-price" => "152.00",
      "restricted-quantity" => "0"
    }
  end

  subject { described_class.new(position_data) }

  describe "#initialize" do
    it "parses basic position attributes" do
      expect(subject.account_number).to eq("5WX12345")
      expect(subject.symbol).to eq("AAPL")
      expect(subject.instrument_type).to eq("Equity")
      expect(subject.underlying_symbol).to eq("AAPL")
    end

    it "converts quantity values to BigDecimal" do
      expect(subject.quantity).to be_a(BigDecimal)
      expect(subject.quantity).to eq(BigDecimal("100"))
      expect(subject.restricted_quantity).to eq(BigDecimal("0"))
    end

    it "parses quantity direction" do
      expect(subject.quantity_direction).to eq("Long")
    end

    it "converts all price values to BigDecimal" do
      expect(subject.close_price).to eq(BigDecimal("150.00"))
      expect(subject.average_open_price).to eq(BigDecimal("145.00"))
      expect(subject.average_yearly_market_close_price).to eq(BigDecimal("140.00"))
      expect(subject.average_daily_market_close_price).to eq(BigDecimal("149.00"))
      expect(subject.mark).to eq(BigDecimal("152.00"))
      expect(subject.mark_price).to eq(BigDecimal("152.00"))
    end

    it "parses multiplier as integer" do
      expect(subject.multiplier).to eq(1)
    end

    it "parses boolean fields" do
      expect(subject.is_suppressed).to be false
      expect(subject.is_frozen).to be false
    end

    it "converts realized gains to BigDecimal" do
      expect(subject.realized_day_gain).to eq(BigDecimal("200.00"))
      expect(subject.realized_today).to eq(BigDecimal("100.00"))
    end

    it "parses timestamps" do
      expect(subject.created_at).to be_a(Time)
      expect(subject.updated_at).to be_a(Time)
      expect(subject.created_at.iso8601).to eq("2024-01-10T09:00:00Z")
      expect(subject.updated_at.iso8601).to eq("2024-01-15T15:30:00Z")
    end

    context "with option position" do
      let(:position_data) do
        {
          "account-number" => "5WX12345",
          "symbol" => "AAPL 240119C150",
          "instrument-type" => "Equity Option",
          "underlying-symbol" => "AAPL",
          "quantity" => "10",
          "quantity-direction" => "Long",
          "close-price" => "5.00",
          "average-open-price" => "4.50",
          "multiplier" => 100,
          "mark-price" => "5.50",
          "expires-at" => "2024-01-19T21:00:00Z",
          "root-symbol" => "AAPL",
          "option-expiration-type" => "Regular",
          "strike-price" => "150.00",
          "option-type" => "Call",
          "contract-size" => 100,
          "exercise-style" => "American"
        }
      end

      it "parses option-specific fields" do
        expect(subject.expires_at).to be_a(Time)
        expect(subject.expires_at.iso8601).to eq("2024-01-19T21:00:00Z")
        expect(subject.root_symbol).to eq("AAPL")
        expect(subject.option_expiration_type).to eq("Regular")
        expect(subject.strike_price).to eq(BigDecimal("150.00"))
        expect(subject.option_type).to eq("Call")
        expect(subject.contract_size).to eq(100)
        expect(subject.exercise_style).to eq("American")
        expect(subject.multiplier).to eq(100)
      end
    end

    context "with nil values" do
      let(:position_data) do
        {
          "account-number" => "5WX12345",
          "symbol" => "AAPL",
          "quantity" => nil,
          "close-price" => "",
          "multiplier" => nil
        }
      end

      it "handles nil and empty values gracefully" do
        expect(subject.quantity).to eq(BigDecimal("0"))
        expect(subject.close_price).to eq(BigDecimal("0"))
        expect(subject.multiplier).to eq(1)
      end
    end
  end

  describe "#long?" do
    it "returns true for long positions" do
      expect(subject.long?).to be true
    end

    context "with short position" do
      before { position_data["quantity-direction"] = "Short" }
      it "returns false" do
        expect(subject.long?).to be false
      end
    end
  end

  describe "#short?" do
    it "returns false for long positions" do
      expect(subject.short?).to be false
    end

    context "with short position" do
      before { position_data["quantity-direction"] = "Short" }
      it "returns true" do
        expect(subject.short?).to be true
      end
    end
  end

  describe "#closed?" do
    it "returns false for open positions" do
      expect(subject.closed?).to be false
    end

    context "with zero quantity direction" do
      before { position_data["quantity-direction"] = "Zero" }
      it "returns true" do
        expect(subject.closed?).to be true
      end
    end

    context "with zero quantity" do
      before { position_data["quantity"] = "0" }
      it "returns true" do
        expect(subject.closed?).to be true
      end
    end
  end

  describe "#equity?" do
    it "returns true for equity positions" do
      expect(subject.equity?).to be true
    end

    context "with option position" do
      before { position_data["instrument-type"] = "Equity Option" }
      it "returns false" do
        expect(subject.equity?).to be false
      end
    end
  end

  describe "#option?" do
    it "returns false for equity positions" do
      expect(subject.option?).to be false
    end

    context "with option position" do
      before { position_data["instrument-type"] = "Equity Option" }
      it "returns true" do
        expect(subject.option?).to be true
      end
    end
  end

  describe "#futures?" do
    it "returns false for equity positions" do
      expect(subject.futures?).to be false
    end

    context "with futures position" do
      before { position_data["instrument-type"] = "Future" }
      it "returns true" do
        expect(subject.futures?).to be true
      end
    end
  end

  describe "#futures_option?" do
    it "returns false for equity positions" do
      expect(subject.futures_option?).to be false
    end

    context "with futures option position" do
      before { position_data["instrument-type"] = "Future Option" }
      it "returns true" do
        expect(subject.futures_option?).to be true
      end
    end
  end

  describe "#position_value" do
    it "calculates position value correctly for long positions" do
      # 100 shares * $152 * 1 = $15,200
      expect(subject.position_value).to eq(BigDecimal("15200"))
    end

    context "with short position" do
      before do
        position_data["quantity-direction"] = "Short"
        position_data["quantity"] = "-100"
      end

      it "uses absolute quantity" do
        expect(subject.position_value).to eq(BigDecimal("15200"))
      end
    end

    context "with options" do
      before do
        position_data["quantity"] = "10"
        position_data["mark-price"] = "5.00"
        position_data["multiplier"] = 100
      end

      it "includes multiplier" do
        # 10 contracts * $5 * 100 = $5,000
        expect(subject.position_value).to eq(BigDecimal("5000"))
      end
    end

    context "when position is closed" do
      before { position_data["quantity-direction"] = "Zero" }

      it "returns zero" do
        expect(subject.position_value).to eq(BigDecimal("0"))
      end
    end

    context "when mark price is nil" do
      before { position_data["mark-price"] = nil }

      it "falls back to close price" do
        # 100 shares * $150 * 1 = $15,000
        expect(subject.position_value).to eq(BigDecimal("15000"))
      end
    end
  end

  describe "#unrealized_pnl" do
    it "calculates profit for long positions correctly" do
      # (152 - 145) * 100 * 1 = $700
      expect(subject.unrealized_pnl).to eq(BigDecimal("700"))
    end

    context "with short position" do
      before do
        position_data["quantity-direction"] = "Short"
        position_data["quantity"] = "-100"
        position_data["average-open-price"] = "155.00"
        position_data["mark-price"] = "152.00"
      end

      it "calculates profit correctly" do
        # (155 - 152) * 100 * 1 = $300
        expect(subject.unrealized_pnl).to eq(BigDecimal("300"))
      end
    end

    context "with losing long position" do
      before do
        position_data["average-open-price"] = "160.00"
        position_data["mark-price"] = "152.00"
      end

      it "calculates loss correctly" do
        # (152 - 160) * 100 * 1 = -$800
        expect(subject.unrealized_pnl).to eq(BigDecimal("-800"))
      end
    end

    context "when position is closed" do
      before { position_data["quantity-direction"] = "Zero" }

      it "returns zero" do
        expect(subject.unrealized_pnl).to eq(BigDecimal("0"))
      end
    end

    context "when average open price is zero" do
      before { position_data["average-open-price"] = "0" }

      it "returns zero" do
        expect(subject.unrealized_pnl).to eq(BigDecimal("0"))
      end
    end
  end

  describe "#unrealized_pnl_percentage" do
    it "calculates percentage correctly" do
      # PnL = $700, Cost = 145 * 100 = $14,500
      # 700 / 14500 * 100 = 4.83%
      expect(subject.unrealized_pnl_percentage).to eq(BigDecimal("4.83"))
    end

    context "with losing position" do
      before do
        position_data["average-open-price"] = "160.00"
        position_data["mark-price"] = "152.00"
      end

      it "calculates negative percentage" do
        # PnL = -$800, Cost = 160 * 100 = $16,000
        # -800 / 16000 * 100 = -5.00%
        expect(subject.unrealized_pnl_percentage).to eq(BigDecimal("-5.00"))
      end
    end

    context "when position is closed" do
      before { position_data["quantity-direction"] = "Zero" }

      it "returns zero" do
        expect(subject.unrealized_pnl_percentage).to eq(BigDecimal("0"))
      end
    end

    context "when cost basis is zero" do
      before { position_data["average-open-price"] = "0" }

      it "returns zero" do
        expect(subject.unrealized_pnl_percentage).to eq(BigDecimal("0"))
      end
    end
  end

  describe "#total_pnl" do
    it "sums realized and unrealized P&L" do
      # Realized today: $100, Unrealized: $700
      expect(subject.total_pnl).to eq(BigDecimal("800"))
    end
  end

  describe "#display_symbol" do
    context "with equity position" do
      it "returns the symbol as-is" do
        expect(subject.display_symbol).to eq("AAPL")
      end
    end

    context "with option position" do
      let(:position_data) do
        {
          "symbol" => "AAPL 240119C150",
          "instrument-type" => "Equity Option",
          "expires-at" => "2024-01-19T21:00:00Z",
          "root-symbol" => "AAPL",
          "strike-price" => "150.00",
          "option-type" => "Call"
        }
      end

      it "formats option symbol nicely" do
        expect(subject.display_symbol).to eq("AAPL 01/19/24 C 150.0")
      end

      context "with put option" do
        before { position_data["option-type"] = "Put" }

        it "uses P for puts" do
          expect(subject.display_symbol).to eq("AAPL 01/19/24 P 150.0")
        end
      end

      context "with missing option data" do
        before do
          position_data["expires-at"] = nil
          position_data["strike-price"] = nil
          position_data["option-type"] = nil
        end

        it "returns original symbol" do
          expect(subject.display_symbol).to eq("AAPL 240119C150")
        end
      end
    end
  end

  describe "precision handling" do
    context "with fractional shares" do
      before { position_data["quantity"] = "0.5" }

      it "handles fractional quantities" do
        expect(subject.quantity).to eq(BigDecimal("0.5"))
        expect(subject.position_value).to eq(BigDecimal("76")) # 0.5 * 152
      end
    end

    context "with very small prices" do
      before do
        position_data["mark-price"] = "0.0001"
        position_data["average-open-price"] = "0.0002"
      end

      it "maintains precision" do
        expect(subject.mark_price).to eq(BigDecimal("0.0001"))
        expect(subject.average_open_price).to eq(BigDecimal("0.0002"))
      end
    end
  end
end
