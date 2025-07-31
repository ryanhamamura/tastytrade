# frozen_string_literal: true

require "spec_helper"
require "tastytrade/cli_helpers"
require "tastytrade/cli_config"

RSpec.describe Tastytrade::CLIHelpers do
  # Create a test class that includes the module
  let(:test_class) do
    Class.new do
      include Tastytrade::CLIHelpers
    end
  end

  let(:instance) { test_class.new }

  describe "output helpers" do
    describe "#error" do
      it "outputs red error message to stderr" do
        expect { instance.error("Something went wrong") }
          .to output(/Error: Something went wrong/).to_stderr
      end
    end

    describe "#warning" do
      it "outputs yellow warning message to stderr" do
        expect { instance.warning("Be careful") }
          .to output(/Warning: Be careful/).to_stderr
      end
    end

    describe "#success" do
      it "outputs green success message with checkmark" do
        expect { instance.success("Operation completed") }
          .to output(/✓ Operation completed/).to_stdout
      end
    end

    describe "#info" do
      it "outputs cyan info message with arrow" do
        expect { instance.info("Processing...") }
          .to output(/→ Processing.../).to_stdout
      end
    end
  end

  describe "#format_currency" do
    it "formats nil as $0.00" do
      expect(instance.format_currency(nil)).to eq("$0.00")
    end

    it "formats zero as $0.00" do
      expect(instance.format_currency(0)).to eq("$0.00")
    end

    it "formats positive values" do
      expect(instance.format_currency(1234.56)).to eq("$1,234.56")
    end

    it "formats negative values" do
      expect(instance.format_currency(-1234.56)).to eq("-$1,234.56")
    end

    it "formats small values" do
      expect(instance.format_currency(0.99)).to eq("$0.99")
    end

    it "formats large values with commas" do
      expect(instance.format_currency(1_234_567.89)).to eq("$1,234,567.89")
    end
  end

  describe "#color_value" do
    it "colors positive values green" do
      result = instance.color_value(100)
      expect(result).to include("$100.00")
      # Pastel adds ANSI codes, so we check for presence of the value
      expect(instance.pastel.strip(result)).to eq("$100.00")
    end

    it "colors negative values red" do
      result = instance.color_value(-100)
      expect(result).to include("$100.00")
      expect(instance.pastel.strip(result)).to eq("-$100.00")
    end

    it "colors zero as dim" do
      result = instance.color_value(0)
      expect(instance.pastel.strip(result)).to eq("$0.00")
    end

    it "can format without currency" do
      result = instance.color_value(42, format_as_currency: false)
      expect(instance.pastel.strip(result)).to eq("42")
    end
  end

  describe "#pastel" do
    it "returns a Pastel instance" do
      expect(instance.pastel).to be_a(Pastel::Delegator)
    end

    it "memoizes the instance" do
      pastel1 = instance.pastel
      pastel2 = instance.pastel
      expect(pastel1).to be(pastel2)
    end
  end

  describe "#prompt" do
    it "returns a TTY::Prompt instance" do
      expect(instance.prompt).to be_a(TTY::Prompt)
    end

    it "memoizes the instance" do
      prompt1 = instance.prompt
      prompt2 = instance.prompt
      expect(prompt1).to be(prompt2)
    end
  end

  describe "#config" do
    it "returns a Config instance" do
      expect(instance.config).to be_a(Tastytrade::CLIConfig)
    end

    it "memoizes the instance" do
      config1 = instance.config
      config2 = instance.config
      expect(config1).to be(config2)
    end
  end

  describe "authentication helpers" do
    describe "#authenticated?" do
      context "when no session exists" do
        it "returns false" do
          expect(instance.authenticated?).to be false
        end
      end
    end

    describe "#require_authentication!" do
      context "when not authenticated" do
        it "exits with error message" do
          expect(instance).to receive(:exit).with(1)
          expect { instance.require_authentication! }
            .to output(/You must be logged in/).to_stderr
        end

        it "suggests login command" do
          expect(instance).to receive(:exit).with(1)
          expect { instance.require_authentication! }
            .to output(/Run 'tastytrade login'/).to_stdout
        end
      end
    end
  end

  describe "class methods" do
    it "sets exit_on_failure? to true" do
      expect(test_class.exit_on_failure?).to be true
    end
  end
end
