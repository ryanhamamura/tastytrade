# frozen_string_literal: true

require "spec_helper"

RSpec.describe Tastytrade::Models::Base do
  let(:test_class) do
    Class.new(described_class) do
      attr_reader :test_attr, :parsed_time

      private

      def parse_attributes
        @test_attr = @data["test-attr"]
        @parsed_time = parse_time(@data["time-field"])
      end
    end
  end

  describe "#initialize" do
    it "accepts hash with string keys" do
      instance = test_class.new("test-attr" => "value")
      expect(instance.test_attr).to eq("value")
    end

    it "accepts hash with symbol keys" do
      instance = test_class.new(test_attr: "value")
      expect(instance.data["test_attr"]).to eq("value")
    end

    it "stores raw data" do
      data = { "test-attr" => "value", "other" => "data" }
      instance = test_class.new(data)
      expect(instance.data).to eq(data.transform_keys(&:to_s))
    end
  end

  describe "#parse_time" do
    let(:instance) { test_class.new({}) }

    it "parses valid ISO 8601 datetime" do
      instance = test_class.new("time-field" => "2025-07-30T10:30:00Z")
      expect(instance.parsed_time).to be_a(Time)
      expect(instance.parsed_time.year).to eq(2025)
    end

    it "returns nil for nil value" do
      instance = test_class.new("time-field" => nil)
      expect(instance.parsed_time).to be_nil
    end

    it "returns nil for empty string" do
      instance = test_class.new("time-field" => "")
      expect(instance.parsed_time).to be_nil
    end

    it "returns nil for invalid datetime" do
      instance = test_class.new("time-field" => "not a date")
      expect(instance.parsed_time).to be_nil
    end
  end
end
