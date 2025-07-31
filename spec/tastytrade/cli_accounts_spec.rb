# frozen_string_literal: true

require "spec_helper"
require "tastytrade/cli"
require "tty-table"

RSpec.describe "Tastytrade::CLI accounts command" do
  let(:cli) { Tastytrade::CLI.new }
  let(:config) { instance_double(Tastytrade::CLIConfig) }
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
    allow(cli).to receive(:exit) # Prevent actual exit during tests
    allow(cli).to receive(:current_session).and_return(session)
    allow(cli).to receive(:authenticated?).and_return(true)
    allow(config).to receive(:get).with("current_account_number").and_return(nil)
    allow(config).to receive(:set)
  end

  describe "#accounts" do
    context "when not authenticated" do
      before do
        allow(cli).to receive(:authenticated?).and_return(false)
      end

      it "requires authentication" do
        expect(cli).to receive(:require_authentication!)
        # Mock the session.get call that happens after authentication check
        allow(session).to receive(:get).with("/customers/me/accounts/", {}).and_return(
          { "data" => { "items" => [] } }
        )
        cli.accounts
      end
    end

    context "with no accounts" do
      before do
        allow(Tastytrade::Models::Account).to receive(:get_all).with(session).and_return([])
      end

      it "displays warning message" do
        expect { cli.accounts }.to output(/No accounts found/).to_stderr
      end

      it "displays fetching message" do
        expect { cli.accounts }.to output(/Fetching accounts/).to_stdout
      end
    end

    context "with single account" do
      before do
        allow(Tastytrade::Models::Account).to receive(:get_all).with(session).and_return([account1])
      end

      it "displays account in table format" do
        expect { cli.accounts }.to output(/5WX12345/).to_stdout
        expect { cli.accounts }.to output(/Main Account/).to_stdout
        expect { cli.accounts }.to output(/Margin/).to_stdout
      end

      it "auto-selects the account" do
        expect(config).to receive(:set).with("current_account_number", "5WX12345")
        cli.accounts
      end

      it "shows using account message" do
        expect { cli.accounts }.to output(/Using account: 5WX12345/).to_stdout
      end

      it "shows total accounts" do
        expect { cli.accounts }.to output(/Total accounts: 1/).to_stdout
      end
    end

    context "with multiple accounts" do
      before do
        allow(Tastytrade::Models::Account).to receive(:get_all).with(session).and_return([account1, account2])
      end

      it "displays all accounts in table format" do
        expect { cli.accounts }.to output(/5WX12345.*Main Account.*Margin/).to_stdout
        expect { cli.accounts }.to output(/5WX67890.*Cash/).to_stdout
      end

      it "handles nil nickname" do
        expect { cli.accounts }.to output(/5WX67890.*-.*Cash/).to_stdout
      end

      it "prompts to select account" do
        expect { cli.accounts }.to output(/Use 'tastytrade select' to choose an account/).to_stdout
      end

      it "shows total accounts" do
        expect { cli.accounts }.to output(/Total accounts: 2/).to_stdout
      end
    end

    context "with current account selected" do
      before do
        allow(config).to receive(:get).with("current_account_number").and_return("5WX12345")
        allow(Tastytrade::Models::Account).to receive(:get_all).with(session).and_return([account1, account2])
      end

      it "shows indicator for current account" do
        expect { cli.accounts }.to output(/→.*5WX12345/).to_stdout
      end

      it "doesn't prompt to select account" do
        expect { cli.accounts }.not_to output(/Use 'tastytrade select'/).to_stdout
      end
    end

    context "with invalid current account" do
      before do
        allow(config).to receive(:get).with("current_account_number").and_return("INVALID")
        allow(Tastytrade::Models::Account).to receive(:get_all).with(session).and_return([account1, account2])
      end

      it "prompts to select account" do
        expect { cli.accounts }.to output(/Use 'tastytrade select' to choose an account/).to_stdout
      end
    end

    context "on API error" do
      before do
        allow(Tastytrade::Models::Account).to receive(:get_all).with(session).and_raise(Tastytrade::Error,
                                                                                        "Network error")
      end

      it "displays error message" do
        expect(cli).to receive(:exit).with(1)
        expect { cli.accounts }.to output(/Failed to fetch accounts: Network error/).to_stderr
      end

      it "exits with status 1" do
        expect(cli).to receive(:exit).with(1)
        cli.accounts
      end
    end

    context "on unexpected error" do
      before do
        allow(Tastytrade::Models::Account).to receive(:get_all).with(session).and_raise(StandardError,
                                                                                        "Unexpected issue")
      end

      it "displays generic error message" do
        expect(cli).to receive(:exit).with(1)
        expect { cli.accounts }.to output(/Unexpected error: Unexpected issue/).to_stderr
      end
    end
  end
end
