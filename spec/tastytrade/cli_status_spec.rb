# frozen_string_literal: true

require "spec_helper"
require "tastytrade/cli"

RSpec.describe "Tastytrade::CLI trading_status command" do
  let(:cli) { Tastytrade::CLI.new }
  let(:session) { instance_double(Tastytrade::Session) }
  let(:account) { instance_double(Tastytrade::Models::Account, account_number: "5WT0001") }
  let(:config) { instance_double(Tastytrade::CLIConfig) }

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
      "day-trade-count" => 0
    }
  end

  let(:trading_status) { Tastytrade::Models::TradingStatus.new(trading_status_data) }

  before do
    allow(cli).to receive(:current_session).and_return(session)
    allow(cli).to receive(:current_account).and_return(account)
    allow(cli).to receive(:config).and_return(config)
    allow(config).to receive(:get).with("current_account_number").and_return("5WT0001")
    allow(account).to receive(:get_trading_status).with(session).and_return(trading_status)
  end

  describe "#trading_status" do
    context "when authenticated with default account" do
      it "displays trading status information" do
        expect { cli.trading_status }.to output(/Trading Status for Account:.*5WT0001/).to_stdout
      end

      it "shows no restrictions when account is unrestricted" do
        expect { cli.trading_status }.to output(/✓ No account restrictions/).to_stdout
      end

      it "displays trading permissions" do
        output = capture_stdout { cli.trading_status }
        expect(output).to include("Trading Permissions:")
        expect(output).to include("Options Trading:")
        expect(output).to include("Level 2")
        expect(output).to include("Futures Trading:")
        expect(output).to include("Cryptocurrency:")
      end

      it "displays account characteristics" do
        output = capture_stdout { cli.trading_status }
        expect(output).to include("Account Characteristics:")
        expect(output).to include("Pattern Day Trader:")
      end

      it "displays additional information" do
        output = capture_stdout { cli.trading_status }
        expect(output).to include("Additional Information:")
        expect(output).to include("Fee Schedule:")
        expect(output).to include("standard")
        expect(output).to include("Margin Type:")
        expect(output).to include("REG_T")
      end
    end

    context "when account has restrictions" do
      let(:restricted_status_data) do
        trading_status_data.merge(
          "is-in-margin-call" => true,
          "is-pattern-day-trader" => true,
          "is-futures-closing-only" => true
        )
      end
      let(:restricted_status) { Tastytrade::Models::TradingStatus.new(restricted_status_data) }

      before do
        allow(account).to receive(:get_trading_status).with(session).and_return(restricted_status)
      end

      it "displays account restrictions with warnings" do
        output = capture_stdout { cli.trading_status }
        expect(output).to include("⚠ Account Restrictions:")
        expect(output).to include("• Margin Call")
        expect(output).to include("• Pattern Day Trader")
        expect(output).to include("• Futures Closing Only")
      end

      it "shows futures as closing only" do
        output = capture_stdout { cli.trading_status }
        expect(output).to include("Futures Trading:")
        expect(output).to include("Closing Only")
      end
    end

    context "with specific account option" do
      let(:other_account) { instance_double(Tastytrade::Models::Account, account_number: "5WT0002") }

      before do
        allow(Tastytrade::Models::Account).to receive(:get)
          .with(session, "5WT0002")
          .and_return(other_account)
        allow(other_account).to receive(:get_trading_status).with(session).and_return(trading_status)
        cli.options = { account: "5WT0002" }
      end

      it "uses the specified account" do
        expect(other_account).to receive(:get_trading_status).with(session)
        cli.trading_status
      end
    end

    context "when not authenticated" do
      before do
        allow(cli).to receive(:current_session).and_return(nil)
      end

      it "requires authentication" do
        expect { cli.trading_status }.to raise_error(SystemExit)
          .and output(/You must be logged in/).to_stderr
      end
    end

    context "when API call fails" do
      before do
        allow(account).to receive(:get_trading_status)
          .and_raise(Tastytrade::Error, "API error")
      end

      it "handles errors gracefully" do
        expect { cli.trading_status }.to raise_error(SystemExit)
          .and output(/Failed to fetch trading status/).to_stderr
      end
    end

    context "with PDT information" do
      let(:pdt_status_data) do
        trading_status_data.merge(
          "is-pattern-day-trader" => true,
          "day-trade-count" => 3,
          "pdt-reset-on" => "2024-02-15"
        )
      end
      let(:pdt_status) { Tastytrade::Models::TradingStatus.new(pdt_status_data) }

      before do
        allow(account).to receive(:get_trading_status).with(session).and_return(pdt_status)
      end

      it "displays PDT information" do
        output = capture_stdout { cli.trading_status }
        expect(output).to include("Pattern Day Trader:")
        expect(output).to include("Yes")
        expect(output).to include("Day Trade Count:")
        expect(output).to include("3")
        expect(output).to include("PDT Reset Date:")
        expect(output).to include("2024-02-15")
      end
    end
  end

  # Helper to capture stdout
  def capture_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end
end
