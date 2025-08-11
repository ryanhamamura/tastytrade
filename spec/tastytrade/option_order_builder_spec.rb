# frozen_string_literal: true

require "spec_helper"
require "tastytrade/option_order_builder"

RSpec.describe Tastytrade::OptionOrderBuilder do
  let(:session) { instance_double(Tastytrade::Session) }
  let(:account) { instance_double(Tastytrade::Models::Account) }
  let(:builder) { described_class.new(session, account) }

  let(:call_option) do
    instance_double(
      Tastytrade::Models::Option,
      symbol: "AAPL 240119C00150000",
      option_type: "C",
      strike_price: BigDecimal("150"),
      expiration_date: Date.new(2024, 1, 19),
      underlying_symbol: "AAPL",
      expired?: false,
      ask: BigDecimal("2.50"),
      bid: BigDecimal("2.45")
    )
  end

  let(:put_option) do
    instance_double(
      Tastytrade::Models::Option,
      symbol: "AAPL 240119P00150000",
      option_type: "P",
      strike_price: BigDecimal("150"),
      expiration_date: Date.new(2024, 1, 19),
      underlying_symbol: "AAPL",
      expired?: false,
      ask: BigDecimal("3.50"),
      bid: BigDecimal("3.45")
    )
  end

  describe "single-leg option orders" do
    describe "#buy_call" do
      it "creates a buy call order" do
        order = builder.buy_call(call_option, 1, price: BigDecimal("2.50"))

        expect(order).to be_a(Tastytrade::Order)
        expect(order.type).to eq(Tastytrade::OrderType::LIMIT)
        expect(order.price).to eq(BigDecimal("2.50"))
        expect(order.legs.size).to eq(1)

        leg = order.legs.first
        expect(leg.action).to eq(Tastytrade::OrderAction::BUY_TO_OPEN)
        expect(leg.symbol).to eq("AAPL 240119C00150000")
        expect(leg.quantity).to eq(1)
        expect(leg.instrument_type).to eq("Option")
      end

      it "creates a market order when no price specified" do
        order = builder.buy_call(call_option, 2)

        expect(order.type).to eq(Tastytrade::OrderType::MARKET)
        expect(order.price).to be_nil
      end

      it "validates the option is not expired" do
        expired_option = instance_double(Tastytrade::Models::Option, expired?: true)

        expect {
          builder.buy_call(expired_option, 1)
        }.to raise_error(Tastytrade::OptionOrderBuilder::InvalidOptionError, /expired/)
      end
    end

    describe "#sell_call" do
      it "creates a sell call order" do
        order = builder.sell_call(call_option, 1, price: BigDecimal("2.60"))

        expect(order).to be_a(Tastytrade::Order)
        expect(order.type).to eq(Tastytrade::OrderType::LIMIT)
        expect(order.price).to eq(BigDecimal("2.60"))

        leg = order.legs.first
        expect(leg.action).to eq(Tastytrade::OrderAction::SELL_TO_OPEN)
        expect(leg.symbol).to eq("AAPL 240119C00150000")
        expect(leg.quantity).to eq(1)
        expect(leg.instrument_type).to eq("Option")
      end
    end

    describe "#buy_put" do
      it "creates a buy put order" do
        order = builder.buy_put(put_option, 1, price: BigDecimal("3.50"))

        expect(order).to be_a(Tastytrade::Order)
        expect(order.type).to eq(Tastytrade::OrderType::LIMIT)
        expect(order.price).to eq(BigDecimal("3.50"))

        leg = order.legs.first
        expect(leg.action).to eq(Tastytrade::OrderAction::BUY_TO_OPEN)
        expect(leg.symbol).to eq("AAPL 240119P00150000")
        expect(leg.quantity).to eq(1)
        expect(leg.instrument_type).to eq("Option")
      end
    end

    describe "#sell_put" do
      it "creates a sell put order" do
        order = builder.sell_put(put_option, 1, price: BigDecimal("3.60"))

        expect(order).to be_a(Tastytrade::Order)
        expect(order.type).to eq(Tastytrade::OrderType::LIMIT)
        expect(order.price).to eq(BigDecimal("3.60"))

        leg = order.legs.first
        expect(leg.action).to eq(Tastytrade::OrderAction::SELL_TO_OPEN)
        expect(leg.symbol).to eq("AAPL 240119P00150000")
        expect(leg.quantity).to eq(1)
        expect(leg.instrument_type).to eq("Option")
      end
    end

    describe "#close_position" do
      it "creates a closing order for a long position" do
        order = builder.close_position(call_option, 1, price: BigDecimal("3.00"))

        expect(order).to be_a(Tastytrade::Order)
        expect(order.type).to eq(Tastytrade::OrderType::LIMIT)

        leg = order.legs.first
        expect(leg.action).to eq(Tastytrade::OrderAction::SELL_TO_CLOSE)
        expect(leg.position_effect).to eq("Closing")
      end

      it "handles negative quantities correctly" do
        order = builder.close_position(call_option, -1, price: BigDecimal("3.00"))

        leg = order.legs.first
        expect(leg.quantity).to eq(1)
      end
    end
  end

  describe "multi-leg strategies" do
    let(:call_long) do
      instance_double(
        Tastytrade::Models::Option,
        symbol: "AAPL 240119C00150000",
        option_type: "C",
        strike_price: BigDecimal("150"),
        expiration_date: Date.new(2024, 1, 19),
        underlying_symbol: "AAPL",
        expired?: false,
        ask: BigDecimal("2.50"),
        bid: BigDecimal("2.45")
      )
    end

    let(:call_short) do
      instance_double(
        Tastytrade::Models::Option,
        symbol: "AAPL 240119C00155000",
        option_type: "C",
        strike_price: BigDecimal("155"),
        expiration_date: Date.new(2024, 1, 19),
        underlying_symbol: "AAPL",
        expired?: false,
        ask: BigDecimal("1.50"),
        bid: BigDecimal("1.45")
      )
    end

    describe "#vertical_spread" do
      it "creates a vertical call spread" do
        order = builder.vertical_spread(call_long, call_short, 1, price: BigDecimal("1.00"))

        expect(order).to be_a(Tastytrade::Order)
        expect(order.type).to eq(Tastytrade::OrderType::LIMIT)
        expect(order.price).to eq(BigDecimal("1.00"))
        expect(order.legs.size).to eq(2)

        expect(order.legs[0].action).to eq(Tastytrade::OrderAction::BUY_TO_OPEN)
        expect(order.legs[0].symbol).to eq("AAPL 240119C00150000")

        expect(order.legs[1].action).to eq(Tastytrade::OrderAction::SELL_TO_OPEN)
        expect(order.legs[1].symbol).to eq("AAPL 240119C00155000")
      end

      it "validates options are same type" do
        expect {
          builder.vertical_spread(call_long, put_option, 1)
        }.to raise_error(Tastytrade::OptionOrderBuilder::InvalidStrategyError, /same type/)
      end

      it "validates options have same expiration" do
        different_exp = instance_double(
          Tastytrade::Models::Option,
          symbol: "AAPL 240216C00155000",
          option_type: "C",
          strike_price: BigDecimal("155"),
          expiration_date: Date.new(2024, 2, 16),
          underlying_symbol: "AAPL",
          expired?: false
        )

        expect {
          builder.vertical_spread(call_long, different_exp, 1)
        }.to raise_error(Tastytrade::OptionOrderBuilder::InvalidStrategyError, /same expiration/)
      end
    end

    describe "#iron_condor" do
      let(:put_short) do
        instance_double(
          Tastytrade::Models::Option,
          symbol: "AAPL 240119P00145000",
          option_type: "P",
          strike_price: BigDecimal("145"),
          expiration_date: Date.new(2024, 1, 19),
          underlying_symbol: "AAPL",
          expired?: false
        )
      end

      let(:put_long) do
        instance_double(
          Tastytrade::Models::Option,
          symbol: "AAPL 240119P00140000",
          option_type: "P",
          strike_price: BigDecimal("140"),
          expiration_date: Date.new(2024, 1, 19),
          underlying_symbol: "AAPL",
          expired?: false
        )
      end

      let(:call_short_ic) do
        instance_double(
          Tastytrade::Models::Option,
          symbol: "AAPL 240119C00155000",
          option_type: "C",
          strike_price: BigDecimal("155"),
          expiration_date: Date.new(2024, 1, 19),
          underlying_symbol: "AAPL",
          expired?: false
        )
      end

      let(:call_long_ic) do
        instance_double(
          Tastytrade::Models::Option,
          symbol: "AAPL 240119C00160000",
          option_type: "C",
          strike_price: BigDecimal("160"),
          expiration_date: Date.new(2024, 1, 19),
          underlying_symbol: "AAPL",
          expired?: false
        )
      end

      it "creates an iron condor with 4 legs" do
        order = builder.iron_condor(
          put_short, put_long, call_short_ic, call_long_ic, 1,
          price: BigDecimal("2.00")
        )

        expect(order).to be_a(Tastytrade::Order)
        expect(order.type).to eq(Tastytrade::OrderType::LIMIT)
        expect(order.price).to eq(BigDecimal("2.00"))
        expect(order.legs.size).to eq(4)

        expect(order.legs[0].action).to eq(Tastytrade::OrderAction::SELL_TO_OPEN)
        expect(order.legs[0].symbol).to eq("AAPL 240119P00145000")

        expect(order.legs[1].action).to eq(Tastytrade::OrderAction::BUY_TO_OPEN)
        expect(order.legs[1].symbol).to eq("AAPL 240119P00140000")

        expect(order.legs[2].action).to eq(Tastytrade::OrderAction::SELL_TO_OPEN)
        expect(order.legs[2].symbol).to eq("AAPL 240119C00155000")

        expect(order.legs[3].action).to eq(Tastytrade::OrderAction::BUY_TO_OPEN)
        expect(order.legs[3].symbol).to eq("AAPL 240119C00160000")
      end

      it "validates put spread strikes" do
        expect {
          builder.iron_condor(
            put_long, put_short, call_short_ic, call_long_ic, 1
          )
        }.to raise_error(Tastytrade::OptionOrderBuilder::InvalidStrategyError, /Long put strike must be lower/)
      end

      it "validates call spread strikes" do
        expect {
          builder.iron_condor(
            put_short, put_long, call_long_ic, call_short_ic, 1
          )
        }.to raise_error(Tastytrade::OptionOrderBuilder::InvalidStrategyError, /Long call strike must be higher/)
      end
    end

    describe "#strangle" do
      let(:strangle_put_option) do
        instance_double(
          Tastytrade::Models::Option,
          symbol: "AAPL 240119P00145000",
          option_type: "P",
          strike_price: BigDecimal("145"),
          expiration_date: Date.new(2024, 1, 19),
          underlying_symbol: "AAPL",
          expired?: false,
          ask: BigDecimal("3.50"),
          bid: BigDecimal("3.45")
        )
      end

      let(:strangle_call_option) do
        instance_double(
          Tastytrade::Models::Option,
          symbol: "AAPL 240119C00155000",
          option_type: "C",
          strike_price: BigDecimal("155"),
          expiration_date: Date.new(2024, 1, 19),
          underlying_symbol: "AAPL",
          expired?: false,
          ask: BigDecimal("2.50"),
          bid: BigDecimal("2.45")
        )
      end

      it "creates a long strangle" do
        order = builder.strangle(
          strangle_put_option, strangle_call_option, 1,
          action: Tastytrade::OrderAction::BUY_TO_OPEN,
          price: BigDecimal("6.00")
        )

        expect(order).to be_a(Tastytrade::Order)
        expect(order.type).to eq(Tastytrade::OrderType::LIMIT)
        expect(order.price).to eq(BigDecimal("6.00"))
        expect(order.legs.size).to eq(2)

        expect(order.legs[0].action).to eq(Tastytrade::OrderAction::BUY_TO_OPEN)
        expect(order.legs[0].symbol).to eq("AAPL 240119P00145000")

        expect(order.legs[1].action).to eq(Tastytrade::OrderAction::BUY_TO_OPEN)
        expect(order.legs[1].symbol).to eq("AAPL 240119C00155000")
      end

      it "creates a short strangle" do
        order = builder.strangle(
          strangle_put_option, strangle_call_option, 1,
          action: Tastytrade::OrderAction::SELL_TO_OPEN,
          price: BigDecimal("6.00")
        )

        expect(order.legs[0].action).to eq(Tastytrade::OrderAction::SELL_TO_OPEN)
        expect(order.legs[1].action).to eq(Tastytrade::OrderAction::SELL_TO_OPEN)
      end

      it "validates strangle has different strikes" do
        expect {
          builder.strangle(put_option, call_option, 1)
        }.to raise_error(Tastytrade::OptionOrderBuilder::InvalidStrategyError, /different strike prices/)
      end
    end

    describe "#straddle" do
      it "creates a long straddle" do
        order = builder.straddle(
          put_option, call_option, 1,
          action: Tastytrade::OrderAction::BUY_TO_OPEN,
          price: BigDecimal("6.00")
        )

        expect(order).to be_a(Tastytrade::Order)
        expect(order.type).to eq(Tastytrade::OrderType::LIMIT)
        expect(order.price).to eq(BigDecimal("6.00"))
        expect(order.legs.size).to eq(2)

        expect(order.legs[0].action).to eq(Tastytrade::OrderAction::BUY_TO_OPEN)
        expect(order.legs[0].symbol).to eq("AAPL 240119P00150000")

        expect(order.legs[1].action).to eq(Tastytrade::OrderAction::BUY_TO_OPEN)
        expect(order.legs[1].symbol).to eq("AAPL 240119C00150000")
      end

      it "creates a short straddle" do
        order = builder.straddle(
          put_option, call_option, 1,
          action: Tastytrade::OrderAction::SELL_TO_OPEN,
          price: BigDecimal("6.00")
        )

        expect(order.legs[0].action).to eq(Tastytrade::OrderAction::SELL_TO_OPEN)
        expect(order.legs[0].symbol).to eq("AAPL 240119P00150000")

        expect(order.legs[1].action).to eq(Tastytrade::OrderAction::SELL_TO_OPEN)
        expect(order.legs[1].symbol).to eq("AAPL 240119C00150000")
      end

      it "validates put and call have same strike" do
        different_strike_call = instance_double(
          Tastytrade::Models::Option,
          symbol: "AAPL 240119C00155000",
          option_type: "C",
          strike_price: BigDecimal("155"),
          expiration_date: Date.new(2024, 1, 19),
          underlying_symbol: "AAPL",
          expired?: false
        )

        expect {
          builder.straddle(put_option, different_strike_call, 1)
        }.to raise_error(Tastytrade::OptionOrderBuilder::InvalidStrategyError, /same strike price/)
      end

      it "validates put and call have same expiration" do
        different_exp_call = instance_double(
          Tastytrade::Models::Option,
          symbol: "AAPL 240216C00150000",
          option_type: "C",
          strike_price: BigDecimal("150"),
          expiration_date: Date.new(2024, 2, 16),
          underlying_symbol: "AAPL",
          expired?: false
        )

        expect {
          builder.straddle(put_option, different_exp_call, 1)
        }.to raise_error(Tastytrade::OptionOrderBuilder::InvalidStrategyError, /same expiration/)
      end
    end
  end

  describe "#calculate_net_premium" do
    it "calculates net debit for buying options" do
      order = instance_double(
        Tastytrade::Order,
        legs: [
          instance_double(
            Tastytrade::OrderLeg,
            symbol: "AAPL 240119C00150000",
            action: Tastytrade::OrderAction::BUY_TO_OPEN,
            quantity: 1
          )
        ]
      )

      allow(Tastytrade::Models::Option).to receive(:get).with(session, "AAPL 240119C00150000").and_return(call_option)

      net_premium = builder.calculate_net_premium(order)

      expect(net_premium).to eq(BigDecimal("-247.5"))
    end

    it "calculates net credit for selling options" do
      order = instance_double(
        Tastytrade::Order,
        legs: [
          instance_double(
            Tastytrade::OrderLeg,
            symbol: "AAPL 240119P00150000",
            action: Tastytrade::OrderAction::SELL_TO_OPEN,
            quantity: 1
          )
        ]
      )

      allow(Tastytrade::Models::Option).to receive(:get).with(session, "AAPL 240119P00150000").and_return(put_option)

      net_premium = builder.calculate_net_premium(order)

      expect(net_premium).to eq(BigDecimal("347.5"))
    end

    it "calculates net premium for multi-leg orders" do
      order = instance_double(
        Tastytrade::Order,
        legs: [
          instance_double(
            Tastytrade::OrderLeg,
            symbol: "AAPL 240119C00150000",
            action: Tastytrade::OrderAction::BUY_TO_OPEN,
            quantity: 1
          ),
          instance_double(
            Tastytrade::OrderLeg,
            symbol: "AAPL 240119P00150000",
            action: Tastytrade::OrderAction::SELL_TO_OPEN,
            quantity: 1
          )
        ]
      )

      allow(Tastytrade::Models::Option).to receive(:get).with(session, "AAPL 240119C00150000").and_return(call_option)
      allow(Tastytrade::Models::Option).to receive(:get).with(session, "AAPL 240119P00150000").and_return(put_option)

      net_premium = builder.calculate_net_premium(order)

      expect(net_premium).to eq(BigDecimal("100"))
    end
  end
end
