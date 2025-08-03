# frozen_string_literal: true

require "spec_helper"
require "bigdecimal"

RSpec.describe Tastytrade::Models::AccountBalance do
  let(:balance_data) do
    {
      "account-number" => "5WX12345",
      "cash-balance" => "10000.50",
      "long-equity-value" => "25000.75",
      "short-equity-value" => "5000.25",
      "long-derivative-value" => "3000.00",
      "short-derivative-value" => "1500.00",
      "net-liquidating-value" => "42001.00",
      "equity-buying-power" => "20000.00",
      "derivative-buying-power" => "15000.00",
      "day-trading-buying-power" => "40000.00",
      "available-trading-funds" => "12000.00",
      "margin-equity" => "42001.00",
      "pending-cash" => "500.00",
      "pending-margin-interest" => "25.50",
      "effective-trading-funds" => "11974.50",
      "updated-at" => "2024-01-15T10:30:00Z"
    }
  end

  subject { described_class.new(balance_data) }

  describe "#initialize" do
    it "parses account number" do
      expect(subject.account_number).to eq("5WX12345")
    end

    it "converts monetary values to BigDecimal" do
      expect(subject.cash_balance).to be_a(BigDecimal)
      expect(subject.cash_balance).to eq(BigDecimal("10000.50"))
    end

    it "parses all balance fields correctly" do
      expect(subject.long_equity_value).to eq(BigDecimal("25000.75"))
      expect(subject.short_equity_value).to eq(BigDecimal("5000.25"))
      expect(subject.long_derivative_value).to eq(BigDecimal("3000.00"))
      expect(subject.short_derivative_value).to eq(BigDecimal("1500.00"))
      expect(subject.net_liquidating_value).to eq(BigDecimal("42001.00"))
      expect(subject.equity_buying_power).to eq(BigDecimal("20000.00"))
      expect(subject.derivative_buying_power).to eq(BigDecimal("15000.00"))
      expect(subject.day_trading_buying_power).to eq(BigDecimal("40000.00"))
      expect(subject.available_trading_funds).to eq(BigDecimal("12000.00"))
      expect(subject.margin_equity).to eq(BigDecimal("42001.00"))
      expect(subject.pending_cash).to eq(BigDecimal("500.00"))
      expect(subject.pending_margin_interest).to eq(BigDecimal("25.50"))
      expect(subject.effective_trading_funds).to eq(BigDecimal("11974.50"))
    end

    it "parses updated_at as Time" do
      expect(subject.updated_at).to be_a(Time)
      expect(subject.updated_at.iso8601).to eq("2024-01-15T10:30:00Z")
    end

    context "with nil values" do
      let(:balance_data) do
        {
          "account-number" => "5WX12345",
          "cash-balance" => nil,
          "long-equity-value" => "",
          "net-liquidating-value" => "1000.00",
          "equity-buying-power" => "1000.00",
          "available-trading-funds" => "1000.00"
        }
      end

      it "converts nil and empty strings to zero" do
        expect(subject.cash_balance).to eq(BigDecimal("0"))
        expect(subject.long_equity_value).to eq(BigDecimal("0"))
      end
    end

    context "with string numbers" do
      let(:balance_data) do
        {
          "account-number" => "5WX12345",
          "cash-balance" => "1234.567890",
          "net-liquidating-value" => "1234.567890",
          "equity-buying-power" => "1000.00",
          "available-trading-funds" => "1000.00"
        }
      end

      it "maintains precision with BigDecimal" do
        expect(subject.cash_balance.to_s("F")).to eq("1234.56789")
        expect(subject.net_liquidating_value.to_s("F")).to eq("1234.56789")
      end
    end
  end

  describe "#buying_power_usage_percentage" do
    context "with normal usage" do
      it "calculates the percentage correctly" do
        # Used BP = 20000 - 12000 = 8000
        # Percentage = 8000 / 20000 * 100 = 40%
        expect(subject.buying_power_usage_percentage).to eq(BigDecimal("40.00"))
      end
    end

    context "with zero equity buying power" do
      let(:balance_data) do
        {
          "account-number" => "5WX12345",
          "equity-buying-power" => "0",
          "available-trading-funds" => "0"
        }
      end

      it "returns zero" do
        expect(subject.buying_power_usage_percentage).to eq(BigDecimal("0"))
      end
    end

    context "with full usage" do
      let(:balance_data) do
        {
          "account-number" => "5WX12345",
          "equity-buying-power" => "10000.00",
          "available-trading-funds" => "0.00"
        }
      end

      it "returns 100%" do
        expect(subject.buying_power_usage_percentage).to eq(BigDecimal("100.00"))
      end
    end

    context "with high precision" do
      let(:balance_data) do
        {
          "account-number" => "5WX12345",
          "equity-buying-power" => "10000.00",
          "available-trading-funds" => "3333.33"
        }
      end

      it "rounds to 2 decimal places" do
        # Used BP = 10000 - 3333.33 = 6666.67
        # Percentage = 6666.67 / 10000 * 100 = 66.6667
        expect(subject.buying_power_usage_percentage).to eq(BigDecimal("66.67"))
      end
    end
  end

  describe "#high_buying_power_usage?" do
    context "with default threshold (80%)" do
      it "returns false when usage is below 80%" do
        expect(subject.high_buying_power_usage?).to be false
      end

      context "with high usage" do
        let(:balance_data) do
          {
            "account-number" => "5WX12345",
            "equity-buying-power" => "10000.00",
            "available-trading-funds" => "1500.00"
          }
        end

        it "returns true when usage is above 80%" do
          # Usage = 85%
          expect(subject.high_buying_power_usage?).to be true
        end
      end
    end

    context "with custom threshold" do
      it "uses the provided threshold" do
        expect(subject.high_buying_power_usage?(30)).to be true
        expect(subject.high_buying_power_usage?(50)).to be false
      end
    end
  end

  describe "#total_equity_value" do
    it "sums long and short equity values" do
      # 25000.75 + 5000.25 = 30001.00
      expect(subject.total_equity_value).to eq(BigDecimal("30001.00"))
    end
  end

  describe "#total_derivative_value" do
    it "sums long and short derivative values" do
      # 3000.00 + 1500.00 = 4500.00
      expect(subject.total_derivative_value).to eq(BigDecimal("4500.00"))
    end
  end

  describe "#total_market_value" do
    it "sums all market values" do
      # 30001.00 + 4500.00 = 34501.00
      expect(subject.total_market_value).to eq(BigDecimal("34501.00"))
    end
  end

  describe "attribute readers" do
    it "provides access to all balance fields" do
      expect(subject).to respond_to(:account_number)
      expect(subject).to respond_to(:cash_balance)
      expect(subject).to respond_to(:long_equity_value)
      expect(subject).to respond_to(:short_equity_value)
      expect(subject).to respond_to(:long_derivative_value)
      expect(subject).to respond_to(:short_derivative_value)
      expect(subject).to respond_to(:net_liquidating_value)
      expect(subject).to respond_to(:equity_buying_power)
      expect(subject).to respond_to(:derivative_buying_power)
      expect(subject).to respond_to(:day_trading_buying_power)
      expect(subject).to respond_to(:available_trading_funds)
      expect(subject).to respond_to(:margin_equity)
      expect(subject).to respond_to(:pending_cash)
      expect(subject).to respond_to(:pending_margin_interest)
      expect(subject).to respond_to(:effective_trading_funds)
      expect(subject).to respond_to(:updated_at)
    end
  end

  describe "BigDecimal precision" do
    let(:balance_data) do
      {
        "account-number" => "5WX12345",
        "cash-balance" => "0.01",
        "net-liquidating-value" => "999999.99",
        "equity-buying-power" => "123456.789",
        "available-trading-funds" => "0.001"
      }
    end

    it "handles small values correctly" do
      expect(subject.cash_balance).to eq(BigDecimal("0.01"))
      expect(subject.available_trading_funds).to eq(BigDecimal("0.001"))
    end

    it "handles large values correctly" do
      expect(subject.net_liquidating_value).to eq(BigDecimal("999999.99"))
    end

    it "maintains precision beyond 2 decimal places" do
      expect(subject.equity_buying_power).to eq(BigDecimal("123456.789"))
    end
  end

  describe "#derivative_buying_power_usage_percentage" do
    it "calculates derivative BP usage correctly" do
      # Used BP = 15000 - 12000 = 3000
      # Percentage = 3000 / 15000 * 100 = 20%
      expect(subject.derivative_buying_power_usage_percentage).to eq(BigDecimal("20.00"))
    end

    context "with zero derivative buying power" do
      let(:balance_data) do
        {
          "account-number" => "5WX12345",
          "derivative-buying-power" => "0",
          "available-trading-funds" => "0"
        }
      end

      it "returns zero" do
        expect(subject.derivative_buying_power_usage_percentage).to eq(BigDecimal("0"))
      end
    end
  end

  describe "#day_trading_buying_power_usage_percentage" do
    it "calculates day trading BP usage correctly" do
      # Used BP = 40000 - 12000 = 28000
      # Percentage = 28000 / 40000 * 100 = 70%
      expect(subject.day_trading_buying_power_usage_percentage).to eq(BigDecimal("70.00"))
    end
  end

  describe "#minimum_buying_power" do
    it "returns the smallest buying power value" do
      # Min of 20000, 15000, 40000 = 15000
      expect(subject.minimum_buying_power).to eq(BigDecimal("15000.00"))
    end
  end

  describe "#sufficient_buying_power?" do
    context "with equity buying power" do
      it "returns true when amount is less than available BP" do
        expect(subject.sufficient_buying_power?(10000)).to be true
        expect(subject.sufficient_buying_power?("10000.00")).to be true
      end

      it "returns false when amount exceeds available BP" do
        expect(subject.sufficient_buying_power?(25000)).to be false
      end

      it "returns true when amount equals available BP" do
        expect(subject.sufficient_buying_power?(20000)).to be true
      end
    end

    context "with derivative buying power" do
      it "checks against derivative BP when specified" do
        expect(subject.sufficient_buying_power?(10000, buying_power_type: :derivative)).to be true
        expect(subject.sufficient_buying_power?(20000, buying_power_type: :derivative)).to be false
      end
    end

    context "with day trading buying power" do
      it "checks against day trading BP when specified" do
        expect(subject.sufficient_buying_power?(35000, buying_power_type: :day_trading)).to be true
        expect(subject.sufficient_buying_power?(45000, buying_power_type: :day_trading)).to be false
      end
    end
  end

  describe "#buying_power_impact_percentage" do
    context "with equity buying power" do
      it "calculates impact percentage correctly" do
        # 5000 / 20000 * 100 = 25%
        expect(subject.buying_power_impact_percentage(5000)).to eq(BigDecimal("25.00"))
      end

      it "handles string amounts" do
        expect(subject.buying_power_impact_percentage("5000.00")).to eq(BigDecimal("25.00"))
      end
    end

    context "with derivative buying power" do
      it "calculates against derivative BP when specified" do
        # 3000 / 15000 * 100 = 20%
        expect(subject.buying_power_impact_percentage(3000, buying_power_type: :derivative))
          .to eq(BigDecimal("20.00"))
      end
    end

    context "with zero buying power" do
      let(:balance_data) do
        {
          "account-number" => "5WX12345",
          "equity-buying-power" => "0",
          "available-trading-funds" => "0"
        }
      end

      it "returns zero" do
        expect(subject.buying_power_impact_percentage(1000)).to eq(BigDecimal("0"))
      end
    end
  end
end
