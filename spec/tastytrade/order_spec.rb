# frozen_string_literal: true

RSpec.describe Tastytrade::OrderLeg do
  describe "#initialize" do
    it "creates a valid order leg" do
      leg = described_class.new(
        action: Tastytrade::OrderAction::BUY_TO_OPEN,
        symbol: "AAPL",
        quantity: 100
      )

      expect(leg.action).to eq(Tastytrade::OrderAction::BUY_TO_OPEN)
      expect(leg.symbol).to eq("AAPL")
      expect(leg.quantity).to eq(100)
      expect(leg.instrument_type).to eq("Equity")
    end

    it "validates action parameter" do
      expect do
        described_class.new(
          action: "INVALID_ACTION",
          symbol: "AAPL",
          quantity: 100
        )
      end.to raise_error(ArgumentError, /Invalid action/)
    end
  end

  describe "#to_api_params" do
    it "converts to API format" do
      leg = described_class.new(
        action: Tastytrade::OrderAction::BUY_TO_OPEN,
        symbol: "AAPL",
        quantity: 100
      )

      params = leg.to_api_params
      expect(params["action"]).to eq("Buy to Open")
      expect(params["symbol"]).to eq("AAPL")
      expect(params["quantity"]).to eq(100)
      expect(params["instrument-type"]).to eq("Equity")
    end
  end

  describe "option leg support" do
    it "creates an option leg with OCC symbol" do
      leg = described_class.new(
        action: Tastytrade::OrderAction::BUY_TO_OPEN,
        symbol: "AAPL 240119C00150000",
        quantity: 1,
        instrument_type: "Option"
      )

      expect(leg.action).to eq(Tastytrade::OrderAction::BUY_TO_OPEN)
      expect(leg.symbol).to eq("AAPL 240119C00150000")
      expect(leg.quantity).to eq(1)
      expect(leg.instrument_type).to eq("Option")
      expect(leg.position_effect).to eq("Opening")
    end

    it "validates OCC symbol format for options" do
      expect do
        described_class.new(
          action: Tastytrade::OrderAction::BUY_TO_OPEN,
          symbol: "INVALID_OPTION",
          quantity: 1,
          instrument_type: "Option"
        )
      end.to raise_error(ArgumentError, /Invalid OCC option symbol format/)
    end

    it "accepts valid OCC symbols" do
      valid_symbols = [
        "AAPL 240119C00150000",
        "SPY 240630P00420000",
        "TSLA 241220C00200000",
        "QQQ 240315P00380000"
      ]

      valid_symbols.each do |symbol|
        expect do
          described_class.new(
            action: Tastytrade::OrderAction::BUY_TO_OPEN,
            symbol: symbol,
            quantity: 1,
            instrument_type: "Option"
          )
        end.not_to raise_error
      end
    end

    it "auto-detects position effect for opening orders" do
      leg = described_class.new(
        action: Tastytrade::OrderAction::SELL_TO_OPEN,
        symbol: "AAPL 240119C00150000",
        quantity: 1,
        instrument_type: "Option"
      )

      expect(leg.position_effect).to eq("Opening")
    end

    it "auto-detects position effect for closing orders" do
      leg = described_class.new(
        action: Tastytrade::OrderAction::SELL_TO_CLOSE,
        symbol: "AAPL 240119C00150000",
        quantity: 1,
        instrument_type: "Option"
      )

      expect(leg.position_effect).to eq("Closing")
    end

    it "allows explicit position effect override" do
      leg = described_class.new(
        action: Tastytrade::OrderAction::BUY_TO_OPEN,
        symbol: "AAPL 240119C00150000",
        quantity: 1,
        instrument_type: "Option",
        position_effect: "Auto"
      )

      expect(leg.position_effect).to eq("Auto")
    end

    it "validates position effect values" do
      expect do
        described_class.new(
          action: Tastytrade::OrderAction::BUY_TO_OPEN,
          symbol: "AAPL 240119C00150000",
          quantity: 1,
          instrument_type: "Option",
          position_effect: "INVALID"
        )
      end.to raise_error(ArgumentError, /Invalid position effect/)
    end

    it "includes position effect in API params for options" do
      leg = described_class.new(
        action: Tastytrade::OrderAction::BUY_TO_OPEN,
        symbol: "AAPL 240119C00150000",
        quantity: 1,
        instrument_type: "Option",
        position_effect: "Opening"
      )

      params = leg.to_api_params
      expect(params["position-effect"]).to eq("Opening")
    end

    it "excludes position effect for equity orders" do
      leg = described_class.new(
        action: Tastytrade::OrderAction::BUY_TO_OPEN,
        symbol: "AAPL",
        quantity: 100,
        instrument_type: "Equity"
      )

      params = leg.to_api_params
      expect(params).not_to have_key("position-effect")
    end
  end
end

RSpec.describe Tastytrade::Order do
  let(:leg) do
    Tastytrade::OrderLeg.new(
      action: Tastytrade::OrderAction::BUY_TO_OPEN,
      symbol: "AAPL",
      quantity: 100
    )
  end

  describe "#initialize" do
    it "creates a market order" do
      order = described_class.new(
        type: Tastytrade::OrderType::MARKET,
        legs: leg
      )

      expect(order.type).to eq(Tastytrade::OrderType::MARKET)
      expect(order.time_in_force).to eq(Tastytrade::OrderTimeInForce::DAY)
      expect(order.legs).to eq([leg])
      expect(order.price).to be_nil
    end

    it "creates a limit order with price" do
      order = described_class.new(
        type: Tastytrade::OrderType::LIMIT,
        legs: leg,
        price: 150.50
      )

      expect(order.type).to eq(Tastytrade::OrderType::LIMIT)
      expect(order.price).to eq(BigDecimal("150.50"))
    end

    it "validates order type" do
      expect do
        described_class.new(
          type: "INVALID_TYPE",
          legs: leg
        )
      end.to raise_error(ArgumentError, /Invalid order type/)
    end

    it "validates time in force" do
      expect do
        described_class.new(
          type: Tastytrade::OrderType::MARKET,
          time_in_force: "INVALID_TIF",
          legs: leg
        )
      end.to raise_error(ArgumentError, /Invalid time in force/)
    end

    it "requires price for limit orders" do
      expect do
        described_class.new(
          type: Tastytrade::OrderType::LIMIT,
          legs: leg
        )
      end.to raise_error(ArgumentError, /Price is required for limit orders/)
    end

    it "validates price is positive" do
      expect do
        described_class.new(
          type: Tastytrade::OrderType::LIMIT,
          legs: leg,
          price: -10
        )
      end.to raise_error(ArgumentError, /Price must be greater than 0/)
    end
  end

  describe "#market?" do
    it "returns true for market orders" do
      order = described_class.new(
        type: Tastytrade::OrderType::MARKET,
        legs: leg
      )
      expect(order.market?).to be true
    end

    it "returns false for limit orders" do
      order = described_class.new(
        type: Tastytrade::OrderType::LIMIT,
        legs: leg,
        price: 150
      )
      expect(order.market?).to be false
    end
  end

  describe "#limit?" do
    it "returns true for limit orders" do
      order = described_class.new(
        type: Tastytrade::OrderType::LIMIT,
        legs: leg,
        price: 150
      )
      expect(order.limit?).to be true
    end

    it "returns false for market orders" do
      order = described_class.new(
        type: Tastytrade::OrderType::MARKET,
        legs: leg
      )
      expect(order.limit?).to be false
    end
  end

  describe "#to_api_params" do
    it "converts market order to API format" do
      order = described_class.new(
        type: Tastytrade::OrderType::MARKET,
        legs: leg
      )

      params = order.to_api_params
      expect(params["order-type"]).to eq("Market")
      expect(params["time-in-force"]).to eq("Day")
      expect(params["legs"]).to be_an(Array)
      expect(params["legs"].first["action"]).to eq("Buy to Open")
      expect(params).not_to have_key("price")
    end

    it "converts limit order to API format with price and price-effect" do
      order = described_class.new(
        type: Tastytrade::OrderType::LIMIT,
        legs: leg,
        price: 150.50
      )

      params = order.to_api_params
      expect(params["order-type"]).to eq("Limit")
      expect(params["price"]).to eq("150.5")
      expect(params["price-effect"]).to eq("Debit") # BUY_TO_OPEN results in Debit
    end

    it "sets price-effect to Credit for sell orders" do
      sell_leg = Tastytrade::OrderLeg.new(
        action: Tastytrade::OrderAction::SELL_TO_CLOSE,
        symbol: "AAPL",
        quantity: 100
      )

      order = described_class.new(
        type: Tastytrade::OrderType::LIMIT,
        legs: sell_leg,
        price: 150.50
      )

      params = order.to_api_params
      expect(params["price-effect"]).to eq("Credit")
    end
  end
end
