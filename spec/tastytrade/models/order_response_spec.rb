# frozen_string_literal: true

RSpec.describe Tastytrade::Models::OrderResponse do
  let(:order_response_data) do
    {
      "id" => "123456",
      "account-number" => "5WX12345",
      "status" => "Filled",
      "buying-power-effect" => "-15050.00",
      "fee-calculation" => {
        "total-fees" => "0.65",
        "regulatory-fees" => "0.01"
      },
      "price" => "150.50",
      "price-effect" => "Debit",
      "value" => "-15050.00",
      "value-effect" => "Debit",
      "time-in-force" => "Day",
      "order-type" => "Limit",
      "cancellable" => false,
      "editable" => false,
      "edited" => false,
      "warnings" => [],
      "errors" => [],
      "legs" => [
        {
          "action" => "Buy to Open",
          "symbol" => "AAPL",
          "quantity" => 100,
          "instrument-type" => "Equity",
          "remaining-quantity" => 0,
          "fills" => [],
          "execution-price" => "150.50"
        }
      ],
      "updated-at" => "2023-01-01T10:00:00Z",
      "created-at" => "2023-01-01T09:59:00Z"
    }
  end

  describe "#initialize" do
    it "parses all order response attributes" do
      response = described_class.new(order_response_data)

      expect(response.order_id).to eq("123456")
      expect(response.account_number).to eq("5WX12345")
      expect(response.status).to eq("Filled")
      expect(response.buying_power_effect).to eq(BigDecimal("-15050.00"))
      expect(response.fee_calculations).to be_a(Hash)
      expect(response.price).to eq(BigDecimal("150.50"))
      expect(response.price_effect).to eq("Debit")
      expect(response.value).to eq(BigDecimal("-15050.00"))
      expect(response.value_effect).to eq("Debit")
      expect(response.time_in_force).to eq("Day")
      expect(response.order_type).to eq("Limit")
      expect(response.cancellable).to be false
      expect(response.editable).to be false
      expect(response.edited).to be false
      expect(response.warnings).to be_empty
      expect(response.errors).to be_empty
      expect(response.legs).to be_an(Array)
      expect(response.updated_at).to be_a(Time)
      expect(response.created_at).to be_a(Time)
    end

    it "handles missing optional fields" do
      minimal_data = {
        "id" => "123456",
        "account-number" => "5WX12345",
        "status" => "Pending"
      }

      response = described_class.new(minimal_data)
      expect(response.order_id).to eq("123456")
      expect(response.buying_power_effect).to be_nil
      expect(response.price).to be_nil
      expect(response.warnings).to be_empty
      expect(response.legs).to be_empty
    end
  end

  describe "leg parsing" do
    it "parses order legs correctly" do
      response = described_class.new(order_response_data)
      leg = response.legs.first

      expect(leg).to be_a(Tastytrade::Models::OrderLegResponse)
      expect(leg.action).to eq("Buy to Open")
      expect(leg.symbol).to eq("AAPL")
      expect(leg.quantity).to eq(100)
      expect(leg.instrument_type).to eq("Equity")
      expect(leg.remaining_quantity).to eq(0)
      expect(leg.execution_price).to eq(BigDecimal("150.50"))
    end
  end
end
