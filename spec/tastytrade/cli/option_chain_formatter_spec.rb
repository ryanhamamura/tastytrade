# frozen_string_literal: true

require "spec_helper"
require "tastytrade/cli/option_chain_formatter"
require "tastytrade/models/option"
require "tastytrade/models/option_chain"
require "tastytrade/models/nested_option_chain"

RSpec.describe Tastytrade::OptionChainFormatter do
  let(:formatter) { described_class.new }
  let(:pastel) { Pastel.new(enabled: false) }
  let(:formatter_with_color) { described_class.new(pastel: Pastel.new(enabled: true)) }

  # Create sample option data
  let(:call_option) do
    Tastytrade::Models::Option.new(
      "symbol" => "SPY240315C00450000",
      "underlying-symbol" => "SPY",
      "root-symbol" => "SPY",
      "option-type" => "Call",
      "strike-price" => 450.0,
      "expiration-date" => "2024-03-15",
      "days-to-expiration" => 30,
      "bid" => 5.50,
      "ask" => 5.55,
      "volume" => 1234,
      "open-interest" => 5678,
      "delta" => 0.65,
      "gamma" => 0.012,
      "theta" => -0.085,
      "vega" => 0.156,
      "implied-volatility" => 0.185
    )
  end

  let(:put_option) do
    Tastytrade::Models::Option.new(
      "symbol" => "SPY240315P00450000",
      "underlying-symbol" => "SPY",
      "root-symbol" => "SPY",
      "option-type" => "Put",
      "strike-price" => 450.0,
      "expiration-date" => "2024-03-15",
      "days-to-expiration" => 30,
      "bid" => 4.20,
      "ask" => 4.25,
      "volume" => 987,
      "open-interest" => 3456,
      "delta" => -0.35,
      "gamma" => 0.012,
      "theta" => -0.080,
      "vega" => 0.156,
      "implied-volatility" => 0.175
    )
  end

  let(:option_chain) do
    chain = Tastytrade::Models::OptionChain.new(
      "underlying-symbol" => "SPY",
      "root-symbol" => "SPY",
      "option-chain-type" => "Standard",
      "shares-per-contract" => 100,
      "symbols" => [
        "SPY240315C00450000",
        "SPY240315P00450000"
      ]
    )

    # Set up expirations hash with Option objects
    chain.instance_variable_set(:@expirations, {
                                  Date.parse("2024-03-15") => [call_option, put_option]
                                })

    chain
  end

  let(:nested_option_chain) do
    chain = Tastytrade::Models::NestedOptionChain.new(
      "underlying-symbol" => "SPY",
      "root-symbol" => "SPY",
      "option-chain-type" => "Standard",
      "shares-per-contract" => 100,
      "expirations" => [{
        "expiration-date" => "2024-03-15",
        "days-to-expiration" => 30,
        "expiration-type" => "Regular",
        "settlement-type" => "PM",
        "strikes" => [{
          "strike-price" => 450.0,
          "call" => "SPY240315C00450000",
          "call-streamer-symbol" => ".SPY240315C450",
          "put" => "SPY240315P00450000",
          "put-streamer-symbol" => ".SPY240315P450"
        }]
      }]
    )
    chain
  end

  let(:empty_chain) do
    Tastytrade::Models::OptionChain.new(
      "underlying-symbol" => "SPY",
      "root-symbol" => "SPY",
      "option-chain-type" => "Standard",
      "shares-per-contract" => 100
    )
  end

  describe "#format_table" do
    context "with complete data" do
      it "formats a nested option chain" do
        output = formatter.format_table(nested_option_chain, current_price: 450.0)
        expect(output).to include("SPY Option Chain")
        expect(output).to include("450.0")
        expect(output).to include("2024-03-15")
        expect(output).to include("30 DTE")
      end

      it "formats a compact option chain" do
        output = formatter.format_table(option_chain, current_price: 450.0)
        expect(output).to include("SPY Option Chain")
        expect(output).to include("Current Price: $450.00")
      end

      it "includes Greeks when requested" do
        output = formatter.format_table(nested_option_chain, current_price: 450.0, show_greeks: true)
        expect(output).to include("Δ")
        expect(output).to include("IV")
      end

      it "uses different format modes" do
        detailed = formatter.format_table(nested_option_chain, format: :detailed)
        compact = formatter.format_table(nested_option_chain, format: :compact)
        greeks = formatter.format_table(nested_option_chain, format: :greeks)

        expect(detailed).not_to eq(compact)
        expect(greeks).to include("γ")
        expect(greeks).to include("θ")
        expect(greeks).to include("ν")
      end
    end

    context "with missing data" do
      it "handles nil values gracefully" do
        chain_with_nils = nested_option_chain.dup
        chain_with_nils.expirations.first.strikes.first.instance_variable_set(:@call, nil)

        output = formatter.format_table(chain_with_nils)
        expect(output).to include("-")
        expect(output).not_to include("nil")
      end

      it "handles missing current price" do
        output = formatter.format_table(nested_option_chain)
        expect(output).not_to include("Current Price")
        expect(output).to include("SPY Option Chain")
      end
    end

    context "with empty chain" do
      it "displays appropriate message for empty chain" do
        output = formatter.format_table(empty_chain)
        expect(output).to include("No options available for SPY")
      end
    end
  end

  describe "moneyness highlighting" do
    it "identifies ATM strikes correctly" do
      output = formatter_with_color.format_table(nested_option_chain, current_price: 450.0)
      # ATM strike should be highlighted
      expect(output).to include("450.00*") if output.include?("*")
    end

    it "colors ITM strikes differently" do
      chain = nested_option_chain.dup
      # Create new expiration with additional strike
      exp_data = {
        "expiration-date" => "2024-03-15",
        "days-to-expiration" => 30,
        "expiration-type" => "Regular",
        "settlement-type" => "PM",
        "strikes" => [
          {
            "strike-price" => 440.0,
            "call" => "SPY240315C00440000",
            "put" => "SPY240315P00440000"
          },
          {
            "strike-price" => 450.0,
            "call" => "SPY240315C00450000",
            "put" => "SPY240315P00450000"
          }
        ]
      }
      chain.instance_variable_set(:@expirations, [Tastytrade::Models::NestedOptionChain::Expiration.new(exp_data)])

      output = formatter_with_color.format_table(chain, current_price: 450.0)
      # ITM calls are below current price
      expect(output).to include("440")
    end

    it "colors OTM strikes differently" do
      chain = nested_option_chain.dup
      # Create new expiration with additional strike
      exp_data = {
        "expiration-date" => "2024-03-15",
        "days-to-expiration" => 30,
        "expiration-type" => "Regular",
        "settlement-type" => "PM",
        "strikes" => [
          {
            "strike-price" => 450.0,
            "call" => "SPY240315C00450000",
            "put" => "SPY240315P00450000"
          },
          {
            "strike-price" => 460.0,
            "call" => "SPY240315C00460000",
            "put" => "SPY240315P00460000"
          }
        ]
      }
      chain.instance_variable_set(:@expirations, [Tastytrade::Models::NestedOptionChain::Expiration.new(exp_data)])

      output = formatter_with_color.format_table(chain, current_price: 450.0)
      # OTM calls are above current price
      expect(output).to include("460")
    end
  end

  describe "volume formatting" do
    it "formats small volumes as plain numbers" do
      output = formatter.send(:format_volume, 123)
      expect(output).to eq("123")
    end

    it "formats thousands with K suffix" do
      output = formatter.send(:format_volume, 1500)
      expect(output).to eq("1.5K")
    end

    it "formats millions with M suffix" do
      output = formatter.send(:format_volume, 2_500_000)
      expect(output).to eq("2.5M")
    end

    it "handles nil volumes" do
      output = formatter.send(:format_volume, nil)
      expect(output).to eq("-")
    end

    it "handles zero volumes" do
      output = formatter.send(:format_volume, 0)
      expect(output).to eq("-")
    end
  end

  describe "Greeks formatting" do
    it "formats delta with 3 decimal places" do
      output = formatter.send(:format_delta, 0.6543)
      expect(output).to eq("0.654")
    end

    it "formats other Greeks with 4 decimal places" do
      output = formatter.send(:format_greek, 0.012345)
      expect(output).to eq("0.0123")
    end

    it "formats implied volatility as percentage" do
      output = formatter.send(:format_iv, 0.185)
      expect(output).to eq("18.5%")
    end

    it "handles nil Greeks" do
      expect(formatter.send(:format_delta, nil)).to eq("-")
      expect(formatter.send(:format_greek, nil)).to eq("-")
      expect(formatter.send(:format_iv, nil)).to eq("-")
    end
  end

  describe "#to_csv" do
    it "exports chain to CSV format" do
      csv = formatter.to_csv(nested_option_chain, current_price: 450.0)

      expect(csv).to include("Expiration")
      expect(csv).to include("Strike")
      expect(csv).to include("Moneyness")
      expect(csv).to include("Call Symbol")
      expect(csv).to include("Put Symbol")
      expect(csv).to include("2024-03-15")
      expect(csv).to include("450")
    end

    it "includes all required columns" do
      csv = formatter.to_csv(nested_option_chain)
      lines = csv.split("\n")
      headers = lines.first.split(",")

      expect(headers).to include("Expiration")
      expect(headers).to include("DTE")
      expect(headers).to include("Strike")
      expect(headers).to include("Moneyness")
      expect(headers).to include("Call Symbol")
      expect(headers).to include("Call Bid")
      expect(headers).to include("Call Ask")
      expect(headers).to include("Call Volume")
      expect(headers).to include("Call OI")
      expect(headers).to include("Call Delta")
      expect(headers).to include("Call IV")
      expect(headers).to include("Put Symbol")
      expect(headers).to include("Put Bid")
      expect(headers).to include("Put Ask")
      expect(headers).to include("Put Volume")
      expect(headers).to include("Put OI")
      expect(headers).to include("Put Delta")
      expect(headers).to include("Put IV")
    end

    it "handles empty chains" do
      csv = formatter.to_csv(empty_chain)
      lines = csv.split("\n")
      expect(lines.size).to eq(1) # Headers only
    end
  end

  describe "#to_json" do
    it "exports chain to JSON format" do
      json_str = formatter.to_json(nested_option_chain, current_price: 450.0)
      json = JSON.parse(json_str)

      expect(json["underlying_symbol"]).to eq("SPY")
      expect(json["current_price"]).to eq(450.0)
      expect(json["chain_type"]).to eq("Standard")
      expect(json["expirations"]).to be_an(Array)
      expect(json["expirations"].size).to eq(1)
    end

    it "includes strike details" do
      json_str = formatter.to_json(nested_option_chain, current_price: 450.0)
      json = JSON.parse(json_str)

      expiration = json["expirations"].first
      expect(expiration["expiration_date"]).to eq("2024-03-15")
      expect(expiration["days_to_expiration"]).to eq(30)
      expect(expiration["strikes"]).to be_an(Array)

      strike = expiration["strikes"].first
      expect(strike["strike_price"]).to eq(450.0)
      expect(strike["moneyness"]).to eq("ATM")
    end

    it "includes timestamp" do
      json_str = formatter.to_json(nested_option_chain)
      json = JSON.parse(json_str)

      expect(json["timestamp"]).not_to be_nil
      expect { Time.parse(json["timestamp"]) }.not_to raise_error
    end
  end

  describe "non-TTY fallback" do
    it "handles render errors gracefully" do
      allow_any_instance_of(TTY::Table).to receive(:render).and_raise(StandardError)

      output = formatter.format_table(nested_option_chain)
      expect(output).to include("SPY Option Chain")
      expect(output).to include("-" * 10) # Fallback separator
    end
  end

  describe "performance" do
    it "renders large chains quickly" do
      # Create a large chain with many strikes
      strikes_data = []
      101.times do |i|
        strikes_data << {
          "strike-price" => 400.0 + i,
          "call" => "SPY240315C#{"%.8d" % ((400 + i) * 1000)}",
          "put" => "SPY240315P#{"%.8d" % ((400 + i) * 1000)}"
        }
      end

      exp_data = {
        "expiration-date" => "2024-03-15",
        "days-to-expiration" => 30,
        "expiration-type" => "Regular",
        "settlement-type" => "PM",
        "strikes" => strikes_data
      }

      large_chain = Tastytrade::Models::NestedOptionChain.new(
        "underlying-symbol" => "SPY",
        "root-symbol" => "SPY",
        "option-chain-type" => "Standard",
        "shares-per-contract" => 100,
        "expirations" => [exp_data]
      )

      start_time = Time.now
      formatter.format_table(large_chain, current_price: 450.0)
      elapsed = Time.now - start_time

      expect(elapsed).to be < 0.1 # Should render in less than 100ms
    end

    it "limits display for large chains" do
      # Create a chain with many strikes
      strikes_data = []
      31.times do |i|
        strikes_data << {
          "strike-price" => 430.0 + i,
          "call" => "SPY240315C#{"%.8d" % ((430 + i) * 1000)}",
          "put" => "SPY240315P#{"%.8d" % ((430 + i) * 1000)}"
        }
      end

      exp_data = {
        "expiration-date" => "2024-03-15",
        "days-to-expiration" => 30,
        "expiration-type" => "Regular",
        "settlement-type" => "PM",
        "strikes" => strikes_data
      }

      large_chain = Tastytrade::Models::NestedOptionChain.new(
        "underlying-symbol" => "SPY",
        "root-symbol" => "SPY",
        "option-chain-type" => "Standard",
        "shares-per-contract" => 100,
        "expirations" => [exp_data]
      )

      output = formatter.format_table(large_chain, current_price: 450.0)
      expect(output).to include("Showing strikes around ATM")
    end
  end

  describe "bid/ask coloring" do
    it "colors bid prices in green" do
      colored_output = formatter_with_color.send(:color_bid, 5.50)
      expect(colored_output).to include("5.50")
    end

    it "colors ask prices in red" do
      colored_output = formatter_with_color.send(:color_ask, 5.55)
      expect(colored_output).to include("5.55")
    end

    it "handles nil bid/ask" do
      expect(formatter.send(:color_bid, nil)).to eq("-")
      expect(formatter.send(:color_ask, nil)).to eq("-")
    end

    it "handles zero bid/ask" do
      expect(formatter.send(:color_bid, 0)).to eq("-")
      expect(formatter.send(:color_ask, 0)).to eq("-")
    end
  end

  describe "currency formatting" do
    it "formats currency with 2 decimal places" do
      expect(formatter.send(:format_currency, 450.5)).to eq("$450.50")
      expect(formatter.send(:format_currency, 10)).to eq("$10.00")
      expect(formatter.send(:format_currency, 0.05)).to eq("$0.05")
    end

    it "handles nil amounts" do
      expect(formatter.send(:format_currency, nil)).to eq("-")
    end
  end
end
