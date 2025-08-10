# frozen_string_literal: true

require "spec_helper"
require "bigdecimal"
require "date"

RSpec.describe Tastytrade::Models::NestedOptionChain do
  let(:strike1_data) do
    {
      "strike-price" => "450.00",
      "call" => "SPY240315C00450000",
      "put" => "SPY240315P00450000",
      "call-streamer-symbol" => ".SPY240315C450",
      "put-streamer-symbol" => ".SPY240315P450"
    }
  end

  let(:strike2_data) do
    {
      "strike-price" => "455.00",
      "call" => "SPY240315C00455000",
      "put" => "SPY240315P00455000",
      "call-streamer-symbol" => ".SPY240315C455",
      "put-streamer-symbol" => ".SPY240315P455"
    }
  end

  let(:expiration1_data) do
    {
      "expiration-date" => "2024-03-15",
      "days-to-expiration" => 30,
      "expiration-type" => "Regular",
      "settlement-type" => "PM",
      "strikes" => [strike1_data, strike2_data]
    }
  end

  let(:expiration2_data) do
    {
      "expiration-date" => "2024-03-22",
      "days-to-expiration" => 37,
      "expiration-type" => "Weekly",
      "settlement-type" => "PM",
      "strikes" => [
        {
          "strike-price" => "460.00",
          "call" => "SPY240322C00460000",
          "put" => "SPY240322P00460000"
        }
      ]
    }
  end

  let(:nested_chain_data) do
    {
      "underlying-symbol" => "SPY",
      "root-symbol" => "SPY",
      "option-chain-type" => "Standard",
      "shares-per-contract" => 100,
      "tick-sizes" => [{ "value" => 0.01, "threshold" => 3.0 }],
      "deliverables" => [],
      "expirations" => [expiration1_data, expiration2_data]
    }
  end

  let(:nested_chain) { described_class.new(nested_chain_data) }

  describe "#initialize" do
    it "parses chain attributes" do
      expect(nested_chain.underlying_symbol).to eq("SPY")
      expect(nested_chain.root_symbol).to eq("SPY")
      expect(nested_chain.option_chain_type).to eq("Standard")
      expect(nested_chain.shares_per_contract).to eq(100)
      expect(nested_chain.tick_sizes).to be_an(Array)
      expect(nested_chain.deliverables).to eq([])
    end

    it "parses expirations" do
      expect(nested_chain.expirations).to be_an(Array)
      expect(nested_chain.expirations.length).to eq(2)
      expect(nested_chain.expirations.first).to be_a(Tastytrade::Models::NestedOptionChain::Expiration)
    end

    it "handles snake_case keys" do
      snake_data = {
        "underlying_symbol" => "QQQ",
        "root_symbol" => "QQQ",
        "option_chain_type" => "Standard",
        "shares_per_contract" => 100,
        "expirations" => []
      }
      chain = described_class.new(snake_data)
      expect(chain.underlying_symbol).to eq("QQQ")
      expect(chain.root_symbol).to eq("QQQ")
    end

    it "handles missing optional fields" do
      minimal_data = {
        "underlying-symbol" => "SPY",
        "expirations" => []
      }
      chain = described_class.new(minimal_data)
      expect(chain.underlying_symbol).to eq("SPY")
      expect(chain.shares_per_contract).to eq(100) # default value
      expect(chain.tick_sizes).to eq([])
    end
  end

  describe "#expiration_dates" do
    it "returns sorted expiration dates" do
      dates = nested_chain.expiration_dates
      expect(dates).to eq([Date.parse("2024-03-15"), Date.parse("2024-03-22")])
    end

    it "handles nil expiration dates" do
      data = nested_chain_data.dup
      data["expirations"] = [{ "expiration-date" => nil }]
      chain = described_class.new(data)
      expect(chain.expiration_dates).to eq([])
    end
  end

  describe "#all_strikes" do
    it "returns all unique strikes sorted" do
      strikes = nested_chain.all_strikes
      expect(strikes).to eq([BigDecimal("450"), BigDecimal("455"), BigDecimal("460")])
    end

    it "handles duplicate strikes across expirations" do
      data = nested_chain_data.dup
      data["expirations"][1]["strikes"] = [strike1_data] # duplicate 450 strike
      chain = described_class.new(data)
      expect(chain.all_strikes).to eq([BigDecimal("450"), BigDecimal("455")])
    end
  end

  describe "#find_expiration" do
    it "finds expiration by date" do
      exp = nested_chain.find_expiration(Date.parse("2024-03-15"))
      expect(exp).to be_a(Tastytrade::Models::NestedOptionChain::Expiration)
      expect(exp.expiration_date).to eq(Date.parse("2024-03-15"))
    end

    it "returns nil for non-existent date" do
      exp = nested_chain.find_expiration(Date.parse("2024-12-31"))
      expect(exp).to be_nil
    end
  end

  describe "#weekly_expirations" do
    it "returns only weekly expirations" do
      weeklies = nested_chain.weekly_expirations
      expect(weeklies.length).to eq(1)
      expect(weeklies.first.expiration_type).to eq("Weekly")
    end
  end

  describe "#monthly_expirations" do
    it "returns only monthly expirations" do
      monthlies = nested_chain.monthly_expirations
      expect(monthlies.length).to eq(1)
      expect(monthlies.first.expiration_type).to eq("Regular")
    end
  end

  describe "#quarterly_expirations" do
    it "returns only quarterly expirations" do
      data = nested_chain_data.dup
      data["expirations"][0]["expiration-type"] = "Quarterly"
      chain = described_class.new(data)
      quarterlies = chain.quarterly_expirations
      expect(quarterlies.length).to eq(1)
      expect(quarterlies.first.expiration_type).to eq("Quarterly")
    end
  end

  describe "#filter_by_dte" do
    it "filters by minimum DTE" do
      filtered = nested_chain.filter_by_dte(min_dte: 35)
      expect(filtered.length).to eq(1)
      expect(filtered.first.days_to_expiration).to eq(37)
    end

    it "filters by maximum DTE" do
      filtered = nested_chain.filter_by_dte(max_dte: 35)
      expect(filtered.length).to eq(1)
      expect(filtered.first.days_to_expiration).to eq(30)
    end

    it "filters by DTE range" do
      filtered = nested_chain.filter_by_dte(min_dte: 25, max_dte: 35)
      expect(filtered.length).to eq(1)
      expect(filtered.first.days_to_expiration).to eq(30)
    end

    it "handles nil DTE values" do
      data = nested_chain_data.dup
      data["expirations"][0]["days-to-expiration"] = nil
      chain = described_class.new(data)
      filtered = chain.filter_by_dte(min_dte: 10)
      expect(filtered.length).to eq(1) # Only the one with valid DTE
    end
  end

  describe "#nearest_expiration" do
    it "returns expiration closest to today" do
      allow(Date).to receive(:today).and_return(Date.parse("2024-02-13"))
      nearest = nested_chain.nearest_expiration
      expect(nearest.expiration_date).to eq(Date.parse("2024-03-15"))
    end

    it "handles nil expiration dates" do
      data = nested_chain_data.dup
      data["expirations"][0]["expiration-date"] = nil
      chain = described_class.new(data)
      nearest = chain.nearest_expiration
      expect(nearest.expiration_date).to eq(Date.parse("2024-03-22"))
    end
  end

  describe "#strikes_for_expiration" do
    it "returns strikes for specific expiration" do
      strikes = nested_chain.strikes_for_expiration(Date.parse("2024-03-15"))
      expect(strikes.length).to eq(2)
      expect(strikes.first).to be_a(Tastytrade::Models::NestedOptionChain::Strike)
    end

    it "returns empty array for non-existent expiration" do
      strikes = nested_chain.strikes_for_expiration(Date.parse("2024-12-31"))
      expect(strikes).to eq([])
    end
  end

  describe "#at_the_money_strike" do
    let(:current_price) { BigDecimal("452") }

    it "finds ATM strike across all expirations" do
      atm = nested_chain.at_the_money_strike(current_price)
      expect(atm).to eq(BigDecimal("450"))
    end

    it "finds ATM strike for specific expiration" do
      atm = nested_chain.at_the_money_strike(current_price, Date.parse("2024-03-22"))
      expect(atm).to eq(BigDecimal("460")) # Only strike available for that date
    end

    it "returns nil when current_price is nil" do
      expect(nested_chain.at_the_money_strike(nil)).to be_nil
    end

    it "returns nil for empty strikes" do
      data = nested_chain_data.dup
      data["expirations"] = []
      chain = described_class.new(data)
      expect(chain.at_the_money_strike(current_price)).to be_nil
    end
  end

  describe "#option_symbols_for_strike" do
    it "returns call and put symbols for strike" do
      symbols = nested_chain.option_symbols_for_strike(BigDecimal("450"), Date.parse("2024-03-15"))
      expect(symbols[:call]).to eq("SPY240315C00450000")
      expect(symbols[:put]).to eq("SPY240315P00450000")
    end

    it "returns nil symbols for non-existent strike" do
      symbols = nested_chain.option_symbols_for_strike(BigDecimal("999"), Date.parse("2024-03-15"))
      expect(symbols[:call]).to be_nil
      expect(symbols[:put]).to be_nil
    end

    it "returns nil symbols for non-existent expiration" do
      symbols = nested_chain.option_symbols_for_strike(BigDecimal("450"), Date.parse("2024-12-31"))
      expect(symbols[:call]).to be_nil
      expect(symbols[:put]).to be_nil
    end
  end

  describe Tastytrade::Models::NestedOptionChain::Strike do
    let(:strike) { Tastytrade::Models::NestedOptionChain::Strike.new(strike1_data) }

    it "parses strike attributes" do
      expect(strike.strike_price).to eq(BigDecimal("450"))
      expect(strike.call).to eq("SPY240315C00450000")
      expect(strike.put).to eq("SPY240315P00450000")
      expect(strike.call_streamer_symbol).to eq(".SPY240315C450")
      expect(strike.put_streamer_symbol).to eq(".SPY240315P450")
    end

    it "handles snake_case keys" do
      snake_data = {
        "strike_price" => "450.00",
        "call" => "SPY240315C00450000",
        "put" => "SPY240315P00450000",
        "call_streamer_symbol" => ".SPY240315C450",
        "put_streamer_symbol" => ".SPY240315P450"
      }
      strike = Tastytrade::Models::NestedOptionChain::Strike.new(snake_data)
      expect(strike.strike_price).to eq(BigDecimal("450"))
      expect(strike.call_streamer_symbol).to eq(".SPY240315C450")
    end

    it "handles nil values" do
      nil_data = {
        "strike-price" => nil,
        "call" => nil
      }
      strike = Tastytrade::Models::NestedOptionChain::Strike.new(nil_data)
      expect(strike.strike_price).to be_nil
      expect(strike.call).to be_nil
    end

    it "handles empty string values" do
      empty_data = {
        "strike-price" => "",
        "call" => ""
      }
      strike = Tastytrade::Models::NestedOptionChain::Strike.new(empty_data)
      expect(strike.strike_price).to be_nil
      expect(strike.call).to eq("")
    end
  end

  describe Tastytrade::Models::NestedOptionChain::Expiration do
    let(:expiration) { Tastytrade::Models::NestedOptionChain::Expiration.new(expiration1_data) }

    it "parses expiration attributes" do
      expect(expiration.expiration_date).to eq(Date.parse("2024-03-15"))
      expect(expiration.days_to_expiration).to eq(30)
      expect(expiration.expiration_type).to eq("Regular")
      expect(expiration.settlement_type).to eq("PM")
    end

    it "parses strikes" do
      expect(expiration.strikes).to be_an(Array)
      expect(expiration.strikes.length).to eq(2)
      expect(expiration.strikes.first).to be_a(Tastytrade::Models::NestedOptionChain::Strike)
    end

    describe "#weekly?" do
      it "returns true for weekly expiration" do
        weekly_data = expiration1_data.merge("expiration-type" => "Weekly")
        weekly_exp = Tastytrade::Models::NestedOptionChain::Expiration.new(weekly_data)
        expect(weekly_exp.weekly?).to be true
      end

      it "returns false for non-weekly expiration" do
        expect(expiration.weekly?).to be false
      end
    end

    describe "#monthly?" do
      it "returns true for regular expiration" do
        expect(expiration.monthly?).to be true
      end

      it "returns false for non-regular expiration" do
        weekly_data = expiration1_data.merge("expiration-type" => "Weekly")
        weekly_exp = Tastytrade::Models::NestedOptionChain::Expiration.new(weekly_data)
        expect(weekly_exp.monthly?).to be false
      end
    end

    describe "#quarterly?" do
      it "returns true for quarterly expiration" do
        quarterly_data = expiration1_data.merge("expiration-type" => "Quarterly")
        quarterly_exp = Tastytrade::Models::NestedOptionChain::Expiration.new(quarterly_data)
        expect(quarterly_exp.quarterly?).to be true
      end

      it "returns false for non-quarterly expiration" do
        expect(expiration.quarterly?).to be false
      end
    end

    it "handles snake_case keys" do
      snake_data = {
        "expiration_date" => "2024-03-15",
        "days_to_expiration" => 30,
        "expiration_type" => "Regular",
        "settlement_type" => "PM",
        "strikes" => []
      }
      exp = Tastytrade::Models::NestedOptionChain::Expiration.new(snake_data)
      expect(exp.expiration_date).to eq(Date.parse("2024-03-15"))
      expect(exp.days_to_expiration).to eq(30)
    end

    it "handles nil values" do
      nil_data = {
        "expiration-date" => nil,
        "days-to-expiration" => nil,
        "strikes" => []
      }
      exp = Tastytrade::Models::NestedOptionChain::Expiration.new(nil_data)
      expect(exp.expiration_date).to be_nil
      expect(exp.days_to_expiration).to be_nil
    end

    it "handles empty strikes array" do
      empty_data = expiration1_data.merge("strikes" => [])
      exp = Tastytrade::Models::NestedOptionChain::Expiration.new(empty_data)
      expect(exp.strikes).to eq([])
    end

    it "handles missing strikes key" do
      no_strikes_data = expiration1_data.dup
      no_strikes_data.delete("strikes")
      exp = Tastytrade::Models::NestedOptionChain::Expiration.new(no_strikes_data)
      expect(exp.strikes).to eq([])
    end
  end
end
