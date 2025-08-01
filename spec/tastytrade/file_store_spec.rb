# frozen_string_literal: true

require "spec_helper"
require "tastytrade/file_store"
require "tmpdir"

RSpec.describe Tastytrade::FileStore do
  let(:test_key) { "test_user_production" }
  let(:test_value) { "test_token_123" }

  let(:tmpdir) { Dir.mktmpdir }

  before do
    allow(described_class).to receive(:storage_directory).and_return(tmpdir)
  end

  after do
    FileUtils.rm_rf(tmpdir) if File.exist?(tmpdir)
  end

  describe ".set" do
    it "stores a credential successfully" do
      expect(described_class.set(test_key, test_value)).to be true
    end

    it "creates the storage directory with proper permissions" do
      described_class.set(test_key, test_value)
      storage_dir = described_class.send(:storage_directory)
      expect(File.exist?(storage_dir)).to be true
      expect(File.stat(storage_dir).mode & 0o777).to eq(0o700)
    end

    it "creates credential files with proper permissions" do
      described_class.set(test_key, test_value)
      cred_path = described_class.send(:credential_path, test_key)
      expect(File.stat(cred_path).mode & 0o777).to eq(0o600)
    end

    it "returns false for nil key" do
      expect(described_class.set(nil, test_value)).to be false
    end

    it "returns false for nil value" do
      expect(described_class.set(test_key, nil)).to be false
    end

    it "handles errors gracefully" do
      allow(File).to receive(:write).and_raise(StandardError, "Write error")
      expect(described_class.set(test_key, test_value)).to be false
    end

    it "converts symbols to strings" do
      expect(described_class.set(:test_key, :test_value)).to be true
      expect(described_class.get(:test_key)).to eq("test_value")
    end
  end

  describe ".get" do
    it "retrieves a credential successfully" do
      described_class.set(test_key, test_value)
      expect(described_class.get(test_key)).to eq(test_value)
    end

    it "returns nil for nil key" do
      expect(described_class.get(nil)).to be nil
    end

    it "returns nil for non-existent key" do
      expect(described_class.get("non_existent")).to be nil
    end

    it "handles errors gracefully" do
      described_class.set(test_key, test_value)
      allow(File).to receive(:read).and_raise(StandardError, "Read error")
      expect(described_class.get(test_key)).to be nil
    end

    it "converts symbols to strings" do
      described_class.set(:test_key, "value")
      expect(described_class.get(:test_key)).to eq("value")
    end
  end

  describe ".delete" do
    it "deletes a credential successfully" do
      described_class.set(test_key, test_value)
      expect(described_class.delete(test_key)).to be true
      expect(described_class.get(test_key)).to be nil
    end

    it "returns false for nil key" do
      expect(described_class.delete(nil)).to be false
    end

    it "returns true for non-existent key" do
      expect(described_class.delete("non_existent")).to be true
    end

    it "handles errors gracefully" do
      described_class.set(test_key, test_value)
      allow(File).to receive(:delete).and_raise(StandardError, "Delete error")
      expect(described_class.delete(test_key)).to be false
    end
  end

  describe ".available?" do
    it "always returns true" do
      expect(described_class.available?).to be true
    end
  end

  describe "credential_path sanitization" do
    it "sanitizes unsafe characters in keys" do
      unsafe_key = "user@example.com/../../etc/passwd"
      safe_path = described_class.send(:credential_path, unsafe_key)
      expect(safe_path).to include("user@example.com_.._.._etc_passwd.cred")
      expect(safe_path).not_to include("/../")
    end

    it "preserves allowed characters" do
      safe_key = "user@example.com_production-123"
      path = described_class.send(:credential_path, safe_key)
      expect(path).to include("user@example.com_production-123.cred")
    end
  end
end
