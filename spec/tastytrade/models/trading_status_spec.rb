# frozen_string_literal: true

require "spec_helper"

RSpec.describe Tastytrade::Models::TradingStatus do
  let(:trading_status_data) do
    {
      "account-number" => "5WT0001",
      "equities-margin-calculation-type" => "REG_T",
      "fee-schedule-name" => "standard",
      "futures-margin-rate-multiplier" => "1.0",
      "has-intraday-equities-margin" => false,
      "id" => 123456,
      "is-aggregated-at-clearing" => false,
      "is-closed" => false,
      "is-closing-only" => false,
      "is-cryptocurrency-enabled" => true,
      "is-frozen" => false,
      "is-full-equity-margin-required" => false,
      "is-futures-closing-only" => false,
      "is-futures-intra-day-enabled" => true,
      "is-futures-enabled" => true,
      "is-in-day-trade-equity-maintenance-call" => false,
      "is-in-margin-call" => false,
      "is-pattern-day-trader" => false,
      "is-small-notional-futures-intra-day-enabled" => false,
      "is-roll-the-day-forward-enabled" => true,
      "are-far-otm-net-options-restricted" => false,
      "options-level" => "Level 2",
      "short-calls-enabled" => false,
      "small-notional-futures-margin-rate-multiplier" => "1.0",
      "is-equity-offering-enabled" => true,
      "is-equity-offering-closing-only" => false,
      "updated-at" => "2024-01-15T10:30:00Z",
      "is-portfolio-margin-enabled" => false,
      "is-risk-reducing-only" => nil,
      "day-trade-count" => 0,
      "autotrade-account-type" => nil,
      "clearing-account-number" => nil,
      "clearing-aggregation-identifier" => nil,
      "is-cryptocurrency-closing-only" => false,
      "pdt-reset-on" => nil,
      "cmta-override" => nil,
      "enhanced-fraud-safeguards-enabled-at" => nil
    }
  end

  subject(:trading_status) { described_class.new(trading_status_data) }

  describe "#initialize" do
    it "parses all required fields correctly" do
      expect(trading_status.account_number).to eq("5WT0001")
      expect(trading_status.equities_margin_calculation_type).to eq("REG_T")
      expect(trading_status.fee_schedule_name).to eq("standard")
      expect(trading_status.futures_margin_rate_multiplier).to eq(BigDecimal("1.0"))
      expect(trading_status.has_intraday_equities_margin).to eq(false)
      expect(trading_status.id).to eq(123456)
      expect(trading_status.is_aggregated_at_clearing).to eq(false)
      expect(trading_status.is_closed).to eq(false)
      expect(trading_status.is_closing_only).to eq(false)
      expect(trading_status.is_cryptocurrency_enabled).to eq(true)
      expect(trading_status.is_frozen).to eq(false)
      expect(trading_status.is_full_equity_margin_required).to eq(false)
      expect(trading_status.is_futures_closing_only).to eq(false)
      expect(trading_status.is_futures_intra_day_enabled).to eq(true)
      expect(trading_status.is_futures_enabled).to eq(true)
      expect(trading_status.is_in_day_trade_equity_maintenance_call).to eq(false)
      expect(trading_status.is_in_margin_call).to eq(false)
      expect(trading_status.is_pattern_day_trader).to eq(false)
      expect(trading_status.options_level).to eq("Level 2")
      expect(trading_status.short_calls_enabled).to eq(false)
      expect(trading_status.updated_at).to be_a(Time)
    end

    it "parses optional fields correctly" do
      expect(trading_status.is_portfolio_margin_enabled).to eq(false)
      expect(trading_status.is_risk_reducing_only).to be_nil
      expect(trading_status.day_trade_count).to eq(0)
      expect(trading_status.is_cryptocurrency_closing_only).to eq(false)
    end

    context "with PDT reset date" do
      let(:trading_status_data_with_pdt) do
        trading_status_data.merge("pdt-reset-on" => "2024-02-15")
      end

      subject(:trading_status_with_pdt) { described_class.new(trading_status_data_with_pdt) }

      it "parses the PDT reset date correctly" do
        expect(trading_status_with_pdt.pdt_reset_on).to be_a(Date)
        expect(trading_status_with_pdt.pdt_reset_on.to_s).to eq("2024-02-15")
      end
    end
  end

  describe "#can_trade_options?" do
    context "when options are enabled" do
      it "returns true" do
        expect(trading_status.can_trade_options?).to eq(true)
      end
    end

    context "when options level is 'No Permissions'" do
      before { trading_status_data["options-level"] = "No Permissions" }

      it "returns false" do
        expect(trading_status.can_trade_options?).to eq(false)
      end
    end

    context "when options level is nil" do
      before { trading_status_data["options-level"] = nil }

      it "returns false" do
        expect(trading_status.can_trade_options?).to eq(false)
      end
    end
  end

  describe "#can_trade_futures?" do
    context "when futures are enabled and not closing only" do
      it "returns true" do
        expect(trading_status.can_trade_futures?).to eq(true)
      end
    end

    context "when futures are disabled" do
      before { trading_status_data["is-futures-enabled"] = false }

      it "returns false" do
        expect(trading_status.can_trade_futures?).to eq(false)
      end
    end

    context "when futures are closing only" do
      before { trading_status_data["is-futures-closing-only"] = true }

      it "returns false" do
        expect(trading_status.can_trade_futures?).to eq(false)
      end
    end
  end

  describe "#can_trade_cryptocurrency?" do
    context "when crypto is enabled and not closing only" do
      it "returns true" do
        expect(trading_status.can_trade_cryptocurrency?).to eq(true)
      end
    end

    context "when crypto is disabled" do
      before { trading_status_data["is-cryptocurrency-enabled"] = false }

      it "returns false" do
        expect(trading_status.can_trade_cryptocurrency?).to eq(false)
      end
    end

    context "when crypto is closing only" do
      before { trading_status_data["is-cryptocurrency-closing-only"] = true }

      it "returns false" do
        expect(trading_status.can_trade_cryptocurrency?).to eq(false)
      end
    end
  end

  describe "#restricted?" do
    context "when account has no restrictions" do
      it "returns false" do
        expect(trading_status.restricted?).to eq(false)
      end
    end

    context "when account is closed" do
      before { trading_status_data["is-closed"] = true }

      it "returns true" do
        expect(trading_status.restricted?).to eq(true)
      end
    end

    context "when account is frozen" do
      before { trading_status_data["is-frozen"] = true }

      it "returns true" do
        expect(trading_status.restricted?).to eq(true)
      end
    end

    context "when account is in margin call" do
      before { trading_status_data["is-in-margin-call"] = true }

      it "returns true" do
        expect(trading_status.restricted?).to eq(true)
      end
    end

    context "when account is risk reducing only" do
      before { trading_status_data["is-risk-reducing-only"] = true }

      it "returns true" do
        expect(trading_status.restricted?).to eq(true)
      end
    end
  end

  describe "#active_restrictions" do
    context "when account has no restrictions" do
      it "returns an empty array" do
        expect(trading_status.active_restrictions).to eq([])
      end
    end

    context "when account has multiple restrictions" do
      before do
        trading_status_data["is-in-margin-call"] = true
        trading_status_data["is-pattern-day-trader"] = true
        trading_status_data["is-futures-closing-only"] = true
      end

      it "returns all active restrictions" do
        restrictions = trading_status.active_restrictions
        expect(restrictions).to include("Margin Call")
        expect(restrictions).to include("Pattern Day Trader")
        expect(restrictions).to include("Futures Closing Only")
      end
    end
  end

  describe "#permissions_summary" do
    it "returns a summary of all trading permissions" do
      summary = trading_status.permissions_summary
      expect(summary[:options]).to eq("Level 2")
      expect(summary[:futures]).to eq("Enabled")
      expect(summary[:cryptocurrency]).to eq("Enabled")
      expect(summary[:short_calls]).to eq("Disabled")
      expect(summary[:pattern_day_trader]).to eq("No")
      expect(summary[:portfolio_margin]).to eq("Disabled")
    end

    context "when futures are closing only" do
      before { trading_status_data["is-futures-closing-only"] = true }

      it "shows futures as closing only" do
        summary = trading_status.permissions_summary
        expect(summary[:futures]).to eq("Closing Only")
      end
    end

    context "when pattern day trader is flagged" do
      before { trading_status_data["is-pattern-day-trader"] = true }

      it "shows PDT as Yes" do
        summary = trading_status.permissions_summary
        expect(summary[:pattern_day_trader]).to eq("Yes")
      end
    end
  end
end
