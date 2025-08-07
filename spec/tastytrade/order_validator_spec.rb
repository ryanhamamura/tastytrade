# frozen_string_literal: true

require "spec_helper"

RSpec.describe Tastytrade::OrderValidator do
  let(:session) { instance_double(Tastytrade::Session) }
  let(:account) { instance_double(Tastytrade::Models::Account, account_number: "TEST123") }
  let(:order) { instance_double(Tastytrade::Order) }
  let(:validator) { described_class.new(session, account, order) }

  describe "#validate!" do
    let(:trading_status) { instance_double(Tastytrade::Models::TradingStatus) }
    let(:leg) do
      instance_double(
        Tastytrade::OrderLeg,
        symbol: "AAPL",
        quantity: 100,
        action: Tastytrade::OrderAction::BUY_TO_OPEN,
        instrument_type: "Equity"
      )
    end

    before do
      allow(order).to receive(:legs).and_return([leg])
      allow(order).to receive(:type).and_return(Tastytrade::OrderType::LIMIT)
      allow(order).to receive(:limit?).and_return(true)
      allow(order).to receive(:market?).and_return(false)
      allow(order).to receive(:price).and_return(BigDecimal("150.00"))
      allow(order).to receive(:time_in_force).and_return(Tastytrade::OrderTimeInForce::DAY)
      allow(account).to receive(:get_trading_status).and_return(trading_status)
      allow(trading_status).to receive(:restricted?).and_return(false)
      allow(trading_status).to receive(:is_closing_only).and_return(false)
    end

    context "with valid order" do
      before do
        allow(Tastytrade::Instruments::Equity).to receive(:get).and_return(
          instance_double(Tastytrade::Instruments::Equity, symbol: "AAPL")
        )
      end

      it "passes validation" do
        expect { validator.validate!(skip_dry_run: true) }.not_to raise_error
      end

      it "returns true" do
        expect(validator.validate!(skip_dry_run: true)).to be true
      end
    end

    context "with invalid symbol" do
      before do
        allow(Tastytrade::Instruments::Equity).to receive(:get)
          .and_raise(StandardError, "Symbol not found")
      end

      it "raises OrderValidationError" do
        expect { validator.validate!(skip_dry_run: true) }
          .to raise_error(Tastytrade::OrderValidationError, /Invalid equity symbol/)
      end
    end

    context "with invalid quantity" do
      context "when quantity is zero" do
        before do
          allow(leg).to receive(:quantity).and_return(0)
          allow(Tastytrade::Instruments::Equity).to receive(:get).and_return(
            instance_double(Tastytrade::Instruments::Equity, symbol: "AAPL")
          )
        end

        it "raises OrderValidationError" do
          expect { validator.validate!(skip_dry_run: true) }
            .to raise_error(Tastytrade::OrderValidationError, /must be at least 1/)
        end
      end

      context "when quantity exceeds maximum" do
        before do
          allow(leg).to receive(:quantity).and_return(1_000_000)
          allow(Tastytrade::Instruments::Equity).to receive(:get).and_return(
            instance_double(Tastytrade::Instruments::Equity, symbol: "AAPL")
          )
        end

        it "raises OrderValidationError" do
          expect { validator.validate!(skip_dry_run: true) }
            .to raise_error(Tastytrade::OrderValidationError, /exceeds maximum/)
        end
      end
    end

    context "with invalid price" do
      context "when price is zero" do
        before do
          allow(order).to receive(:price).and_return(BigDecimal("0"))
          allow(Tastytrade::Instruments::Equity).to receive(:get).and_return(
            instance_double(Tastytrade::Instruments::Equity, symbol: "AAPL")
          )
        end

        it "raises OrderValidationError" do
          expect { validator.validate!(skip_dry_run: true) }
            .to raise_error(Tastytrade::OrderValidationError, /Price must be greater than 0/)
        end
      end

      context "when price is negative" do
        before do
          allow(order).to receive(:price).and_return(BigDecimal("-10"))
          allow(Tastytrade::Instruments::Equity).to receive(:get).and_return(
            instance_double(Tastytrade::Instruments::Equity, symbol: "AAPL")
          )
        end

        it "raises OrderValidationError" do
          expect { validator.validate!(skip_dry_run: true) }
            .to raise_error(Tastytrade::OrderValidationError, /Price must be greater than 0/)
        end
      end
    end

    context "with account restrictions" do
      before do
        allow(Tastytrade::Instruments::Equity).to receive(:get).and_return(
          instance_double(Tastytrade::Instruments::Equity, symbol: "AAPL")
        )
      end

      context "when account is restricted" do
        before do
          allow(trading_status).to receive(:restricted?).and_return(true)
          allow(trading_status).to receive(:active_restrictions)
            .and_return(["Account Frozen", "Margin Call"])
        end

        it "raises OrderValidationError with restrictions" do
          expect { validator.validate!(skip_dry_run: true) }
            .to raise_error(Tastytrade::OrderValidationError, /Account has active restrictions/)
        end
      end

      context "when account is closing only" do
        before do
          allow(trading_status).to receive(:is_closing_only).and_return(true)
        end

        it "raises OrderValidationError for opening orders" do
          expect { validator.validate!(skip_dry_run: true) }
            .to raise_error(Tastytrade::OrderValidationError, /restricted to closing orders only/)
        end
      end
    end

    context "with options order" do
      let(:option_leg) do
        instance_double(
          Tastytrade::OrderLeg,
          symbol: "AAPL 240119C150",
          quantity: 1,
          action: Tastytrade::OrderAction::BUY_TO_OPEN,
          instrument_type: "Option"
        )
      end

      before do
        allow(order).to receive(:legs).and_return([option_leg])
      end

      context "when account lacks options permissions" do
        before do
          allow(trading_status).to receive(:can_trade_options?).and_return(false)
        end

        it "raises OrderValidationError" do
          expect { validator.validate!(skip_dry_run: true) }
            .to raise_error(Tastytrade::OrderValidationError, /does not have options trading permissions/)
        end
      end

      context "when account has options permissions" do
        before do
          allow(trading_status).to receive(:can_trade_options?).and_return(true)
        end

        it "adds warning about option validation not implemented" do
          validator.validate!(skip_dry_run: true)
          expect(validator.warnings).to include(/Option symbol validation not yet implemented/)
        end
      end
    end
  end

  describe "#dry_run_validate!" do
    let(:dry_run_response) { instance_double(Tastytrade::Models::OrderResponse) }
    let(:buying_power_effect) { instance_double(Tastytrade::Models::BuyingPowerEffect) }

    before do
      allow(account).to receive(:place_order).and_return(dry_run_response)
      allow(dry_run_response).to receive(:errors).and_return([])
      allow(dry_run_response).to receive(:warnings).and_return([])
      allow(dry_run_response).to receive(:buying_power_effect).and_return(buying_power_effect)
    end

    context "when dry-run succeeds" do
      before do
        allow(buying_power_effect).to receive(:new_buying_power).and_return(BigDecimal("1000"))
        allow(buying_power_effect).to receive(:current_buying_power).and_return(BigDecimal("2000"))
        allow(buying_power_effect).to receive(:buying_power_change_amount).and_return(BigDecimal("100"))
        allow(buying_power_effect).to receive(:buying_power_usage_percentage).and_return(BigDecimal("5"))
        allow(buying_power_effect).to receive(:change_in_margin_requirement).and_return(nil)
      end

      it "returns the dry-run response" do
        expect(validator.dry_run_validate!).to eq(dry_run_response)
      end

      it "does not add errors" do
        validator.dry_run_validate!
        expect(validator.errors).to be_empty
      end
    end

    context "when dry-run returns errors" do
      let(:api_errors) do
        [
          { "domain" => "order", "reason" => "Invalid symbol" },
          { "domain" => "account", "reason" => "Insufficient funds" }
        ]
      end

      before do
        allow(dry_run_response).to receive(:errors).and_return(api_errors)
        allow(buying_power_effect).to receive(:new_buying_power).and_return(BigDecimal("1000"))
        allow(buying_power_effect).to receive(:current_buying_power).and_return(BigDecimal("2000"))
        allow(buying_power_effect).to receive(:buying_power_change_amount).and_return(BigDecimal("100"))
        allow(buying_power_effect).to receive(:buying_power_usage_percentage).and_return(BigDecimal("5"))
        allow(buying_power_effect).to receive(:change_in_margin_requirement).and_return(nil)
      end

      it "formats and adds errors" do
        validator.dry_run_validate!
        expect(validator.errors).to include("order: Invalid symbol")
        expect(validator.errors).to include("account: Insufficient funds")
      end
    end

    context "when dry-run returns warnings" do
      let(:warnings) { ["Order may be rejected during market hours", "Price outside NBBO"] }

      before do
        allow(dry_run_response).to receive(:warnings).and_return(warnings)
        allow(buying_power_effect).to receive(:new_buying_power).and_return(BigDecimal("1000"))
        allow(buying_power_effect).to receive(:current_buying_power).and_return(BigDecimal("2000"))
        allow(buying_power_effect).to receive(:buying_power_change_amount).and_return(BigDecimal("100"))
        allow(buying_power_effect).to receive(:buying_power_usage_percentage).and_return(BigDecimal("5"))
        allow(buying_power_effect).to receive(:change_in_margin_requirement).and_return(nil)
      end

      it "adds warnings" do
        validator.dry_run_validate!
        expect(validator.warnings).to include("Order may be rejected during market hours")
        expect(validator.warnings).to include("Price outside NBBO")
      end
    end

    context "with insufficient buying power" do
      before do
        allow(buying_power_effect).to receive(:new_buying_power).and_return(BigDecimal("-100"))
        allow(buying_power_effect).to receive(:current_buying_power).and_return(BigDecimal("1000"))
        allow(buying_power_effect).to receive(:buying_power_change_amount).and_return(BigDecimal("1100"))
        allow(buying_power_effect).to receive(:buying_power_usage_percentage).and_return(BigDecimal("110"))
        allow(buying_power_effect).to receive(:change_in_margin_requirement).and_return(nil)
      end

      it "adds insufficient buying power error" do
        validator.dry_run_validate!
        expect(validator.errors.first).to match(/Insufficient buying power/)
      end
    end

    context "with high buying power usage" do
      before do
        allow(buying_power_effect).to receive(:new_buying_power).and_return(BigDecimal("400"))
        allow(buying_power_effect).to receive(:current_buying_power).and_return(BigDecimal("1000"))
        allow(buying_power_effect).to receive(:buying_power_usage_percentage).and_return(BigDecimal("60"))
        allow(buying_power_effect).to receive(:change_in_margin_requirement).and_return(nil)
      end

      it "adds warning about high buying power usage" do
        validator.dry_run_validate!
        expect(validator.warnings.first).to match(/60\.0% of available buying power/)
      end
    end
  end

  describe "#round_to_tick_size" do
    it "rounds to penny increments" do
      expect(validator.send(:round_to_tick_size, BigDecimal("10.123"))).to eq(BigDecimal("10.12"))
      expect(validator.send(:round_to_tick_size, BigDecimal("10.126"))).to eq(BigDecimal("10.13"))
      expect(validator.send(:round_to_tick_size, BigDecimal("10.125"))).to eq(BigDecimal("10.13"))
    end

    it "handles nil values" do
      expect(validator.send(:round_to_tick_size, nil)).to be_nil
    end
  end

  describe "#regular_market_hours?" do
    it "returns true during market hours" do
      market_time = Time.parse("2024-01-10 10:30:00")
      expect(validator.send(:regular_market_hours?, market_time)).to be true

      market_time = Time.parse("2024-01-10 15:30:00")
      expect(validator.send(:regular_market_hours?, market_time)).to be true
    end

    it "returns false outside market hours" do
      pre_market = Time.parse("2024-01-10 08:00:00")
      expect(validator.send(:regular_market_hours?, pre_market)).to be false

      after_hours = Time.parse("2024-01-10 17:00:00")
      expect(validator.send(:regular_market_hours?, after_hours)).to be false

      early_morning = Time.parse("2024-01-10 09:15:00")
      expect(validator.send(:regular_market_hours?, early_morning)).to be false
    end
  end

  describe "#weekend?" do
    it "returns true on weekends" do
      saturday = Time.parse("2024-01-13 12:00:00")
      expect(validator.send(:weekend?, saturday)).to be true

      sunday = Time.parse("2024-01-14 12:00:00")
      expect(validator.send(:weekend?, sunday)).to be true
    end

    it "returns false on weekdays" do
      monday = Time.parse("2024-01-15 12:00:00")
      expect(validator.send(:weekend?, monday)).to be false

      friday = Time.parse("2024-01-12 12:00:00")
      expect(validator.send(:weekend?, friday)).to be false
    end
  end
end
