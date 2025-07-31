# frozen_string_literal: true

require "spec_helper"

RSpec.describe Tastytrade::Models::Account do
  let(:account_data) do
    {
      "account-number" => "123456",
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

  let(:session) { instance_double(Tastytrade::Session) }
  subject(:account) { described_class.new(account_data) }

  describe "attributes" do
    it "parses account number" do
      expect(account.account_number).to eq("123456")
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

  describe ".get_all" do
    let(:response) do
      {
        "data" => {
          "items" => [
            {
              "account" => account_data,
              "authority-level" => "owner"
            },
            {
              "account" => account_data.merge("account-number" => "789012"),
              "authority-level" => "owner"
            }
          ]
        }
      }
    end

    it "returns array of Account objects" do
      allow(session).to receive(:get).with("/customers/me/accounts/", {}).and_return(response)

      accounts = described_class.get_all(session)

      expect(accounts).to be_an(Array)
      expect(accounts.size).to eq(2)
      expect(accounts.first).to be_a(described_class)
      expect(accounts.first.account_number).to eq("123456")
      expect(accounts.last.account_number).to eq("789012")
    end

    it "includes closed accounts when specified" do
      allow(session).to receive(:get).with("/customers/me/accounts/", { "include-closed" => true })
                                     .and_return(response)

      described_class.get_all(session, include_closed: true)
    end
  end

  describe ".get" do
    let(:response) do
      { "data" => account_data }
    end

    it "returns single Account object" do
      allow(session).to receive(:get).with("/accounts/123456/").and_return(response)

      account = described_class.get(session, "123456")

      expect(account).to be_a(described_class)
      expect(account.account_number).to eq("123456")
    end
  end

  describe "#get_balances" do
    let(:balance_data) do
      {
        "data" => {
          "account-number" => "123456",
          "cash-balance" => "10000.00",
          "net-liquidating-value" => "15000.00"
        }
      }
    end

    it "returns balance data" do
      allow(session).to receive(:get).with("/accounts/123456/balances/").and_return(balance_data)

      balances = account.get_balances(session)

      expect(balances).to eq(balance_data["data"])
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
      allow(session).to receive(:get).with("/accounts/123456/positions/").and_return(positions_data)

      positions = account.get_positions(session)

      expect(positions).to be_an(Array)
      expect(positions.size).to eq(2)
      expect(positions.first["symbol"]).to eq("AAPL")
    end
  end

  describe "#get_trading_status" do
    let(:status_data) do
      {
        "data" => {
          "account-number" => "123456",
          "is-pattern-day-trader" => false
        }
      }
    end

    it "returns trading status data" do
      allow(session).to receive(:get).with("/accounts/123456/trading-status/").and_return(status_data)

      status = account.get_trading_status(session)

      expect(status).to eq(status_data["data"])
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
