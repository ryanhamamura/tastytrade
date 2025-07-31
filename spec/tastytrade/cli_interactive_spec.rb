# frozen_string_literal: true

require "spec_helper"
require "tastytrade/cli"

RSpec.describe "Tastytrade::CLI interactive command" do
  let(:cli) { Tastytrade::CLI.new }
  let(:session) { instance_double(Tastytrade::Session) }
  let(:prompt) { instance_double(TTY::Prompt) }
  let(:config) { instance_double(Tastytrade::CLIConfig) }

  before do
    allow(cli).to receive(:prompt).and_return(prompt)
    allow(cli).to receive(:config).and_return(config)
    allow(cli).to receive(:exit)
    allow(config).to receive(:get).with("current_account_number").and_return(nil)
  end

  describe "#interactive" do
    context "when authenticated" do
      before do
        allow(cli).to receive(:current_session).and_return(session)
        allow(cli).to receive(:interactive_mode)
      end

      it "enters interactive mode" do
        expect(cli).to receive(:interactive_mode)
        cli.interactive
      end
    end

    context "when not authenticated" do
      before do
        allow(cli).to receive(:current_session).and_return(nil)
        allow(cli).to receive(:exit).with(1).and_raise(SystemExit)
      end

      it "requires authentication" do
        expect { cli.interactive }.to raise_error(SystemExit)
          .and output(/You must be logged in/).to_stderr
      end

      it "suggests login command" do
        expect { cli.interactive }.to raise_error(SystemExit)
          .and output(/Run 'tastytrade login'/).to_stdout
      end

      it "does not enter interactive mode" do
        expect(cli).not_to receive(:interactive_mode)
        expect { cli.interactive }.to raise_error(SystemExit)
      end
    end
  end
end
