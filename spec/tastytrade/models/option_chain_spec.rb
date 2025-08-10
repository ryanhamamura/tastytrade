# frozen_string_literal: true

require "spec_helper"
require "bigdecimal"
require "date"

RSpec.describe Tastytrade::Models::OptionChain do
  let(:option1_data) do
    {
      "symbol" => "SPY240315C00450000",
      "root-symbol" => "SPY",
      "option-type" => "Call",
      "expiration-date" => "2024-03-15",
      "strike-price" => "450.00",
      "expiration-type" => "Regular"
    }
  end

  let(:option2_data) do
    {
      "symbol" => "SPY240315P00450000",
      "root-symbol" => "SPY",
      "option-type" => "Put",
      "expiration-date" => "2024-03-15",
      "strike-price" => "450.00",
      "expiration-type" => "Regular"
    }
  end

  let(:option3_data) do
    {
      "symbol" => "SPY240322C00455000",
      "root-symbol" => "SPY",
      "option-type" => "Call",
      "expiration-date" => "2024-03-22",
      "strike-price" => "455.00",
      "expiration-type" => "Weekly"
    }
  end

  let(:chain_data) do
    {
      "underlying-symbol" => "SPY",
      "root-symbol" => "SPY",
      "option-chain-type" => "Standard",
      "shares-per-contract" => 100,
      "tick-sizes" => [{ "value" => 0.01, "threshold" => 3.0 }],
      "items" => [option1_data, option2_data, option3_data]
    }
  end

  let(:option_chain) { described_class.new(chain_data) }

  describe "#initialize" do
    it "parses chain attributes" do
      expect(option_chain.underlying_symbol).to eq("SPY")
      expect(option_chain.root_symbol).to eq("SPY")
      expect(option_chain.option_chain_type).to eq("Standard")
      expect(option_chain.shares_per_contract).to eq(100)
      expect(option_chain.tick_sizes).to be_an(Array)
    end

    it "parses options into expiration groups" do
      expect(option_chain.expirations).to be_a(Hash)
      expect(option_chain.expirations.keys).to include(Date.parse("2024-03-15"))
      expect(option_chain.expirations.keys).to include(Date.parse("2024-03-22"))
    end

    it "groups options by expiration date" do
      mar15_options = option_chain.expirations[Date.parse("2024-03-15")]
      expect(mar15_options.length).to eq(2)
      expect(mar15_options.map(&:symbol)).to include("SPY240315C00450000", "SPY240315P00450000")
    end

    it "handles snake_case keys" do
      snake_data = {
        "underlying_symbol" => "QQQ",
        "root_symbol" => "QQQ",
        "option_chain_type" => "Standard",
        "shares_per_contract" => 100,
        "items" => []
      }
      chain = described_class.new(snake_data)
      expect(chain.underlying_symbol).to eq("QQQ")
      expect(chain.root_symbol).to eq("QQQ")
    end

    it "handles options key instead of items" do
      options_data = chain_data.dup
      options_data["options"] = options_data.delete("items")
      chain = described_class.new(options_data)
      expect(chain.all_options.length).to eq(3)
    end

    it "handles pre-grouped expiration structure" do
      grouped_data = {
        "underlying-symbol" => "SPY",
        "items" => {
          "2024-03-15" => [option1_data, option2_data],
          "2024-03-22" => [option3_data]
        }
      }
      chain = described_class.new(grouped_data)
      expect(chain.expirations[Date.parse("2024-03-15")].length).to eq(2)
      expect(chain.expirations[Date.parse("2024-03-22")].length).to eq(1)
    end

    it "handles nested expiration structure" do
      nested_data = {
        "underlying-symbol" => "SPY",
        "expirations" => [
          {
            "expiration-date" => "2024-03-15",
            "options" => [option1_data, option2_data]
          },
          {
            "expiration-date" => "2024-03-22",
            "options" => [option3_data]
          }
        ]
      }
      chain = described_class.new(nested_data)
      expect(chain.expirations[Date.parse("2024-03-15")].length).to eq(2)
      expect(chain.expirations[Date.parse("2024-03-22")].length).to eq(1)
    end
  end

  describe "#expiration_dates" do
    it "returns sorted expiration dates" do
      dates = option_chain.expiration_dates
      expect(dates).to eq([Date.parse("2024-03-15"), Date.parse("2024-03-22")])
    end
  end

  describe "#all_options" do
    it "returns all options across expirations" do
      all_opts = option_chain.all_options
      expect(all_opts.length).to eq(3)
      expect(all_opts.map(&:symbol)).to include("SPY240315C00450000", "SPY240315P00450000", "SPY240322C00455000")
    end
  end

  describe "#options_for_expiration" do
    it "returns options for specific expiration" do
      mar15_opts = option_chain.options_for_expiration(Date.parse("2024-03-15"))
      expect(mar15_opts.length).to eq(2)
    end

    it "returns empty array for non-existent expiration" do
      opts = option_chain.options_for_expiration(Date.parse("2024-12-31"))
      expect(opts).to eq([])
    end
  end

  describe "#calls" do
    it "returns only call options" do
      calls = option_chain.calls
      expect(calls.length).to eq(2)
      expect(calls.all?(&:call?)).to be true
    end
  end

  describe "#puts" do
    it "returns only put options" do
      puts = option_chain.puts
      expect(puts.length).to eq(1)
      expect(puts.all?(&:put?)).to be true
    end
  end

  describe "#filter_by_expiration" do
    it "filters by specific expiration date" do
      filtered = option_chain.filter_by_expiration(expiration: Date.parse("2024-03-15"))
      expect(filtered.expiration_dates).to eq([Date.parse("2024-03-15")])
      expect(filtered.all_options.length).to eq(2)
    end

    it "filters by date range" do
      start_date = Date.parse("2024-03-14")
      end_date = Date.parse("2024-03-20")
      filtered = option_chain.filter_by_expiration(start_date: start_date, end_date: end_date)
      expect(filtered.expiration_dates).to eq([Date.parse("2024-03-15")])
    end

    it "returns empty chain when no matches" do
      filtered = option_chain.filter_by_expiration(expiration: Date.parse("2025-01-01"))
      expect(filtered.expirations).to be_empty
    end
  end

  describe "#filter_by_strikes" do
    let(:current_price) { BigDecimal("450") }
    let(:multi_strike_data) do
      {
        "underlying-symbol" => "SPY",
        "items" => [
          option1_data,
          option1_data.merge("strike-price" => "445", "symbol" => "SPY240315C00445000"),
          option1_data.merge("strike-price" => "455", "symbol" => "SPY240315C00455000"),
          option1_data.merge("strike-price" => "460", "symbol" => "SPY240315C00460000"),
          option1_data.merge("strike-price" => "440", "symbol" => "SPY240315C00440000")
        ]
      }
    end
    let(:multi_strike_chain) { described_class.new(multi_strike_data) }

    it "filters to specified number of strikes around ATM" do
      filtered = multi_strike_chain.filter_by_strikes(3, current_price)
      strikes = filtered.all_options.map(&:strike_price).uniq.sort
      expect(strikes.length).to be <= 3
      expect(strikes).to include(BigDecimal("450"))
    end

    it "returns self when current_price is nil" do
      filtered = multi_strike_chain.filter_by_strikes(3, nil)
      expect(filtered.all_options.length).to eq(multi_strike_chain.all_options.length)
    end

    it "returns self when num_strikes is nil" do
      filtered = multi_strike_chain.filter_by_strikes(nil, current_price)
      expect(filtered.all_options.length).to eq(multi_strike_chain.all_options.length)
    end
  end

  describe "#filter_by_moneyness" do
    let(:current_price) { BigDecimal("450") }
    let(:moneyness_data) do
      {
        "underlying-symbol" => "SPY",
        "items" => [
          option1_data.merge("strike-price" => "440"),                      # ITM Call
          option1_data.merge("strike-price" => "450"),                      # ATM Call
          option1_data.merge("strike-price" => "460"),                      # OTM Call
          option2_data.merge("strike-price" => "440", "option-type" => "Put"), # OTM Put
          option2_data.merge("strike-price" => "450", "option-type" => "Put"), # ATM Put
          option2_data.merge("strike-price" => "460", "option-type" => "Put")  # ITM Put
        ]
      }
    end
    let(:moneyness_chain) { described_class.new(moneyness_data) }

    it "filters ITM options" do
      filtered = moneyness_chain.filter_by_moneyness("ITM", current_price)
      expect(filtered.all_options.length).to eq(2)
      expect(filtered.all_options.all? { |o| o.itm?(current_price) }).to be true
    end

    it "filters ATM options" do
      filtered = moneyness_chain.filter_by_moneyness("ATM", current_price)
      expect(filtered.all_options.length).to eq(2)
      expect(filtered.all_options.all? { |o| o.atm?(current_price) }).to be true
    end

    it "filters OTM options" do
      filtered = moneyness_chain.filter_by_moneyness("OTM", current_price)
      expect(filtered.all_options.length).to eq(2)
      expect(filtered.all_options.all? { |o| o.otm?(current_price) }).to be true
    end

    it "handles custom ATM threshold" do
      filtered = moneyness_chain.filter_by_moneyness("ATM", current_price, atm_threshold: BigDecimal("0.02"))
      expect(filtered.all_options.length).to be >= 2
    end

    it "returns self for invalid moneyness" do
      filtered = moneyness_chain.filter_by_moneyness("INVALID", current_price)
      expect(filtered.all_options.length).to eq(moneyness_chain.all_options.length)
    end

    it "returns self when current_price is nil" do
      filtered = moneyness_chain.filter_by_moneyness("ITM", nil)
      expect(filtered.all_options.length).to eq(moneyness_chain.all_options.length)
    end
  end

  describe "#at_the_money_strike" do
    let(:current_price) { BigDecimal("452") }

    it "finds closest strike to current price" do
      atm_strike = option_chain.at_the_money_strike(current_price)
      expect(atm_strike).to eq(BigDecimal("450"))
    end

    it "returns nil when current_price is nil" do
      expect(option_chain.at_the_money_strike(nil)).to be_nil
    end

    it "returns nil for empty chain" do
      empty_chain = described_class.new({ "items" => [] })
      expect(empty_chain.at_the_money_strike(current_price)).to be_nil
    end
  end

  describe "#nearest_strikes" do
    let(:current_price) { BigDecimal("450") }
    let(:multi_strike_data) do
      {
        "underlying-symbol" => "SPY",
        "items" => (440..460).step(5).map do |strike|
          option1_data.merge("strike-price" => strike.to_s)
        end
      }
    end
    let(:multi_strike_chain) { described_class.new(multi_strike_data) }

    it "returns specified number of nearest strikes" do
      strikes = multi_strike_chain.nearest_strikes(current_price, 3)
      expect(strikes.length).to eq(3)
      expect(strikes).to include(BigDecimal("450"))
    end

    it "returns all strikes when fewer than requested" do
      small_chain = described_class.new(chain_data)
      strikes = small_chain.nearest_strikes(current_price, 10)
      expect(strikes.length).to eq(2) # Only 450 and 455 strikes
    end

    it "returns empty array when current_price is nil" do
      expect(multi_strike_chain.nearest_strikes(nil)).to eq([])
    end
  end

  describe "#filter_by_dte" do
    let(:today) { Date.today }
    let(:dte_data) do
      {
        "underlying-symbol" => "SPY",
        "items" => [
          option1_data.merge("expiration-date" => (today + 10).to_s),
          option1_data.merge("expiration-date" => (today + 20).to_s),
          option1_data.merge("expiration-date" => (today + 30).to_s)
        ]
      }
    end
    let(:dte_chain) { described_class.new(dte_data) }

    it "filters by minimum DTE" do
      filtered = dte_chain.filter_by_dte(min_dte: 15)
      expect(filtered.expiration_dates.all? { |d| (d - today).to_i >= 15 }).to be true
    end

    it "filters by maximum DTE" do
      filtered = dte_chain.filter_by_dte(max_dte: 25)
      expect(filtered.expiration_dates.all? { |d| (d - today).to_i <= 25 }).to be true
    end

    it "filters by DTE range" do
      filtered = dte_chain.filter_by_dte(min_dte: 15, max_dte: 25)
      dtes = filtered.expiration_dates.map { |d| (d - today).to_i }
      expect(dtes.all? { |dte| dte >= 15 && dte <= 25 }).to be true
    end
  end

  describe "#weekly_expirations" do
    it "filters weekly expirations" do
      filtered = option_chain.weekly_expirations
      expect(filtered.all_options.all? { |o| o.expiration_type == "Weekly" }).to be true
    end
  end

  describe "#monthly_expirations" do
    it "filters monthly expirations" do
      filtered = option_chain.monthly_expirations
      expect(filtered.all_options.all? { |o| o.expiration_type == "Regular" }).to be true
    end
  end

  describe "#quarterly_expirations" do
    let(:quarterly_data) do
      chain_data.merge(
        "items" => [option1_data.merge("expiration-type" => "Quarterly")]
      )
    end
    let(:quarterly_chain) { described_class.new(quarterly_data) }

    it "filters quarterly expirations" do
      filtered = quarterly_chain.quarterly_expirations
      expect(filtered.all_options.all? { |o| o.expiration_type == "Quarterly" }).to be true
    end
  end
end
