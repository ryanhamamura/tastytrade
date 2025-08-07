# frozen_string_literal: true

require "spec_helper"

RSpec.describe Tastytrade::Models::OrderStatus do
  describe "constants" do
    it "defines submission phase statuses" do
      expect(described_class::RECEIVED).to eq("Received")
      expect(described_class::ROUTED).to eq("Routed")
      expect(described_class::IN_FLIGHT).to eq("In Flight")
      expect(described_class::CONTINGENT).to eq("Contingent")
    end

    it "defines working phase statuses" do
      expect(described_class::LIVE).to eq("Live")
      expect(described_class::CANCEL_REQUESTED).to eq("Cancel Requested")
      expect(described_class::REPLACE_REQUESTED).to eq("Replace Requested")
    end

    it "defines terminal phase statuses" do
      expect(described_class::FILLED).to eq("Filled")
      expect(described_class::CANCELLED).to eq("Cancelled")
      expect(described_class::REJECTED).to eq("Rejected")
      expect(described_class::EXPIRED).to eq("Expired")
      expect(described_class::REMOVED).to eq("Removed")
    end
  end

  describe ".submission?" do
    it "returns true for submission statuses" do
      expect(described_class.submission?("Received")).to be true
      expect(described_class.submission?("Routed")).to be true
      expect(described_class.submission?("In Flight")).to be true
      expect(described_class.submission?("Contingent")).to be true
    end

    it "returns false for non-submission statuses" do
      expect(described_class.submission?("Live")).to be false
      expect(described_class.submission?("Filled")).to be false
      expect(described_class.submission?("Cancelled")).to be false
    end
  end

  describe ".working?" do
    it "returns true for working statuses" do
      expect(described_class.working?("Live")).to be true
      expect(described_class.working?("Cancel Requested")).to be true
      expect(described_class.working?("Replace Requested")).to be true
    end

    it "returns false for non-working statuses" do
      expect(described_class.working?("Received")).to be false
      expect(described_class.working?("Filled")).to be false
      expect(described_class.working?("Cancelled")).to be false
    end
  end

  describe ".terminal?" do
    it "returns true for terminal statuses" do
      expect(described_class.terminal?("Filled")).to be true
      expect(described_class.terminal?("Cancelled")).to be true
      expect(described_class.terminal?("Rejected")).to be true
      expect(described_class.terminal?("Expired")).to be true
      expect(described_class.terminal?("Removed")).to be true
    end

    it "returns false for non-terminal statuses" do
      expect(described_class.terminal?("Live")).to be false
      expect(described_class.terminal?("Received")).to be false
      expect(described_class.terminal?("Routed")).to be false
    end
  end

  describe ".cancellable?" do
    it "returns true only for Live status" do
      expect(described_class.cancellable?("Live")).to be true
    end

    it "returns false for other statuses" do
      expect(described_class.cancellable?("Received")).to be false
      expect(described_class.cancellable?("Filled")).to be false
      expect(described_class.cancellable?("Cancel Requested")).to be false
    end
  end

  describe ".editable?" do
    it "returns true only for Live status" do
      expect(described_class.editable?("Live")).to be true
    end

    it "returns false for other statuses" do
      expect(described_class.editable?("Received")).to be false
      expect(described_class.editable?("Filled")).to be false
      expect(described_class.editable?("Replace Requested")).to be false
    end
  end

  describe ".valid?" do
    it "returns true for all valid statuses" do
      all_statuses = described_class::ALL_STATUSES
      all_statuses.each do |status|
        expect(described_class.valid?(status)).to be true
      end
    end

    it "returns false for invalid statuses" do
      expect(described_class.valid?("Invalid")).to be false
      expect(described_class.valid?("Unknown")).to be false
      expect(described_class.valid?("")).to be false
      expect(described_class.valid?(nil)).to be false
    end
  end
end
