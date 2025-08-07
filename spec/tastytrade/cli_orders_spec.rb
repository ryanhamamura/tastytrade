# frozen_string_literal: true

require "spec_helper"
require "tastytrade/cli"

RSpec.describe "CLI Order Placement" do
  let(:cli) { Tastytrade::CLI::Orders.new }
  let(:session) { instance_double(Tastytrade::Session) }
  let(:account) { instance_double(Tastytrade::Models::Account, account_number: "5WT00000") }

  before do
    allow(cli).to receive(:current_session).and_return(session)
    allow(cli).to receive(:current_account).and_return(account)
    allow(cli).to receive(:require_authentication!)
    allow(cli).to receive(:puts)
    allow(cli).to receive(:info)
    allow(cli).to receive(:success)
    allow(cli).to receive(:error)
    allow(cli).to receive(:prompt).and_return(instance_double(TTY::Prompt, yes?: true))
    allow(cli).to receive(:format_currency) { |val| "$#{val}" }
  end

  describe "time_in_force parameter" do
    let(:order_response) do
      instance_double(
        Tastytrade::Models::OrderResponse,
        order_id: "12345",
        buying_power_effect: BigDecimal("-150.00"),
        warnings: [],
        errors: [],
        status: "Routed"
      )
    end

    before do
      allow(account).to receive(:place_order).and_return(order_response)
      allow(cli).to receive(:exit)
    end

    context "when placing a DAY order" do
      it "creates an order with DAY time_in_force (default)" do
        expect(Tastytrade::Order).to receive(:new).with(
          type: Tastytrade::OrderType::LIMIT,
          time_in_force: Tastytrade::OrderTimeInForce::DAY,
          legs: anything,
          price: BigDecimal("150.00")
        ).and_call_original

        allow(cli).to receive(:options).and_return({
                                                     symbol: "AAPL",
                                                     action: "buy_to_open",
                                                     quantity: 100,
                                                     type: "limit",
                                                     price: 150.00,
                                                     time_in_force: "day",
                                                     skip_confirmation: true
                                                   })

        expect { cli.place }.not_to raise_error
      end

      it "accepts 'd' as shorthand for day" do
        expect(Tastytrade::Order).to receive(:new).with(
          type: Tastytrade::OrderType::LIMIT,
          time_in_force: Tastytrade::OrderTimeInForce::DAY,
          legs: anything,
          price: BigDecimal("150.00")
        ).and_call_original

        allow(cli).to receive(:options).and_return({
                                                     symbol: "AAPL",
                                                     action: "buy_to_open",
                                                     quantity: 100,
                                                     type: "limit",
                                                     price: 150.00,
                                                     time_in_force: "d",
                                                     skip_confirmation: true
                                                   })

        expect { cli.place }.not_to raise_error
      end
    end

    context "when placing a GTC order" do
      it "creates an order with GTC time_in_force" do
        expect(Tastytrade::Order).to receive(:new).with(
          type: Tastytrade::OrderType::LIMIT,
          time_in_force: Tastytrade::OrderTimeInForce::GTC,
          legs: anything,
          price: BigDecimal("150.00")
        ).and_call_original

        allow(cli).to receive(:options).and_return({
                                                     symbol: "AAPL",
                                                     action: "buy_to_open",
                                                     quantity: 100,
                                                     type: "limit",
                                                     price: 150.00,
                                                     time_in_force: "gtc",
                                                     skip_confirmation: true
                                                   })

        expect { cli.place }.not_to raise_error
      end

      it "accepts 'g' as shorthand for GTC" do
        expect(Tastytrade::Order).to receive(:new).with(
          type: Tastytrade::OrderType::LIMIT,
          time_in_force: Tastytrade::OrderTimeInForce::GTC,
          legs: anything,
          price: BigDecimal("150.00")
        ).and_call_original

        allow(cli).to receive(:options).and_return({
                                                     symbol: "AAPL",
                                                     action: "buy_to_open",
                                                     quantity: 100,
                                                     type: "limit",
                                                     price: 150.00,
                                                     time_in_force: "g",
                                                     skip_confirmation: true
                                                   })

        expect { cli.place }.not_to raise_error
      end

      it "accepts 'good_till_cancelled' as GTC alias" do
        expect(Tastytrade::Order).to receive(:new).with(
          type: Tastytrade::OrderType::LIMIT,
          time_in_force: Tastytrade::OrderTimeInForce::GTC,
          legs: anything,
          price: BigDecimal("150.00")
        ).and_call_original

        allow(cli).to receive(:options).and_return({
                                                     symbol: "AAPL",
                                                     action: "buy_to_open",
                                                     quantity: 100,
                                                     type: "limit",
                                                     price: 150.00,
                                                     time_in_force: "good_till_cancelled",
                                                     skip_confirmation: true
                                                   })

        expect { cli.place }.not_to raise_error
      end
    end

    context "with invalid time_in_force" do
      it "exits with error for invalid value" do
        expect(cli).to receive(:error).with("Invalid time in force. Must be: day or gtc")
        expect(cli).to receive(:exit).with(1).and_raise(SystemExit)

        allow(cli).to receive(:options).and_return({
                                                     symbol: "AAPL",
                                                     action: "buy_to_open",
                                                     quantity: 100,
                                                     type: "limit",
                                                     price: 150.00,
                                                     time_in_force: "invalid",
                                                     skip_confirmation: true
                                                   })

        expect { cli.place }.to raise_error(SystemExit)
      end
    end
  end
end
