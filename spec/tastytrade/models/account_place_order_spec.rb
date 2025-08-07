# frozen_string_literal: true

RSpec.describe "Tastytrade::Models::Account#place_order" do
  let(:session) { instance_double(Tastytrade::Session) }
  let(:account) { Tastytrade::Models::Account.new("account-number" => "5WX12345") }

  let(:order_leg) do
    Tastytrade::OrderLeg.new(
      action: Tastytrade::OrderAction::BUY_TO_OPEN,
      symbol: "AAPL",
      quantity: 100
    )
  end

  let(:market_order) do
    Tastytrade::Order.new(
      type: Tastytrade::OrderType::MARKET,
      legs: order_leg
    )
  end

  let(:limit_order) do
    Tastytrade::Order.new(
      type: Tastytrade::OrderType::LIMIT,
      legs: order_leg,
      price: 150.50
    )
  end

  let(:successful_response) do
    {
      "data" => {
        "id" => "123456",
        "account-number" => "5WX12345",
        "status" => "Routed",
        "buying-power-effect" => "-15050.00"
      }
    }
  end

  let(:dry_run_response) do
    {
      "data" => {
        "buying-power-effect" => {
          "impact" => "1.50",
          "change-in-buying-power" => "1.50"
        },
        "warnings" => [
          { "code" => "market_closed", "message" => "Market is closed" }
        ]
      }
    }
  end

  describe "successful order placement" do
    before do
      allow(session).to receive(:post).and_return(successful_response)
    end

    it "places a market order" do
      response = account.place_order(session, market_order, skip_validation: true)

      expect(session).to have_received(:post).with(
        "/accounts/5WX12345/orders",
        market_order.to_api_params
      )

      expect(response).to be_a(Tastytrade::Models::OrderResponse)
      expect(response.order_id).to eq("123456")
      expect(response.status).to eq("Routed")
    end

    it "places a limit order with correct parameters" do
      response = account.place_order(session, limit_order, skip_validation: true)

      expect(session).to have_received(:post).with(
        "/accounts/5WX12345/orders",
        hash_including(
          "order-type" => "Limit",
          "price" => "150.5",
          "price-effect" => "Debit"
        )
      )

      expect(response).to be_a(Tastytrade::Models::OrderResponse)
    end

    it "handles dry run orders" do
      allow(session).to receive(:post).and_return(dry_run_response)

      response = account.place_order(session, market_order, dry_run: true)

      expect(session).to have_received(:post).with(
        "/accounts/5WX12345/orders/dry-run",
        anything
      )

      expect(response.buying_power_effect).to be_a(Tastytrade::Models::BuyingPowerEffect)
      expect(response.buying_power_effect.impact).to eq(BigDecimal("1.50"))
      expect(response.warnings).not_to be_empty
    end
  end

  describe "error handling" do
    it "handles API errors" do
      allow(session).to receive(:post).and_raise(
        Tastytrade::Error, "Invalid symbol"
      )

      expect {
        account.place_order(session, market_order, skip_validation: true)
      }.to raise_error(Tastytrade::Error, "Invalid symbol")
    end

    it "handles network timeouts" do
      allow(session).to receive(:post).and_raise(
        Tastytrade::NetworkTimeoutError, "Request timed out"
      )

      expect {
        account.place_order(session, market_order, skip_validation: true)
      }.to raise_error(Tastytrade::NetworkTimeoutError)
    end
  end
end
