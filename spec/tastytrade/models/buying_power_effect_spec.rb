# frozen_string_literal: true

require "spec_helper"
require "bigdecimal"

RSpec.describe Tastytrade::Models::BuyingPowerEffect do
  let(:buying_power_effect_data) do
    {
      "change-in-margin-requirement" => "-125.0",
      "change-in-buying-power" => "-125.004",
      "current-buying-power" => "1000.0",
      "new-buying-power" => "874.996",
      "isolated-order-margin-requirement" => "-125.0",
      "is-spread" => false,
      "impact" => "125.004",
      "effect" => "Debit"
    }
  end

  subject { described_class.new(buying_power_effect_data) }

  describe "#initialize" do
    it "parses all attributes correctly" do
      expect(subject.change_in_margin_requirement).to eq(BigDecimal("-125.0"))
      expect(subject.change_in_buying_power).to eq(BigDecimal("-125.004"))
      expect(subject.current_buying_power).to eq(BigDecimal("1000.0"))
      expect(subject.new_buying_power).to eq(BigDecimal("874.996"))
      expect(subject.isolated_order_margin_requirement).to eq(BigDecimal("-125.0"))
      expect(subject.is_spread).to eq(false)
      expect(subject.impact).to eq(BigDecimal("125.004"))
      expect(subject.effect).to eq("Debit")
    end

    context "with nil values" do
      let(:buying_power_effect_data) do
        {
          "change-in-margin-requirement" => nil,
          "change-in-buying-power" => "",
          "current-buying-power" => "1000.0",
          "effect" => "Debit"
        }
      end

      it "handles nil and empty values gracefully" do
        expect(subject.change_in_margin_requirement).to be_nil
        expect(subject.change_in_buying_power).to be_nil
        expect(subject.current_buying_power).to eq(BigDecimal("1000.0"))
      end
    end
  end

  describe "#buying_power_usage_percentage" do
    it "calculates the percentage correctly" do
      # 125.004 / 1000.0 * 100 = 12.5004
      expect(subject.buying_power_usage_percentage).to eq(BigDecimal("12.50"))
    end

    context "with zero current buying power" do
      let(:buying_power_effect_data) do
        {
          "current-buying-power" => "0",
          "impact" => "100.0"
        }
      end

      it "returns zero" do
        expect(subject.buying_power_usage_percentage).to eq(BigDecimal("0"))
      end
    end

    context "with nil current buying power" do
      let(:buying_power_effect_data) do
        {
          "current-buying-power" => nil,
          "impact" => "100.0"
        }
      end

      it "returns zero" do
        expect(subject.buying_power_usage_percentage).to eq(BigDecimal("0"))
      end
    end

    context "using change-in-buying-power when impact is nil" do
      let(:buying_power_effect_data) do
        {
          "change-in-buying-power" => "-200.50",
          "current-buying-power" => "1000.0",
          "impact" => nil
        }
      end

      it "uses the absolute value of change-in-buying-power" do
        # 200.50 / 1000.0 * 100 = 20.05
        expect(subject.buying_power_usage_percentage).to eq(BigDecimal("20.05"))
      end
    end
  end

  describe "#exceeds_threshold?" do
    it "returns true when usage exceeds threshold" do
      expect(subject.exceeds_threshold?(10)).to be true
      expect(subject.exceeds_threshold?("10.0")).to be true
    end

    it "returns false when usage is below threshold" do
      expect(subject.exceeds_threshold?(15)).to be false
      expect(subject.exceeds_threshold?(20)).to be false
    end

    it "returns false when usage equals threshold" do
      expect(subject.exceeds_threshold?(12.50)).to be false
    end
  end

  describe "#buying_power_change_amount" do
    it "returns the absolute value of the change" do
      expect(subject.buying_power_change_amount).to eq(BigDecimal("125.004"))
    end

    context "with positive change" do
      let(:buying_power_effect_data) do
        {
          "change-in-buying-power" => "150.00",
          "current-buying-power" => "1000.0"
        }
      end

      it "returns the absolute value" do
        expect(subject.buying_power_change_amount).to eq(BigDecimal("150.00"))
      end
    end

    context "using impact when change-in-buying-power is nil" do
      let(:buying_power_effect_data) do
        {
          "change-in-buying-power" => nil,
          "impact" => "75.50"
        }
      end

      it "returns the impact absolute value" do
        expect(subject.buying_power_change_amount).to eq(BigDecimal("75.50"))
      end
    end

    context "with all nil values" do
      let(:buying_power_effect_data) do
        {
          "change-in-buying-power" => nil,
          "impact" => nil
        }
      end

      it "returns zero" do
        expect(subject.buying_power_change_amount).to eq(BigDecimal("0"))
      end
    end
  end

  describe "#debit?" do
    it "returns true for debit effects" do
      expect(subject.debit?).to be true
    end

    context "with credit effect" do
      let(:buying_power_effect_data) do
        {
          "effect" => "Credit",
          "change-in-buying-power" => "100.0"
        }
      end

      it "returns false" do
        expect(subject.debit?).to be false
      end
    end

    context "with negative change and no effect field" do
      let(:buying_power_effect_data) do
        {
          "change-in-buying-power" => "-50.0",
          "effect" => nil
        }
      end

      it "returns true based on negative change" do
        expect(subject.debit?).to be true
      end
    end

    context "with positive change and no effect field" do
      let(:buying_power_effect_data) do
        {
          "change-in-buying-power" => "50.0",
          "effect" => nil
        }
      end

      it "returns false based on positive change" do
        expect(subject.debit?).to be false
      end
    end
  end

  describe "#credit?" do
    context "with credit effect" do
      let(:buying_power_effect_data) do
        {
          "effect" => "Credit",
          "change-in-buying-power" => "100.0"
        }
      end

      it "returns true" do
        expect(subject.credit?).to be true
      end
    end

    it "returns false for debit effects" do
      expect(subject.credit?).to be false
    end

    context "with positive change and no effect field" do
      let(:buying_power_effect_data) do
        {
          "change-in-buying-power" => "75.0",
          "effect" => nil
        }
      end

      it "returns true based on positive change" do
        expect(subject.credit?).to be true
      end
    end
  end

  describe "attribute readers" do
    it "provides access to all attributes" do
      expect(subject).to respond_to(:change_in_margin_requirement)
      expect(subject).to respond_to(:change_in_buying_power)
      expect(subject).to respond_to(:current_buying_power)
      expect(subject).to respond_to(:new_buying_power)
      expect(subject).to respond_to(:isolated_order_margin_requirement)
      expect(subject).to respond_to(:is_spread)
      expect(subject).to respond_to(:impact)
      expect(subject).to respond_to(:effect)
    end
  end
end
