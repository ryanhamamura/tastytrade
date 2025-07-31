# frozen_string_literal: true

require "spec_helper"
require "tastytrade/cli"

RSpec.describe "Tastytrade::CLI select command" do
  let(:cli) { Tastytrade::CLI.new }
  let(:config) { instance_double(Tastytrade::CLIConfig) }
  let(:prompt) { instance_double(TTY::Prompt) }
  let(:session) { instance_double(Tastytrade::Session) }
  let(:account1) do
    instance_double(Tastytrade::Models::Account,
                    account_number: "5WX12345",
                    nickname: "Main Account",
                    account_type_name: "Margin")
  end
  let(:account2) do
    instance_double(Tastytrade::Models::Account,
                    account_number: "5WX67890",
                    nickname: nil,
                    account_type_name: "Cash")
  end

  before do
    allow(cli).to receive(:config).and_return(config)
    allow(cli).to receive(:prompt).and_return(prompt)
    allow(cli).to receive(:exit) # Prevent actual exit during tests
    allow(cli).to receive(:current_session).and_return(session)
    allow(cli).to receive(:authenticated?).and_return(true)
    allow(config).to receive(:get).with("current_account_number").and_return(nil)
    allow(config).to receive(:set)
  end

  describe "#select" do
    context "when not authenticated" do
      before do
        allow(cli).to receive(:authenticated?).and_return(false)
      end

      it "requires authentication" do
        expect(cli).to receive(:require_authentication!)
        allow(Tastytrade::Models::Account).to receive(:get_all).with(session).and_return([])
        cli.select
      end
    end

    context "with no accounts" do
      before do
        allow(Tastytrade::Models::Account).to receive(:get_all).with(session).and_return([])
      end

      it "returns early with warning" do
        expect { cli.select }.to output(/No accounts found/).to_stderr
      end

      it "doesn't prompt for selection" do
        expect(prompt).not_to receive(:select)
        cli.select
      end
    end

    context "with single account" do
      before do
        allow(Tastytrade::Models::Account).to receive(:get_all).with(session).and_return([account1])
      end

      it "auto-selects the account" do
        expect(config).to receive(:set).with("current_account_number", "5WX12345")
        cli.select
      end

      it "displays success message" do
        expect { cli.select }.to output(/Using account: 5WX12345/).to_stdout
      end

      it "doesn't prompt for selection" do
        expect(prompt).not_to receive(:select)
        cli.select
      end
    end

    context "with multiple accounts" do
      before do
        allow(Tastytrade::Models::Account).to receive(:get_all).with(session).and_return([account1, account2])
      end

      it "prompts for account selection" do
        expect(prompt).to receive(:select).with(
          "Choose an account:",
          [
            { name: "5WX12345 - Main Account (Margin)", value: "5WX12345" },
            { name: "5WX67890 (Cash)", value: "5WX67890" }
          ]
        ).and_return("5WX12345")

        cli.select
      end

      it "saves selected account" do
        allow(prompt).to receive(:select).and_return("5WX67890")

        expect(config).to receive(:set).with("current_account_number", "5WX67890")
        cli.select
      end

      it "displays success message" do
        allow(prompt).to receive(:select).and_return("5WX12345")

        expect { cli.select }.to output(/Selected account: 5WX12345/).to_stdout
      end

      context "with current account selected" do
        before do
          allow(config).to receive(:get).with("current_account_number").and_return("5WX12345")
        end

        it "marks current account in choices" do
          expect(prompt).to receive(:select).with(
            "Choose an account:",
            [
              { name: "5WX12345 - Main Account (Margin) [current]", value: "5WX12345" },
              { name: "5WX67890 (Cash)", value: "5WX67890" }
            ]
          ).and_return("5WX12345")

          cli.select
        end
      end

      context "with account without nickname" do
        it "handles nil nickname properly" do
          expect(prompt).to receive(:select).with(
            "Choose an account:",
            [
              { name: "5WX12345 - Main Account (Margin)", value: "5WX12345" },
              { name: "5WX67890 (Cash)", value: "5WX67890" }
            ]
          ).and_return("5WX67890")

          cli.select
        end
      end
    end

    context "on API error" do
      before do
        allow(Tastytrade::Models::Account).to receive(:get_all).with(session)
                                                               .and_raise(Tastytrade::Error, "Network error")
      end

      it "displays error message" do
        expect(cli).to receive(:exit).with(1)
        expect { cli.select }.to output(/Failed to fetch accounts: Network error/).to_stderr
      end

      it "exits with status 1" do
        expect(cli).to receive(:exit).with(1)
        cli.select
      end
    end

    context "on unexpected error" do
      before do
        allow(Tastytrade::Models::Account).to receive(:get_all).with(session)
                                                               .and_raise(StandardError, "Unexpected issue")
      end

      it "displays generic error message" do
        expect(cli).to receive(:exit).with(1)
        expect { cli.select }.to output(/Unexpected error: Unexpected issue/).to_stderr
      end
    end
  end
end
