# frozen_string_literal: true

require "spec_helper"
require "bigdecimal"
require "date"

RSpec.describe Tastytrade::Models::Option do
  let(:option_data) do
    {
      "symbol" => "SPY240315C00450000",
      "root-symbol" => "SPY",
      "underlying-symbol" => "SPY",
      "streamer-symbol" => ".SPY240315C450",
      "option-type" => "Call",
      "expiration-date" => "2024-03-15",
      "strike-price" => "450.00",
      "contract-size" => 100,
      "exercise-style" => "American",
      "expiration-type" => "Regular",
      "settlement-type" => "Physical",
      "active" => true,
      "days-to-expiration" => 30,
      "stops-trading-at" => "2024-03-15T20:00:00Z",
      "expires-at" => "2024-03-15T21:00:00Z",
      "option-chain-type" => "Standard",
      "shares-per-contract" => 100,
      "delta" => "0.45",
      "gamma" => "0.02",
      "theta" => "-0.05",
      "vega" => "0.12",
      "rho" => "0.08",
      "implied-volatility" => "0.18",
      "bid" => "5.25",
      "ask" => "5.35",
      "last" => "5.30",
      "mark" => "5.30",
      "bid-size" => 100,
      "ask-size" => 150,
      "last-size" => 10,
      "volume" => 1500,
      "open-interest" => 5000
    }
  end

  let(:option) { described_class.new(option_data) }

  describe "#initialize" do
    it "parses all core identifiers" do
      expect(option.symbol).to eq("SPY240315C00450000")
      expect(option.root_symbol).to eq("SPY")
      expect(option.underlying_symbol).to eq("SPY")
      expect(option.streamer_symbol).to eq(".SPY240315C450")
    end

    it "parses option specifications" do
      expect(option.option_type).to eq("Call")
      expect(option.expiration_date).to eq(Date.parse("2024-03-15"))
      expect(option.strike_price).to eq(BigDecimal("450.00"))
      expect(option.contract_size).to eq(100)
      expect(option.exercise_style).to eq("American")
      expect(option.expiration_type).to eq("Regular")
      expect(option.settlement_type).to eq("Physical")
    end

    it "parses trading attributes" do
      expect(option.active).to be true
      expect(option.days_to_expiration).to eq(30)
      expect(option.stops_trading_at).to be_a(Time)
      expect(option.expires_at).to be_a(Time)
      expect(option.option_chain_type).to eq("Standard")
      expect(option.shares_per_contract).to eq(100)
    end

    it "parses Greeks" do
      expect(option.delta).to eq(BigDecimal("0.45"))
      expect(option.gamma).to eq(BigDecimal("0.02"))
      expect(option.theta).to eq(BigDecimal("-0.05"))
      expect(option.vega).to eq(BigDecimal("0.12"))
      expect(option.rho).to eq(BigDecimal("0.08"))
      expect(option.implied_volatility).to eq(BigDecimal("0.18"))
    end

    it "parses pricing data" do
      expect(option.bid).to eq(BigDecimal("5.25"))
      expect(option.ask).to eq(BigDecimal("5.35"))
      expect(option.last).to eq(BigDecimal("5.30"))
      expect(option.mark).to eq(BigDecimal("5.30"))
      expect(option.bid_size).to eq(100)
      expect(option.ask_size).to eq(150)
      expect(option.volume).to eq(1500)
      expect(option.open_interest).to eq(5000)
    end

    it "auto-generates streamer symbol if not provided" do
      data = option_data.dup
      data.delete("streamer-symbol")
      opt = described_class.new(data)
      expect(opt.streamer_symbol).to eq(".SPY240315C450")
    end

    it "handles snake_case keys" do
      snake_case_data = {
        "symbol" => "SPY240315P00400000",
        "root_symbol" => "SPY",
        "underlying_symbol" => "SPY",
        "option_type" => "Put",
        "expiration_date" => "2024-03-15",
        "strike_price" => "400.00"
      }
      opt = described_class.new(snake_case_data)
      expect(opt.root_symbol).to eq("SPY")
      expect(opt.option_type).to eq("Put")
    end
  end

  describe ".occ_to_streamer_symbol" do
    it "converts OCC format to streamer format" do
      expect(described_class.occ_to_streamer_symbol("SPY240315C00450000")).to eq(".SPY240315C450")
      expect(described_class.occ_to_streamer_symbol("AAPL240315P00175500")).to eq(".AAPL240315P175.5")
      expect(described_class.occ_to_streamer_symbol("QQQ240315C00400250")).to eq(".QQQ240315C400.25")
    end

    it "handles nil input" do
      expect(described_class.occ_to_streamer_symbol(nil)).to be_nil
    end

    it "returns nil for invalid format" do
      expect(described_class.occ_to_streamer_symbol("INVALID")).to be_nil
    end
  end

  describe ".streamer_symbol_to_occ" do
    it "converts streamer format to OCC format" do
      expect(described_class.streamer_symbol_to_occ(".SPY240315C450")).to eq("SPY240315C00450000")
      expect(described_class.streamer_symbol_to_occ(".AAPL240315P175.5")).to eq("AAPL240315P00175500")
      expect(described_class.streamer_symbol_to_occ("QQQ240315C400.25")).to eq("QQQ240315C00400250")
    end

    it "handles nil input" do
      expect(described_class.streamer_symbol_to_occ(nil)).to be_nil
    end

    it "returns nil for invalid format" do
      expect(described_class.streamer_symbol_to_occ("INVALID")).to be_nil
    end
  end

  describe "#call?" do
    it "returns true for call options" do
      expect(option.call?).to be true
    end

    it "returns false for put options" do
      put_data = option_data.merge("option-type" => "Put")
      put_option = described_class.new(put_data)
      expect(put_option.call?).to be false
    end
  end

  describe "#put?" do
    it "returns false for call options" do
      expect(option.put?).to be false
    end

    it "returns true for put options" do
      put_data = option_data.merge("option-type" => "Put")
      put_option = described_class.new(put_data)
      expect(put_option.put?).to be true
    end
  end

  describe "#expired?" do
    it "returns false for future expiration" do
      future_data = option_data.merge("expiration-date" => (Date.today + 30).to_s)
      future_option = described_class.new(future_data)
      expect(future_option.expired?).to be false
    end

    it "returns true for past expiration" do
      past_data = option_data.merge("expiration-date" => (Date.today - 30).to_s)
      past_option = described_class.new(past_data)
      expect(past_option.expired?).to be true
    end

    it "returns false when expiration_date is nil" do
      nil_data = option_data.merge("expiration-date" => nil)
      nil_option = described_class.new(nil_data)
      expect(nil_option.expired?).to be false
    end
  end

  describe "#days_until_expiration" do
    it "calculates days until expiration" do
      future_date = Date.today + 10
      future_data = option_data.merge("expiration-date" => future_date.to_s)
      future_option = described_class.new(future_data)
      expect(future_option.days_until_expiration).to eq(10)
    end

    it "returns 0 for expired options" do
      past_data = option_data.merge("expiration-date" => (Date.today - 30).to_s)
      past_option = described_class.new(past_data)
      expect(past_option.days_until_expiration).to eq(0)
    end

    it "returns nil when expiration_date is nil" do
      nil_data = option_data.merge("expiration-date" => nil)
      nil_option = described_class.new(nil_data)
      expect(nil_option.days_until_expiration).to be_nil
    end
  end

  describe "moneyness methods" do
    let(:current_price) { BigDecimal("450") }

    describe "#itm?" do
      it "returns true for ITM call" do
        call_data = option_data.merge("strike-price" => "440")
        call_option = described_class.new(call_data)
        expect(call_option.itm?(current_price)).to be true
      end

      it "returns false for OTM call" do
        call_data = option_data.merge("strike-price" => "460")
        call_option = described_class.new(call_data)
        expect(call_option.itm?(current_price)).to be false
      end

      it "returns true for ITM put" do
        put_data = option_data.merge("option-type" => "Put", "strike-price" => "460")
        put_option = described_class.new(put_data)
        expect(put_option.itm?(current_price)).to be true
      end

      it "returns false for OTM put" do
        put_data = option_data.merge("option-type" => "Put", "strike-price" => "440")
        put_option = described_class.new(put_data)
        expect(put_option.itm?(current_price)).to be false
      end

      it "returns nil when current_price is nil" do
        expect(option.itm?(nil)).to be_nil
      end
    end

    describe "#otm?" do
      it "returns true for OTM call" do
        call_data = option_data.merge("strike-price" => "460")
        call_option = described_class.new(call_data)
        expect(call_option.otm?(current_price)).to be true
      end

      it "returns false for ITM call" do
        call_data = option_data.merge("strike-price" => "440")
        call_option = described_class.new(call_data)
        expect(call_option.otm?(current_price)).to be false
      end

      it "returns nil when current_price is nil" do
        expect(option.otm?(nil)).to be_nil
      end
    end

    describe "#atm?" do
      it "returns true when within threshold" do
        atm_data = option_data.merge("strike-price" => "450.50")
        atm_option = described_class.new(atm_data)
        expect(atm_option.atm?(current_price)).to be true
      end

      it "returns false when outside threshold" do
        otm_data = option_data.merge("strike-price" => "460")
        otm_option = described_class.new(otm_data)
        expect(otm_option.atm?(current_price)).to be false
      end

      it "accepts custom threshold" do
        near_data = option_data.merge("strike-price" => "455")
        near_option = described_class.new(near_data)
        expect(near_option.atm?(current_price, threshold: BigDecimal("0.02"))).to be true
      end

      it "returns nil when current_price is nil" do
        expect(option.atm?(nil)).to be_nil
      end
    end

    describe "#moneyness_classification" do
      it "classifies as ITM" do
        itm_data = option_data.merge("strike-price" => "440")
        itm_option = described_class.new(itm_data)
        expect(itm_option.moneyness_classification(current_price)).to eq("ITM")
      end

      it "classifies as ATM" do
        atm_data = option_data.merge("strike-price" => "450.20")
        atm_option = described_class.new(atm_data)
        expect(atm_option.moneyness_classification(current_price)).to eq("ATM")
      end

      it "classifies as OTM" do
        otm_data = option_data.merge("strike-price" => "460")
        otm_option = described_class.new(otm_data)
        expect(otm_option.moneyness_classification(current_price)).to eq("OTM")
      end

      it "returns nil when current_price is nil" do
        expect(option.moneyness_classification(nil)).to be_nil
      end
    end
  end

  describe "#calculate_intrinsic_value" do
    let(:current_price) { BigDecimal("455") }

    it "calculates intrinsic value for ITM call" do
      expect(option.calculate_intrinsic_value(current_price)).to eq(BigDecimal("5"))
    end

    it "returns 0 for OTM call" do
      call_data = option_data.merge("strike-price" => "460")
      call_option = described_class.new(call_data)
      expect(call_option.calculate_intrinsic_value(current_price)).to eq(BigDecimal("0"))
    end

    it "calculates intrinsic value for ITM put" do
      put_data = option_data.merge("option-type" => "Put", "strike-price" => "460")
      put_option = described_class.new(put_data)
      expect(put_option.calculate_intrinsic_value(current_price)).to eq(BigDecimal("5"))
    end

    it "returns 0 for OTM put" do
      put_data = option_data.merge("option-type" => "Put", "strike-price" => "440")
      put_option = described_class.new(put_data)
      expect(put_option.calculate_intrinsic_value(current_price)).to eq(BigDecimal("0"))
    end

    it "returns 0 when current_price is nil" do
      expect(option.calculate_intrinsic_value(nil)).to eq(BigDecimal("0"))
    end
  end

  describe "#calculate_extrinsic_value" do
    let(:current_price) { BigDecimal("455") }

    it "calculates extrinsic value" do
      expected = option.mark - option.calculate_intrinsic_value(current_price)
      expect(option.calculate_extrinsic_value(current_price)).to eq(expected)
    end

    it "returns nil when mark is nil" do
      nil_data = option_data.merge("mark" => nil)
      nil_option = described_class.new(nil_data)
      expect(nil_option.calculate_extrinsic_value(current_price)).to be_nil
    end

    it "returns nil when current_price is nil" do
      expect(option.calculate_extrinsic_value(nil)).to be_nil
    end
  end

  describe "#display_symbol" do
    it "formats option symbol for display" do
      expect(option.display_symbol).to eq("SPY 03/15/24 C 450.0")
    end

    it "returns raw symbol when expiration_date is nil" do
      nil_data = option_data.merge("expiration-date" => nil)
      nil_option = described_class.new(nil_data)
      expect(nil_option.display_symbol).to eq("SPY240315C00450000")
    end

    it "returns raw symbol when strike_price is nil" do
      nil_data = option_data.merge("strike-price" => nil)
      nil_option = described_class.new(nil_data)
      expect(nil_option.display_symbol).to eq("SPY240315C00450000")
    end
  end

  describe "edge cases" do
    it "handles all nil values" do
      nil_data = {}
      nil_option = described_class.new(nil_data)
      expect(nil_option.symbol).to be_nil
      expect(nil_option.strike_price).to be_nil
      expect(nil_option.delta).to be_nil
    end

    it "handles empty string values" do
      empty_data = {
        "symbol" => "",
        "strike-price" => "",
        "delta" => ""
      }
      empty_option = described_class.new(empty_data)
      expect(empty_option.symbol).to eq("")
      expect(empty_option.strike_price).to be_nil
      expect(empty_option.delta).to be_nil
    end

    it "handles missing Greeks" do
      no_greeks_data = option_data.reject { |k, _| k.include?("delta") || k.include?("gamma") }
      no_greeks_option = described_class.new(no_greeks_data)
      expect(no_greeks_option.delta).to be_nil
      expect(no_greeks_option.gamma).to be_nil
    end
  end
end
