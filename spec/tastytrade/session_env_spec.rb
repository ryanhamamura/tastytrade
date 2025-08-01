# frozen_string_literal: true

require "spec_helper"

RSpec.describe Tastytrade::Session do
  describe ".from_environment" do
    around do |example|
      # Save original environment
      original_env = ENV.to_hash

      # Clear relevant environment variables
      %w[TASTYTRADE_USERNAME TT_USERNAME TASTYTRADE_PASSWORD TT_PASSWORD
         TASTYTRADE_REMEMBER TT_REMEMBER TASTYTRADE_ENVIRONMENT TT_ENVIRONMENT].each do |key|
        ENV.delete(key)
      end

      example.run

      # Restore original environment
      ENV.clear
      ENV.update(original_env)
    end

    context "with TASTYTRADE_ prefixed variables" do
      before do
        ENV["TASTYTRADE_USERNAME"] = "test@example.com"
        ENV["TASTYTRADE_PASSWORD"] = "test_password"
      end

      it "creates a session with username and password" do
        session = described_class.from_environment
        expect(session).not_to be_nil
        expect(session.instance_variable_get(:@username)).to eq("test@example.com")
        expect(session.instance_variable_get(:@password)).to eq("test_password")
      end

      it "defaults to production environment" do
        session = described_class.from_environment
        expect(session.is_test).to be false
      end

      it "defaults to remember_me false" do
        session = described_class.from_environment
        expect(session.instance_variable_get(:@remember_me)).to be false
      end

      context "with TASTYTRADE_REMEMBER set to true" do
        before do
          ENV["TASTYTRADE_REMEMBER"] = "true"
        end

        it "enables remember_me" do
          session = described_class.from_environment
          expect(session.instance_variable_get(:@remember_me)).to be true
        end
      end

      context "with TASTYTRADE_REMEMBER set to TRUE" do
        before do
          ENV["TASTYTRADE_REMEMBER"] = "TRUE"
        end

        it "enables remember_me (case insensitive)" do
          session = described_class.from_environment
          expect(session.instance_variable_get(:@remember_me)).to be true
        end
      end

      context "with TASTYTRADE_ENVIRONMENT set to sandbox" do
        before do
          ENV["TASTYTRADE_ENVIRONMENT"] = "sandbox"
        end

        it "sets is_test to true" do
          session = described_class.from_environment
          expect(session.is_test).to be true
        end
      end

      context "with TASTYTRADE_ENVIRONMENT set to SANDBOX" do
        before do
          ENV["TASTYTRADE_ENVIRONMENT"] = "SANDBOX"
        end

        it "sets is_test to true (case insensitive)" do
          session = described_class.from_environment
          expect(session.is_test).to be true
        end
      end
    end

    context "with TT_ prefixed variables" do
      before do
        ENV["TT_USERNAME"] = "tt@example.com"
        ENV["TT_PASSWORD"] = "tt_password"
      end

      it "creates a session with username and password" do
        session = described_class.from_environment
        expect(session).not_to be_nil
        expect(session.instance_variable_get(:@username)).to eq("tt@example.com")
        expect(session.instance_variable_get(:@password)).to eq("tt_password")
      end

      context "with TT_REMEMBER set" do
        before do
          ENV["TT_REMEMBER"] = "true"
        end

        it "enables remember_me" do
          session = described_class.from_environment
          expect(session.instance_variable_get(:@remember_me)).to be true
        end
      end

      context "with TT_ENVIRONMENT set to sandbox" do
        before do
          ENV["TT_ENVIRONMENT"] = "sandbox"
        end

        it "sets is_test to true" do
          session = described_class.from_environment
          expect(session.is_test).to be true
        end
      end
    end

    context "with both TASTYTRADE_ and TT_ variables" do
      before do
        ENV["TASTYTRADE_USERNAME"] = "tastytrade@example.com"
        ENV["TT_USERNAME"] = "tt@example.com"
        ENV["TASTYTRADE_PASSWORD"] = "tastytrade_password"
        ENV["TT_PASSWORD"] = "tt_password"
      end

      it "prefers TASTYTRADE_ prefixed variables" do
        session = described_class.from_environment
        expect(session.instance_variable_get(:@username)).to eq("tastytrade@example.com")
        expect(session.instance_variable_get(:@password)).to eq("tastytrade_password")
      end
    end

    context "with missing username" do
      before do
        ENV["TASTYTRADE_PASSWORD"] = "test_password"
      end

      it "returns nil" do
        expect(described_class.from_environment).to be_nil
      end
    end

    context "with missing password" do
      before do
        ENV["TASTYTRADE_USERNAME"] = "test@example.com"
      end

      it "returns nil" do
        expect(described_class.from_environment).to be_nil
      end
    end

    context "with no environment variables set" do
      it "returns nil" do
        expect(described_class.from_environment).to be_nil
      end
    end
  end
end
