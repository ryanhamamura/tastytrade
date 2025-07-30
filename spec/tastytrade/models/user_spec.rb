# frozen_string_literal: true

require "spec_helper"

RSpec.describe Tastytrade::Models::User do
  let(:user_data) do
    {
      "email" => "test@example.com",
      "username" => "testuser",
      "external-id" => "ext-123",
      "is-professional" => false
    }
  end

  subject(:user) { described_class.new(user_data) }

  describe "#email" do
    it "returns the email" do
      expect(user.email).to eq("test@example.com")
    end
  end

  describe "#username" do
    it "returns the username" do
      expect(user.username).to eq("testuser")
    end
  end

  describe "#external_id" do
    it "returns the external ID" do
      expect(user.external_id).to eq("ext-123")
    end
  end

  describe "#professional?" do
    context "when is-professional is true" do
      let(:user_data) { super().merge("is-professional" => true) }

      it "returns true" do
        expect(user.professional?).to be true
      end
    end

    context "when is-professional is false" do
      it "returns false" do
        expect(user.professional?).to be false
      end
    end

    context "when is-professional is nil" do
      let(:user_data) { super().merge("is-professional" => nil) }

      it "returns false" do
        expect(user.professional?).to be false
      end
    end
  end
end
