# frozen_string_literal: true

RSpec.describe "Order edge cases and additional coverage" do
  describe Tastytrade::Order do
    describe "edge cases" do
      it "accepts multiple legs" do
        leg1 = Tastytrade::OrderLeg.new(
          action: Tastytrade::OrderAction::BUY_TO_OPEN,
          symbol: "AAPL",
          quantity: 100
        )

        leg2 = Tastytrade::OrderLeg.new(
          action: Tastytrade::OrderAction::BUY_TO_OPEN,
          symbol: "MSFT",
          quantity: 50
        )

        order = Tastytrade::Order.new(
          type: Tastytrade::OrderType::MARKET,
          legs: [leg1, leg2]
        )

        expect(order.legs).to eq([leg1, leg2])
        params = order.to_api_params
        expect(params["legs"]).to have_attributes(size: 2)
      end

      it "handles GTC time in force" do
        leg = Tastytrade::OrderLeg.new(
          action: Tastytrade::OrderAction::BUY_TO_OPEN,
          symbol: "AAPL",
          quantity: 100
        )

        order = Tastytrade::Order.new(
          type: Tastytrade::OrderType::LIMIT,
          time_in_force: Tastytrade::OrderTimeInForce::GTC,
          legs: leg,
          price: 150
        )

        expect(order.time_in_force).to eq("GTC")
        expect(order.to_api_params["time-in-force"]).to eq("GTC")
      end

      it "handles sell to open orders" do
        leg = Tastytrade::OrderLeg.new(
          action: Tastytrade::OrderAction::SELL_TO_OPEN,
          symbol: "AAPL",
          quantity: 100
        )

        order = Tastytrade::Order.new(
          type: Tastytrade::OrderType::LIMIT,
          legs: leg,
          price: 150
        )

        # Sell orders should have Credit price effect
        expect(order.to_api_params["price-effect"]).to eq("Credit")
      end

      it "handles buy to close orders" do
        leg = Tastytrade::OrderLeg.new(
          action: Tastytrade::OrderAction::BUY_TO_CLOSE,
          symbol: "AAPL",
          quantity: 100
        )

        order = Tastytrade::Order.new(
          type: Tastytrade::OrderType::LIMIT,
          legs: leg,
          price: 150
        )

        # Buy orders should have Debit price effect
        expect(order.to_api_params["price-effect"]).to eq("Debit")
      end
    end
  end

  describe Tastytrade::OrderLeg do
    describe "edge cases" do
      it "converts large quantities correctly" do
        leg = Tastytrade::OrderLeg.new(
          action: Tastytrade::OrderAction::BUY_TO_OPEN,
          symbol: "SPY",
          quantity: 10_000
        )

        expect(leg.quantity).to eq(10_000)
        expect(leg.to_api_params["quantity"]).to eq(10_000)
      end

      it "handles string quantities" do
        leg = Tastytrade::OrderLeg.new(
          action: Tastytrade::OrderAction::BUY_TO_OPEN,
          symbol: "AAPL",
          quantity: "100"
        )

        expect(leg.quantity).to eq(100)
      end
    end
  end

  describe Tastytrade::Models::OrderResponse do
    describe "edge cases" do
      it "handles empty warnings array" do
        response = Tastytrade::Models::OrderResponse.new(
          "warnings" => [],
          "errors" => []
        )

        expect(response.warnings).to eq([])
        expect(response.errors).to eq([])
      end

      it "handles missing legs data" do
        response = Tastytrade::Models::OrderResponse.new({})

        expect(response.legs).to eq([])
      end

      it "handles complex fee calculation structure" do
        response = Tastytrade::Models::OrderResponse.new(
          "fee-calculation" => {
            "total-fees" => "1.50",
            "commission" => "0.65",
            "regulatory-fees" => "0.01",
            "clearing-fees" => "0.84"
          }
        )

        expect(response.fee_calculations).to be_a(Hash)
        expect(response.fee_calculations["total-fees"]).to eq("1.50")
      end
    end
  end

  describe Tastytrade::Instruments::Equity do
    describe "#build_leg" do
      let(:equity) { Tastytrade::Instruments::Equity.new("symbol" => "AAPL") }

      it "builds legs with all action types" do
        [
          Tastytrade::OrderAction::BUY_TO_OPEN,
          Tastytrade::OrderAction::SELL_TO_CLOSE,
          Tastytrade::OrderAction::SELL_TO_OPEN,
          Tastytrade::OrderAction::BUY_TO_CLOSE
        ].each do |action|
          leg = equity.build_leg(action: action, quantity: 100)

          expect(leg.action).to eq(action)
          expect(leg.symbol).to eq("AAPL")
          expect(leg.quantity).to eq(100)
          expect(leg.instrument_type).to eq("Equity")
        end
      end
    end
  end
end
