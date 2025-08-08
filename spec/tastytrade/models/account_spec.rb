# frozen_string_literal: true

require "spec_helper"
require "bigdecimal"

RSpec.describe Tastytrade::Models::Account do
  # Tests for pure Ruby object behavior (no API calls)
  describe "attributes (pure Ruby)" do
    let(:account_data) do
      {
        "account-number" => "5WT0001",
        "nickname" => "My Account",
        "account-type-name" => "Individual",
        "opened-at" => "2025-01-01T10:00:00Z",
        "is-closed" => false,
        "day-trader-status" => false,
        "is-futures-approved" => true,
        "margin-or-cash" => "Margin",
        "is-foreign" => false,
        "created-at" => "2025-01-01T10:00:00Z",
        "is-test-drive" => false
      }
    end

    subject(:account) { described_class.new(account_data) }
    it "parses account number" do
      expect(account.account_number).to eq("5WT0001")
    end

    it "parses nickname" do
      expect(account.nickname).to eq("My Account")
    end

    it "parses account type" do
      expect(account.account_type_name).to eq("Individual")
    end

    it "parses opened_at as Time" do
      expect(account.opened_at).to be_a(Time)
      expect(account.opened_at.year).to eq(2025)
    end

    it "parses boolean fields" do
      expect(account.is_closed).to be false
      expect(account.day_trader_status).to be false
      expect(account.is_futures_approved).to be true
    end

    it "parses optional fields" do
      expect(account.external_id).to be_nil
      expect(account.closed_at).to be_nil
    end
  end

  # Tests that make real API calls (using VCR)
  describe "API interactions", :vcr do
    let(:username) { ENV.fetch("TASTYTRADE_SANDBOX_USERNAME", nil) }
    let(:password) { ENV.fetch("TASTYTRADE_SANDBOX_PASSWORD", nil) }
    let(:account_number) { ENV.fetch("TASTYTRADE_SANDBOX_ACCOUNT", nil) }
    let!(:session) do
      sess = Tastytrade::Session.new(username: username, password: password, is_test: true)
      sess.login if username && password
      sess
    end
    let(:account) do
      # Lazy load account only when needed
      @account ||= described_class.get(session, account_number)
    end

    before do
      skip "Missing sandbox credentials" unless username && password && account_number
    end

    describe ".get_all" do
      it "returns array of Account objects" do
        with_market_hours_check("account/get_all") do
          accounts = described_class.get_all(session)

          expect(accounts).to be_an(Array)
          expect(accounts).not_to be_empty
          expect(accounts.first).to be_a(described_class)
          expect(accounts.first.account_number).not_to be_nil
        end
      end

      it "includes closed accounts when specified" do
        with_market_hours_check("account/get_all_with_closed") do
          accounts = described_class.get_all(session, include_closed: true)
          expect(accounts).to be_an(Array)
        end
      end
    end

    describe ".get" do
      it "returns single Account object" do
        with_market_hours_check("account/get_single") do
          fetched_account = described_class.get(session, account_number)

          expect(fetched_account).to be_a(described_class)
          expect(fetched_account.account_number).to eq(account_number)
          expect(fetched_account.nickname).not_to be_nil
        end
      end
    end

    describe "#get_balances" do
      it "returns balance data" do
        with_market_hours_check("account/get_balances") do
          balance = account.get_balances(session)

          expect(balance).to be_a(Tastytrade::Models::AccountBalance)
          expect(balance.account_number).to eq(account_number)
          expect(balance.cash_balance).to be_a(BigDecimal)
          expect(balance.net_liquidating_value).to be_a(BigDecimal)
        end
      end
    end

    describe "#get_positions" do
      it "returns array of positions" do
        with_market_hours_check("account/get_positions") do
          positions = account.get_positions(session)

          expect(positions).to be_an(Array)
          # Positions might be empty in sandbox
          if positions.any?
            expect(positions.first).to be_a(Tastytrade::Models::CurrentPosition)
            expect(positions.first.symbol).not_to be_nil
          end
        end
      end

      it "filters positions by symbol" do
        with_market_hours_check("account/get_positions_filtered") do
          positions = account.get_positions(session, symbol: "SPY")
          expect(positions).to be_an(Array)
        end
      end
    end

    describe "#get_trading_status" do
      it "returns a TradingStatus object" do
        with_market_hours_check("account/get_trading_status") do
          status = account.get_trading_status(session)

          expect(status).to be_a(Tastytrade::Models::TradingStatus)
          expect(status.account_number).to eq(account_number)
          expect(status.options_level).not_to be_nil
        end
      end
    end

    describe "#get_transactions" do
      it "fetches transactions for the account" do
        with_market_hours_check("account/get_transactions") do
          transactions = account.get_transactions(session)

          expect(transactions).to be_an(Array)
          # Transactions might be empty in new sandbox account
          if transactions.any?
            expect(transactions.first).to be_a(Tastytrade::Models::Transaction)
          end
        end
      end

      it "filters transactions by date range" do
        with_market_hours_check("account/get_transactions_filtered") do
          start_date = Date.today - 30
          end_date = Date.today

          transactions = account.get_transactions(
            session,
            start_date: start_date,
            end_date: end_date
          )

          expect(transactions).to be_an(Array)
        end
      end
    end

    describe "#get_live_orders" do
      it "returns array of live orders" do
        with_market_hours_check("account/get_live_orders") do
          orders = account.get_live_orders(session)

          expect(orders).to be_an(Array)
          # Orders might be empty
          if orders.any?
            expect(orders.first).to be_a(Tastytrade::Models::LiveOrder)
          end
        end
      end
    end

    describe "#get_order_history" do
      it "returns historical orders" do
        with_market_hours_check("account/get_order_history") do
          orders = account.get_order_history(session)

          expect(orders).to be_an(Array)
          # History might be empty
          if orders.any?
            expect(orders.first).to be_a(Tastytrade::Models::LiveOrder)
          end
        end
      end
    end
  end

  describe ".get" do
    let(:response) do
      { "data" => account_data }
    end

    it "returns single Account object" do
      allow(session).to receive(:get).with("/accounts/5WT0001/").and_return(response)

      account = described_class.get(session, "5WT0001")

      expect(account).to be_a(described_class)
      expect(account.account_number).to eq("5WT0001")
    end
  end

  describe "#get_balances" do
    let(:balance_data) do
      {
        "data" => {
          "account-number" => "5WT0001",
          "cash-balance" => "10000.00",
          "net-liquidating-value" => "15000.00"
        }
      }
    end

    it "returns balance data" do
      allow(session).to receive(:get).with("/accounts/5WT0001/balances/").and_return(balance_data)

      balance = account.get_balances(session)

      expect(balance).to be_a(Tastytrade::Models::AccountBalance)
      expect(balance.account_number).to eq("5WT0001")
      expect(balance.cash_balance).to eq(BigDecimal("10000.00"))
      expect(balance.net_liquidating_value).to eq(BigDecimal("15000.00"))
    end
  end

  describe "#get_positions" do
    let(:positions_data) do
      {
        "data" => {
          "items" => [
            { "symbol" => "AAPL", "quantity" => "100" },
            { "symbol" => "MSFT", "quantity" => "50" }
          ]
        }
      }
    end

    it "returns array of positions" do
      allow(session).to receive(:get).with("/accounts/5WT0001/positions/", {}).and_return(positions_data)

      positions = account.get_positions(session)

      expect(positions).to be_an(Array)
      expect(positions.size).to eq(2)
      expect(positions.first).to be_a(Tastytrade::Models::CurrentPosition)
      expect(positions.first.symbol).to eq("AAPL")
      expect(positions.first.quantity).to eq(BigDecimal("100"))
    end
  end

  describe "#get_trading_status" do
    let(:status_data) do
      {
        "data" => {
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
          "updated-at" => "2024-01-15T10:30:00Z"
        }
      }
    end

    it "returns a TradingStatus object" do
      allow(session).to receive(:get).with("/accounts/5WT0001/trading-status/").and_return(status_data)

      status = account.get_trading_status(session)

      expect(status).to be_a(Tastytrade::Models::TradingStatus)
      expect(status.account_number).to eq("5WT0001")
      expect(status.is_pattern_day_trader).to eq(false)
      expect(status.options_level).to eq("Level 2")
    end
  end

  describe "boolean helper methods" do
    describe "#closed?" do
      it "returns true when is_closed is true" do
        account = described_class.new(account_data.merge("is-closed" => true))
        expect(account.closed?).to be true
      end

      it "returns false when is_closed is false" do
        expect(account.closed?).to be false
      end
    end

    describe "#futures_approved?" do
      it "returns true when is_futures_approved is true" do
        expect(account.futures_approved?).to be true
      end
    end

    describe "#test_drive?" do
      it "returns false when is_test_drive is false" do
        expect(account.test_drive?).to be false
      end
    end

    describe "#foreign?" do
      it "returns false when is_foreign is false" do
        expect(account.foreign?).to be false
      end
    end
  end
end
