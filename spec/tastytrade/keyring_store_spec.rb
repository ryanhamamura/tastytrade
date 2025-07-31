# frozen_string_literal: true

require "spec_helper"
require "tastytrade/keyring_store"

RSpec.describe Tastytrade::KeyringStore do
  let(:mock_backend) { instance_double(Keyring) }

  before do
    # Reset the backend before each test
    described_class.instance_variable_set(:@backend, nil)
    allow(Keyring).to receive(:new).and_return(mock_backend)
    # Suppress warnings during tests
    allow(described_class).to receive(:warn)
  end

  describe ".set" do
    it "stores a credential successfully" do
      expect(mock_backend).to receive(:set_password)
        .with("tastytrade-ruby", "test_key", "test_value")

      expect(described_class.set("test_key", "test_value")).to be true
    end

    it "returns false for nil key" do
      expect(mock_backend).not_to receive(:set_password)
      expect(described_class.set(nil, "value")).to be false
    end

    it "returns false for nil value" do
      expect(mock_backend).not_to receive(:set_password)
      expect(described_class.set("key", nil)).to be false
    end

    it "handles errors gracefully" do
      expect(mock_backend).to receive(:set_password)
        .and_raise(StandardError, "Keyring error")

      expect(described_class.set("key", "value")).to be false
    end

    it "converts symbols to strings" do
      expect(mock_backend).to receive(:set_password)
        .with("tastytrade-ruby", "symbol_key", "value")

      described_class.set(:symbol_key, "value")
    end
  end

  describe ".get" do
    it "retrieves a credential successfully" do
      expect(mock_backend).to receive(:get_password)
        .with("tastytrade-ruby", "test_key")
        .and_return("test_value")

      expect(described_class.get("test_key")).to eq("test_value")
    end

    it "returns nil for nil key" do
      expect(mock_backend).not_to receive(:get_password)
      expect(described_class.get(nil)).to be_nil
    end

    it "handles errors gracefully" do
      expect(mock_backend).to receive(:get_password)
        .and_raise(StandardError, "Keyring error")

      expect(described_class.get("key")).to be_nil
    end

    it "converts symbols to strings" do
      expect(mock_backend).to receive(:get_password)
        .with("tastytrade-ruby", "symbol_key")
        .and_return("value")

      expect(described_class.get(:symbol_key)).to eq("value")
    end
  end

  describe ".delete" do
    it "deletes a credential successfully" do
      expect(mock_backend).to receive(:delete_password)
        .with("tastytrade-ruby", "test_key")

      expect(described_class.delete("test_key")).to be true
    end

    it "returns false for nil key" do
      expect(mock_backend).not_to receive(:delete_password)
      expect(described_class.delete(nil)).to be false
    end

    it "handles errors gracefully" do
      expect(mock_backend).to receive(:delete_password)
        .and_raise(StandardError, "Keyring error")

      expect(described_class.delete("key")).to be false
    end
  end

  describe ".available?" do
    context "when keyring is available" do
      it "returns true" do
        expect(described_class.available?).to be true
      end
    end

    context "when keyring is not available" do
      before do
        allow(Keyring).to receive(:new).and_raise(StandardError, "No backend")
      end

      it "returns false" do
        expect(described_class.available?).to be false
      end
    end

    context "when backend is nil" do
      before do
        allow(Keyring).to receive(:new).and_return(nil)
      end

      it "returns false" do
        expect(described_class.available?).to be false
      end
    end
  end

  describe "error messages" do
    context "when warnings are not suppressed" do
      before do
        allow(described_class).to receive(:warn).and_call_original
      end

      it "warns on set failure" do
        expect(mock_backend).to receive(:set_password)
          .and_raise(StandardError, "Set error")

        expect { described_class.set("key", "value") }
          .to output(/Failed to store credential: Set error/).to_stderr
      end

      it "warns on get failure" do
        expect(mock_backend).to receive(:get_password)
          .and_raise(StandardError, "Get error")

        expect { described_class.get("key") }
          .to output(/Failed to retrieve credential: Get error/).to_stderr
      end

      it "warns on delete failure" do
        expect(mock_backend).to receive(:delete_password)
          .and_raise(StandardError, "Delete error")

        expect { described_class.delete("key") }
          .to output(/Failed to delete credential: Delete error/).to_stderr
      end

      it "warns when keyring is not available" do
        allow(Keyring).to receive(:new).and_raise(StandardError, "No backend")

        # Force backend initialization
        expect { described_class.send(:backend) }
          .to output(/Keyring not available: No backend/).to_stderr
      end
    end
  end
end
