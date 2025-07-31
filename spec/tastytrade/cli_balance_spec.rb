# frozen_string_literal: true

require "spec_helper"
require "tastytrade/cli"

RSpec.describe "Tastytrade::CLI balance command" do
  let(:cli) { Tastytrade::CLI.new }

  describe "#balance" do
    it "displays not implemented message" do
      expect { cli.balance }.to output("Balance command not yet implemented\n").to_stdout
    end
  end
end
