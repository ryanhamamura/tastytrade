# frozen_string_literal: true

require "spec_helper"

RSpec.describe Tastytrade::Models::Transaction do
  # Pure Ruby tests (no API calls)
  describe "attributes (pure Ruby)" do
    let(:transaction_data) do
      {
        "id" => 252640963,
        "account-number" => "5WT0001",
        "symbol" => "AAPL",
        "instrument-type" => "Equity",
        "underlying-symbol" => "AAPL",
        "transaction-type" => "Trade",
        "transaction-sub-type" => "Buy",
        "description" => "Bought 100 AAPL @ 150.00",
        "action" => "Buy to Open",
        "quantity" => "100",
        "price" => "150.00",
        "executed-at" => "2023-07-28T21:00:00.000+00:00",
        "transaction-date" => "2023-07-28",
        "value" => "-15000.00",
        "value-effect" => "Debit",
        "net-value" => "-15007.00",
        "net-value-effect" => "Debit",
        "is-estimated-fee" => false,
        "commission" => "5.00",
        "clearing-fees" => "1.00",
        "regulatory-fees" => "0.50",
        "proprietary-index-option-fees" => "0.50",
        "order-id" => "12345",
        "value-date" => "2023-07-30",
        "reverses-id" => nil,
        "is-verified" => true
      }
    end

    subject(:transaction) { described_class.new(transaction_data) }

    it "parses basic attributes" do
      expect(transaction.id).to eq(252640963)
      expect(transaction.account_number).to eq("5WT0001")
      expect(transaction.symbol).to eq("AAPL")
      expect(transaction.instrument_type).to eq("Equity")
    end

    it "parses transaction details" do
      expect(transaction.transaction_type).to eq("Trade")
      expect(transaction.transaction_sub_type).to eq("Buy")
      expect(transaction.description).to eq("Bought 100 AAPL @ 150.00")
      expect(transaction.action).to eq("Buy to Open")
    end

    it "parses numeric values as BigDecimal" do
      expect(transaction.quantity).to eq(BigDecimal("100"))
      expect(transaction.price).to eq(BigDecimal("150.00"))
      expect(transaction.value).to eq(BigDecimal("-15000.00"))
      expect(transaction.net_value).to eq(BigDecimal("-15007.00"))
    end

    it "parses fee values" do
      expect(transaction.commission).to eq(BigDecimal("5.00"))
      expect(transaction.clearing_fees).to eq(BigDecimal("1.00"))
      expect(transaction.regulatory_fees).to eq(BigDecimal("0.50"))
      expect(transaction.proprietary_index_option_fees).to eq(BigDecimal("0.50"))
    end

    it "parses dates and times" do
      expect(transaction.executed_at).to be_a(Time)
      expect(transaction.transaction_date).to eq(Date.parse("2023-07-28"))
      expect(transaction.value_date).to eq(Date.parse("2023-07-30"))
    end

    it "parses boolean and optional fields" do
      expect(transaction.is_estimated_fee).to eq(false)
      expect(transaction.is_verified).to eq(true)
      expect(transaction.reverses_id).to be_nil
    end
  end

  # Real API tests using VCR
  describe "API interactions", :vcr do
    let(:username) { ENV.fetch("TASTYTRADE_SANDBOX_USERNAME", nil) }
    let(:password) { ENV.fetch("TASTYTRADE_SANDBOX_PASSWORD", nil) }
    let(:account_number) { ENV.fetch("TASTYTRADE_SANDBOX_ACCOUNT", nil) }
    let(:session) do
      sess = Tastytrade::Session.new(username: username, password: password, is_test: true)
      sess.login if username && password
      sess
    end

    before do
      skip "Missing sandbox credentials" unless username && password && account_number
    end

    describe ".get_all" do
      it "fetches transactions without filters" do
        with_market_hours_check("transaction/get_all") do
          transactions = described_class.get_all(session, account_number)

          expect(transactions).to be_an(Array)
          # Transactions might be empty in new sandbox account
          if transactions.any?
            expect(transactions.first).to be_a(described_class)
            expect(transactions.first.account_number).to eq(account_number)
          end
        end
      end

      it "fetches transactions with date filter" do
        with_market_hours_check("transaction/get_all_with_dates") do
          start_date = Date.today - 30
          end_date = Date.today

          transactions = described_class.get_all(
            session,
            account_number,
            start_date: start_date,
            end_date: end_date
          )

          expect(transactions).to be_an(Array)

          # If there are transactions, verify they're within date range
          if transactions.any?
            transactions.each do |transaction|
              if transaction.transaction_date
                expect(transaction.transaction_date).to be >= start_date
                expect(transaction.transaction_date).to be <= end_date
              end
            end
          end
        end
      end

      it "fetches transactions with symbol filter" do
        with_market_hours_check("transaction/get_all_with_symbol") do
          transactions = described_class.get_all(
            session,
            account_number,
            symbol: "SPY"
          )

          expect(transactions).to be_an(Array)

          # If there are transactions, verify they match the symbol
          if transactions.any?
            transactions.each do |transaction|
              expect(transaction.symbol).to eq("SPY") if transaction.symbol
            end
          end
        end
      end

      it "fetches transactions with transaction type filter" do
        with_market_hours_check("transaction/get_all_with_type") do
          transactions = described_class.get_all(
            session,
            account_number,
            transaction_types: ["Trade"]
          )

          expect(transactions).to be_an(Array)

          # If there are transactions, verify they match the type
          if transactions.any?
            transactions.each do |transaction|
              expect(transaction.transaction_type).to eq("Trade")
            end
          end
        end
      end

      it "handles pagination" do
        with_market_hours_check("transaction/get_all_paginated") do
          # Request only 5 transactions per page
          transactions = described_class.get_all(
            session,
            account_number,
            per_page: 5
          )

          expect(transactions).to be_an(Array)
          # Should have at most 5 transactions
          expect(transactions.size).to be <= 5 if transactions.any?
        end
      end

      it "fetches transactions with multiple filters" do
        with_market_hours_check("transaction/get_all_multiple_filters") do
          transactions = described_class.get_all(
            session,
            account_number,
            start_date: Date.today - 90,
            end_date: Date.today,
            instrument_type: "Equity",
            per_page: 10
          )

          expect(transactions).to be_an(Array)

          if transactions.any?
            expect(transactions.size).to be <= 10
            transactions.each do |transaction|
              expect(transaction.instrument_type).to eq("Equity") if transaction.instrument_type
            end
          end
        end
      end
    end
  end
end
