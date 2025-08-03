# frozen_string_literal: true

require "spec_helper"

RSpec.describe Tastytrade::Models::Transaction do
  let(:session) { instance_double(Tastytrade::Session) }
  let(:account_number) { "123456" }

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

  describe ".get_all" do
    let(:response_data) do
      {
        "data" => {
          "items" => [transaction_data]
        }
      }
    end

    it "fetches transactions without filters" do
      # First call returns data
      allow(session).to receive(:get)
        .with("/accounts/#{account_number}/transactions", {})
        .and_return(response_data)
      # Second call returns empty to stop pagination
      allow(session).to receive(:get)
        .with("/accounts/#{account_number}/transactions", { "page-offset" => 1 })
        .and_return({ "data" => { "items" => [] } })

      transactions = described_class.get_all(session, account_number)

      expect(transactions).to be_an(Array)
      expect(transactions.length).to eq(1)
      expect(transactions.first).to be_a(described_class)
    end

    it "applies date filters" do
      start_date = Date.new(2023, 7, 1)
      end_date = Date.new(2023, 7, 31)

      expected_params = {
        "start-date" => "2023-07-01",
        "end-date" => "2023-07-31"
      }

      allow(session).to receive(:get)
        .with("/accounts/#{account_number}/transactions", expected_params)
        .and_return(response_data)
      allow(session).to receive(:get)
        .with("/accounts/#{account_number}/transactions", expected_params.merge("page-offset" => 1))
        .and_return({ "data" => { "items" => [] } })

      transactions = described_class.get_all(session, account_number,
                                             start_date: start_date,
                                             end_date: end_date)

      expect(transactions.length).to eq(1)
    end

    it "applies symbol and instrument type filters" do
      expected_params = {
        "symbol" => "AAPL",
        "instrument-type" => "Equity"
      }

      allow(session).to receive(:get)
        .with("/accounts/#{account_number}/transactions", expected_params)
        .and_return(response_data)
      allow(session).to receive(:get)
        .with("/accounts/#{account_number}/transactions", expected_params.merge("page-offset" => 1))
        .and_return({ "data" => { "items" => [] } })

      transactions = described_class.get_all(session, account_number,
                                             symbol: "AAPL",
                                             instrument_type: "Equity")

      expect(transactions.length).to eq(1)
    end

    it "handles pagination automatically" do
      page1_response = {
        "data" => {
          "items" => [transaction_data]
        }
      }

      page2_response = {
        "data" => {
          "items" => [transaction_data.merge("id" => 252640964)]
        }
      }

      page3_response = {
        "data" => {
          "items" => []
        }
      }

      allow(session).to receive(:get)
        .with("/accounts/#{account_number}/transactions", {})
        .and_return(page1_response)

      allow(session).to receive(:get)
        .with("/accounts/#{account_number}/transactions", { "page-offset" => 1 })
        .and_return(page2_response)

      allow(session).to receive(:get)
        .with("/accounts/#{account_number}/transactions", { "page-offset" => 2 })
        .and_return(page3_response)

      transactions = described_class.get_all(session, account_number)

      expect(transactions.length).to eq(2)
    end

    it "respects manual pagination settings" do
      expected_params = {
        "per-page" => 50,
        "page-offset" => 2
      }

      allow(session).to receive(:get)
        .with("/accounts/#{account_number}/transactions", expected_params)
        .and_return(response_data)

      transactions = described_class.get_all(session, account_number,
                                             per_page: 50,
                                             page_offset: 2)

      expect(transactions.length).to eq(1)
    end
  end

  describe "attribute parsing" do
    let(:transaction) { described_class.new(transaction_data) }

    it "parses basic attributes correctly" do
      expect(transaction.id).to eq(252640963)
      expect(transaction.account_number).to eq("5WT0001")
      expect(transaction.symbol).to eq("AAPL")
      expect(transaction.instrument_type).to eq("Equity")
      expect(transaction.underlying_symbol).to eq("AAPL")
    end

    it "parses transaction type attributes" do
      expect(transaction.transaction_type).to eq("Trade")
      expect(transaction.transaction_sub_type).to eq("Buy")
      expect(transaction.description).to eq("Bought 100 AAPL @ 150.00")
      expect(transaction.action).to eq("Buy to Open")
    end

    it "parses decimal values correctly" do
      expect(transaction.quantity).to be_a(BigDecimal)
      expect(transaction.quantity).to eq(BigDecimal("100"))
      expect(transaction.price).to eq(BigDecimal("150.00"))
      expect(transaction.value).to eq(BigDecimal("-15000.00"))
      expect(transaction.net_value).to eq(BigDecimal("-15007.00"))
    end

    it "parses fee attributes" do
      expect(transaction.commission).to eq(BigDecimal("5.00"))
      expect(transaction.clearing_fees).to eq(BigDecimal("1.00"))
      expect(transaction.regulatory_fees).to eq(BigDecimal("0.50"))
      expect(transaction.proprietary_index_option_fees).to eq(BigDecimal("0.50"))
    end

    it "parses date and time attributes" do
      expect(transaction.executed_at).to be_a(Time)
      expect(transaction.executed_at.year).to eq(2023)
      expect(transaction.transaction_date).to be_a(Date)
      expect(transaction.transaction_date.day).to eq(28)
    end

    it "parses boolean and other attributes" do
      expect(transaction.is_estimated_fee).to eq(false)
      expect(transaction.is_verified).to eq(true)
      expect(transaction.order_id).to eq("12345")
      expect(transaction.reverses_id).to be_nil
    end

    it "handles nil decimal values" do
      data_with_nil = transaction_data.merge("commission" => nil)
      transaction = described_class.new(data_with_nil)
      expect(transaction.commission).to be_nil
    end

    it "handles empty string decimal values" do
      data_with_empty = transaction_data.merge("clearing-fees" => "")
      transaction = described_class.new(data_with_empty)
      expect(transaction.clearing_fees).to be_nil
    end
  end

  describe "constants" do
    it "defines transaction types" do
      expect(described_class::TRANSACTION_TYPES).to include("Dividend")
      expect(described_class::TRANSACTION_TYPES).to include("Fee")
      expect(described_class::TRANSACTION_TYPES).to include("Deposit")
    end

    it "defines instrument types" do
      expect(described_class::INSTRUMENT_TYPES).to include("Equity")
      expect(described_class::INSTRUMENT_TYPES).to include("Equity Option")
      expect(described_class::INSTRUMENT_TYPES).to include("Future")
    end
  end
end
