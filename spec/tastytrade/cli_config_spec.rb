# frozen_string_literal: true

require "spec_helper"
require "tastytrade/cli_config"
require "tmpdir"
require "fileutils"

RSpec.describe Tastytrade::CLIConfig do
  let(:temp_dir) { Dir.mktmpdir }
  let(:config_dir) { File.join(temp_dir, ".config", "tastytrade") }
  let(:config_file) { File.join(config_dir, "config.yml") }

  before do
    # Override the config directory for testing
    stub_const("Tastytrade::CLIConfig::CONFIG_DIR", config_dir)
    stub_const("Tastytrade::CLIConfig::CONFIG_FILE", config_file)
  end

  after do
    FileUtils.rm_rf(temp_dir)
  end

  describe "#initialize" do
    context "when config file doesn't exist" do
      it "creates config directory" do
        described_class.new
        expect(Dir.exist?(config_dir)).to be true
      end

      it "loads default configuration" do
        config = described_class.new
        expect(config.data).to eq(described_class::DEFAULT_CONFIG)
      end
    end

    context "when config file exists" do
      before do
        FileUtils.mkdir_p(config_dir)
        File.write(config_file, { "default_account" => "123456" }.to_yaml)
      end

      it "loads config from file" do
        config = described_class.new
        expect(config.get("default_account")).to eq("123456")
      end

      it "merges with default config" do
        config = described_class.new
        expect(config.get("environment")).to eq("production") # from defaults
        expect(config.get("default_account")).to eq("123456") # from file
      end
    end

    context "when config file is corrupted" do
      before do
        FileUtils.mkdir_p(config_dir)
        File.write(config_file, "invalid yaml: [")
      end

      it "loads default config and warns" do
        expect { described_class.new }.to output(/Warning: Failed to load config file/).to_stderr
        config = described_class.new
        expect(config.data).to eq(described_class::DEFAULT_CONFIG)
      end
    end
  end

  describe "#get" do
    let(:config) { described_class.new }

    it "returns value for existing key" do
      expect(config.get("environment")).to eq("production")
    end

    it "returns nil for non-existent key" do
      expect(config.get("non_existent")).to be_nil
    end

    it "accepts symbol keys" do
      expect(config.get(:environment)).to eq("production")
    end
  end

  describe "#set" do
    let(:config) { described_class.new }

    it "sets a new value" do
      config.set("test_key", "test_value")
      expect(config.get("test_key")).to eq("test_value")
    end

    it "updates existing value" do
      config.set("environment", "sandbox")
      expect(config.get("environment")).to eq("sandbox")
    end

    it "saves to file" do
      config.set("test_key", "test_value")

      # Load a new config instance to verify persistence
      new_config = described_class.new
      expect(new_config.get("test_key")).to eq("test_value")
    end

    it "accepts symbol keys" do
      config.set(:test_key, "test_value")
      expect(config.get("test_key")).to eq("test_value")
    end
  end

  describe "#delete" do
    let(:config) { described_class.new }

    before do
      config.set("test_key", "test_value")
    end

    it "removes the key" do
      config.delete("test_key")
      expect(config.get("test_key")).to be_nil
    end

    it "saves changes to file" do
      config.delete("test_key")

      new_config = described_class.new
      expect(new_config.get("test_key")).to be_nil
    end
  end

  describe "#exists?" do
    it "returns false when config doesn't exist" do
      config = described_class.new
      expect(config.exists?).to be false # file not created until save
    end

    it "returns true when config exists" do
      config = described_class.new
      config.set("test", "value") # This triggers save
      expect(config.exists?).to be true
    end
  end

  describe "#reset!" do
    let(:config) { described_class.new }

    before do
      config.set("test_key", "test_value")
      config.set("environment", "sandbox")
    end

    it "resets to default values" do
      config.reset!
      expect(config.data).to eq(described_class::DEFAULT_CONFIG)
      expect(config.get("test_key")).to be_nil
      expect(config.get("environment")).to eq("production")
    end

    it "saves defaults to file" do
      config.reset!

      new_config = described_class.new
      expect(new_config.data).to eq(described_class::DEFAULT_CONFIG)
    end
  end

  describe "error handling" do
    let(:config) { described_class.new }

    context "when save fails" do
      before do
        allow(File).to receive(:write).and_raise(StandardError.new("Permission denied"))
      end

      it "warns but doesn't raise" do
        expect { config.set("test", "value") }.to output(/Warning: Failed to save config file/).to_stderr
      end
    end
  end
end
