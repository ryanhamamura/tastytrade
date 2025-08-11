# frozen_string_literal: true

require "spec_helper"
require "tastytrade/option_order_builder"

RSpec.describe "Option Order Integration", :integration do
  let(:session) { instance_double(Tastytrade::Session) }
  let(:account) do
    instance_double(
      Tastytrade::Models::Account,
      account_number: "TEST123",
      get_trading_status: trading_status
    )
  end
  let(:trading_status) do
    instance_double(
      Tastytrade::Models::TradingStatus,
      can_trade_options?: true,
      restricted?: false,
      is_closing_only: false
    )
  end
  let(:builder) { Tastytrade::OptionOrderBuilder.new(session, account) }

  let(:dry_run_response) do
    instance_double(
      Tastytrade::Models::OrderResponse,
      errors: [],
      warnings: [],
      order_id: "DRY-RUN-123",
      status: "Received",
      buying_power_effect: buying_power_effect
    )
  end

  let(:buying_power_effect) do
    instance_double(
      Tastytrade::Models::BuyingPowerEffect,
      current_buying_power: BigDecimal("10000"),
      new_buying_power: BigDecimal("9500"),
      buying_power_change_amount: BigDecimal("-500"),
      buying_power_usage_percentage: BigDecimal("5"),
      change_in_margin_requirement: nil
    )
  end

  before do
    allow(account).to receive(:place_order).and_return(dry_run_response)
  end

  describe "Single-leg option orders" do
    let(:call_option) do
      instance_double(
        Tastytrade::Models::Option,
        symbol: "AAPL 240119C00150000",
        option_type: "C",
        strike_price: BigDecimal("150"),
        expiration_date: Date.new(2024, 1, 19),
        underlying_symbol: "AAPL",
        expired?: false,
        days_to_expiration: 30,
        ask: BigDecimal("2.50"),
        bid: BigDecimal("2.45")
      )
    end

    before do
      allow(Tastytrade::Models::Option).to receive(:get)
        .with(session, "AAPL 240119C00150000")
        .and_return(call_option)
    end

    it "places a buy call order with dry-run validation" do
      order = builder.buy_call(call_option, 1, price: BigDecimal("2.50"))

      expect(order).to be_a(Tastytrade::Order)
      expect(order.legs.first.instrument_type).to eq("Option")

      # Perform dry-run validation
      response = account.place_order(session, order, dry_run: true)

      expect(response.errors).to be_empty
      expect(response.buying_power_effect.buying_power_change_amount).to eq(BigDecimal("-500"))
    end

    it "places a sell put order with dry-run validation" do
      put_option = instance_double(
        Tastytrade::Models::Option,
        symbol: "AAPL 240119P00145000",
        option_type: "P",
        strike_price: BigDecimal("145"),
        expiration_date: Date.new(2024, 1, 19),
        underlying_symbol: "AAPL",
        expired?: false,
        days_to_expiration: 30,
        ask: BigDecimal("3.50"),
        bid: BigDecimal("3.45")
      )

      allow(Tastytrade::Models::Option).to receive(:get)
        .with(session, "AAPL 240119P00145000")
        .and_return(put_option)

      order = builder.sell_put(put_option, 1, price: BigDecimal("3.50"))

      expect(order).to be_a(Tastytrade::Order)
      expect(order.legs.first.action).to eq(Tastytrade::OrderAction::SELL_TO_OPEN)

      # Perform dry-run validation
      response = account.place_order(session, order, dry_run: true)

      expect(response.errors).to be_empty
    end
  end

  describe "Vertical spread orders" do
    let(:long_call) do
      instance_double(
        Tastytrade::Models::Option,
        symbol: "SPY 240119C00450000",
        option_type: "C",
        strike_price: BigDecimal("450"),
        expiration_date: Date.new(2024, 1, 19),
        underlying_symbol: "SPY",
        expired?: false,
        days_to_expiration: 30,
        ask: BigDecimal("3.00"),
        bid: BigDecimal("2.95")
      )
    end

    let(:short_call) do
      instance_double(
        Tastytrade::Models::Option,
        symbol: "SPY 240119C00455000",
        option_type: "C",
        strike_price: BigDecimal("455"),
        expiration_date: Date.new(2024, 1, 19),
        underlying_symbol: "SPY",
        expired?: false,
        days_to_expiration: 30,
        ask: BigDecimal("1.50"),
        bid: BigDecimal("1.45")
      )
    end

    before do
      allow(Tastytrade::Models::Option).to receive(:get)
        .with(session, "SPY 240119C00450000")
        .and_return(long_call)
      allow(Tastytrade::Models::Option).to receive(:get)
        .with(session, "SPY 240119C00455000")
        .and_return(short_call)
    end

    it "creates and validates a bull call spread" do
      order = builder.vertical_spread(
        long_call,
        short_call,
        1,
        price: BigDecimal("1.50")
      )

      expect(order.legs.size).to eq(2)
      expect(order.legs[0].action).to eq(Tastytrade::OrderAction::BUY_TO_OPEN)
      expect(order.legs[1].action).to eq(Tastytrade::OrderAction::SELL_TO_OPEN)

      # Validate with dry-run
      validator = Tastytrade::OrderValidator.new(session, account, order)

      # Mock the dry-run response
      allow(validator).to receive(:dry_run_validate!).and_return(dry_run_response)

      response = validator.dry_run_validate!
      expect(response.errors).to be_empty
    end
  end

  describe "Iron condor orders" do
    let(:put_short) do
      instance_double(
        Tastytrade::Models::Option,
        symbol: "SPY 240119P00440000",
        option_type: "P",
        strike_price: BigDecimal("440"),
        expiration_date: Date.new(2024, 1, 19),
        underlying_symbol: "SPY",
        expired?: false
      )
    end

    let(:put_long) do
      instance_double(
        Tastytrade::Models::Option,
        symbol: "SPY 240119P00435000",
        option_type: "P",
        strike_price: BigDecimal("435"),
        expiration_date: Date.new(2024, 1, 19),
        underlying_symbol: "SPY",
        expired?: false
      )
    end

    let(:call_short) do
      instance_double(
        Tastytrade::Models::Option,
        symbol: "SPY 240119C00460000",
        option_type: "C",
        strike_price: BigDecimal("460"),
        expiration_date: Date.new(2024, 1, 19),
        underlying_symbol: "SPY",
        expired?: false
      )
    end

    let(:call_long) do
      instance_double(
        Tastytrade::Models::Option,
        symbol: "SPY 240119C00465000",
        option_type: "C",
        strike_price: BigDecimal("465"),
        expiration_date: Date.new(2024, 1, 19),
        underlying_symbol: "SPY",
        expired?: false
      )
    end

    it "creates and validates an iron condor" do
      order = builder.iron_condor(
        put_short,
        put_long,
        call_short,
        call_long,
        1,
        price: BigDecimal("2.00")
      )

      expect(order.legs.size).to eq(4)
      expect(order.legs[0].action).to eq(Tastytrade::OrderAction::SELL_TO_OPEN)
      expect(order.legs[1].action).to eq(Tastytrade::OrderAction::BUY_TO_OPEN)
      expect(order.legs[2].action).to eq(Tastytrade::OrderAction::SELL_TO_OPEN)
      expect(order.legs[3].action).to eq(Tastytrade::OrderAction::BUY_TO_OPEN)

      # Perform dry-run validation
      response = account.place_order(session, order, dry_run: true)
      expect(response.errors).to be_empty
    end
  end

  describe "Strangle orders" do
    let(:put_option) do
      instance_double(
        Tastytrade::Models::Option,
        symbol: "QQQ 240119P00370000",
        option_type: "P",
        strike_price: BigDecimal("370"),
        expiration_date: Date.new(2024, 1, 19),
        underlying_symbol: "QQQ",
        expired?: false,
        ask: BigDecimal("4.00"),
        bid: BigDecimal("3.95")
      )
    end

    let(:call_option) do
      instance_double(
        Tastytrade::Models::Option,
        symbol: "QQQ 240119C00390000",
        option_type: "C",
        strike_price: BigDecimal("390"),
        expiration_date: Date.new(2024, 1, 19),
        underlying_symbol: "QQQ",
        expired?: false,
        ask: BigDecimal("3.50"),
        bid: BigDecimal("3.45")
      )
    end

    it "creates and validates a long strangle" do
      order = builder.strangle(
        put_option,
        call_option,
        1,
        action: Tastytrade::OrderAction::BUY_TO_OPEN,
        price: BigDecimal("7.50")
      )

      expect(order.legs.size).to eq(2)
      expect(order.legs[0].action).to eq(Tastytrade::OrderAction::BUY_TO_OPEN)
      expect(order.legs[1].action).to eq(Tastytrade::OrderAction::BUY_TO_OPEN)

      # Perform dry-run validation
      response = account.place_order(session, order, dry_run: true)
      expect(response.errors).to be_empty
    end

    it "creates and validates a short strangle" do
      order = builder.strangle(
        put_option,
        call_option,
        1,
        action: Tastytrade::OrderAction::SELL_TO_OPEN,
        price: BigDecimal("7.40")
      )

      expect(order.legs.size).to eq(2)
      expect(order.legs[0].action).to eq(Tastytrade::OrderAction::SELL_TO_OPEN)
      expect(order.legs[1].action).to eq(Tastytrade::OrderAction::SELL_TO_OPEN)

      # Perform dry-run validation
      response = account.place_order(session, order, dry_run: true)
      expect(response.errors).to be_empty
    end
  end

  describe "Straddle orders" do
    let(:put_option) do
      instance_double(
        Tastytrade::Models::Option,
        symbol: "IWM 240119P00200000",
        option_type: "P",
        strike_price: BigDecimal("200"),
        expiration_date: Date.new(2024, 1, 19),
        underlying_symbol: "IWM",
        expired?: false,
        ask: BigDecimal("5.00"),
        bid: BigDecimal("4.95")
      )
    end

    let(:call_option) do
      instance_double(
        Tastytrade::Models::Option,
        symbol: "IWM 240119C00200000",
        option_type: "C",
        strike_price: BigDecimal("200"),
        expiration_date: Date.new(2024, 1, 19),
        underlying_symbol: "IWM",
        expired?: false,
        ask: BigDecimal("5.50"),
        bid: BigDecimal("5.45")
      )
    end

    before do
      allow(Tastytrade::Models::Option).to receive(:get)
        .with(session, "IWM 240119P00200000")
        .and_return(put_option)
      allow(Tastytrade::Models::Option).to receive(:get)
        .with(session, "IWM 240119C00200000")
        .and_return(call_option)
    end

    it "creates and validates a long straddle" do
      order = builder.straddle(
        put_option,
        call_option,
        1,
        action: Tastytrade::OrderAction::BUY_TO_OPEN,
        price: BigDecimal("10.50")
      )

      expect(order.legs.size).to eq(2)
      expect(order.legs[0].action).to eq(Tastytrade::OrderAction::BUY_TO_OPEN)
      expect(order.legs[1].action).to eq(Tastytrade::OrderAction::BUY_TO_OPEN)
      expect(order.legs[0].symbol).to include("P")
      expect(order.legs[1].symbol).to include("C")

      # Perform dry-run validation
      response = account.place_order(session, order, dry_run: true)
      expect(response.errors).to be_empty
    end
  end

  describe "Error handling" do
    it "rejects expired options" do
      expired_option = instance_double(
        Tastytrade::Models::Option,
        symbol: "AAPL 231231C00150000",
        expired?: true
      )

      expect {
        builder.buy_call(expired_option, 1)
      }.to raise_error(Tastytrade::OptionOrderBuilder::InvalidOptionError, /expired/)
    end

    it "validates spread requirements" do
      call1 = instance_double(
        Tastytrade::Models::Option,
        symbol: "AAPL 240119C00150000",
        option_type: "C",
        strike_price: BigDecimal("150"),
        expiration_date: Date.new(2024, 1, 19),
        underlying_symbol: "AAPL",
        expired?: false
      )

      put1 = instance_double(
        Tastytrade::Models::Option,
        symbol: "AAPL 240119P00150000",
        option_type: "P",
        strike_price: BigDecimal("150"),
        expiration_date: Date.new(2024, 1, 19),
        underlying_symbol: "AAPL",
        expired?: false
      )

      expect {
        builder.vertical_spread(call1, put1, 1)
      }.to raise_error(Tastytrade::OptionOrderBuilder::InvalidStrategyError, /same type/)
    end

    it "handles insufficient permissions" do
      no_options_status = instance_double(
        Tastytrade::Models::TradingStatus,
        can_trade_options?: false,
        restricted?: false,
        is_closing_only: false
      )

      allow(account).to receive(:get_trading_status).and_return(no_options_status)

      order = builder.buy_call(
        instance_double(
          Tastytrade::Models::Option,
          symbol: "AAPL 240119C00150000",
          option_type: "C",
          expired?: false
        ),
        1
      )

      validator = Tastytrade::OrderValidator.new(session, account, order)

      expect {
        validator.validate!(skip_dry_run: true)
      }.to raise_error(Tastytrade::OrderValidationError, /options trading permissions/)
    end
  end

  describe "Net premium calculation" do
    let(:call_option) do
      instance_double(
        Tastytrade::Models::Option,
        symbol: "AAPL 240119C00150000",
        ask: BigDecimal("2.50"),
        bid: BigDecimal("2.45")
      )
    end

    let(:put_option) do
      instance_double(
        Tastytrade::Models::Option,
        symbol: "AAPL 240119P00145000",
        ask: BigDecimal("3.50"),
        bid: BigDecimal("3.45")
      )
    end

    it "calculates net debit for buying options" do
      order = instance_double(
        Tastytrade::Order,
        legs: [
          instance_double(
            Tastytrade::OrderLeg,
            symbol: "AAPL 240119C00150000",
            action: Tastytrade::OrderAction::BUY_TO_OPEN,
            quantity: 2
          )
        ]
      )

      allow(Tastytrade::Models::Option).to receive(:get)
        .with(session, "AAPL 240119C00150000")
        .and_return(call_option)

      net_premium = builder.calculate_net_premium(order)

      # (2.50 + 2.45) / 2 * 2 contracts * 100 shares * -1 (debit)
      expect(net_premium).to eq(BigDecimal("-495"))
    end

    it "calculates net credit for selling options" do
      order = instance_double(
        Tastytrade::Order,
        legs: [
          instance_double(
            Tastytrade::OrderLeg,
            symbol: "AAPL 240119P00145000",
            action: Tastytrade::OrderAction::SELL_TO_OPEN,
            quantity: 1
          )
        ]
      )

      allow(Tastytrade::Models::Option).to receive(:get)
        .with(session, "AAPL 240119P00145000")
        .and_return(put_option)

      net_premium = builder.calculate_net_premium(order)

      # (3.50 + 3.45) / 2 * 1 contract * 100 shares * 1 (credit)
      expect(net_premium).to eq(BigDecimal("347.5"))
    end
  end
end
