# frozen_string_literal: true

require "spec_helper"
require "tastytrade/cli"

RSpec.describe "Tastytrade::CLI logout command" do
  let(:cli) { Tastytrade::CLI.new }
  let(:config) { instance_double(Tastytrade::CLIConfig) }
  let(:session_manager) { instance_double(Tastytrade::SessionManager) }

  before do
    allow(cli).to receive(:config).and_return(config)
    allow(cli).to receive(:exit) # Prevent actual exit during tests
  end

  describe "#logout" do
    context "with active session" do
      before do
        allow(config).to receive(:get).with("current_username").and_return("test@example.com")
        allow(config).to receive(:get).with("environment").and_return("production")
        allow(Tastytrade::SessionManager).to receive(:new).with(
          username: "test@example.com",
          environment: "production"
        ).and_return(session_manager)
      end

      context "when logout succeeds" do
        before do
          allow(session_manager).to receive(:clear_session!).and_return(true)
          allow(config).to receive(:delete)
        end

        it "clears session credentials" do
          expect(session_manager).to receive(:clear_session!)
          cli.logout
        end

        it "removes config entries" do
          expect(config).to receive(:delete).with("current_username")
          expect(config).to receive(:delete).with("environment")
          expect(config).to receive(:delete).with("last_login")
          cli.logout
        end

        it "displays success message" do
          expect { cli.logout }.to output(/Successfully logged out/).to_stdout
        end
      end

      context "when logout fails" do
        before do
          allow(session_manager).to receive(:clear_session!).and_return(false)
        end

        it "displays error message" do
          expect(cli).to receive(:exit).with(1)
          expect { cli.logout }.to output(/Failed to logout completely/).to_stderr
        end

        it "exits with status 1" do
          expect(cli).to receive(:exit).with(1)
          cli.logout
        end
      end
    end

    context "with sandbox environment" do
      before do
        allow(config).to receive(:get).with("current_username").and_return("test@example.com")
        allow(config).to receive(:get).with("environment").and_return("sandbox")
        allow(session_manager).to receive(:clear_session!).and_return(true)
        allow(config).to receive(:delete)
      end

      it "creates session manager with sandbox environment" do
        expect(Tastytrade::SessionManager).to receive(:new).with(
          username: "test@example.com",
          environment: "sandbox"
        ).and_return(session_manager)
        cli.logout
      end
    end

    context "without active session" do
      before do
        allow(config).to receive(:get).with("current_username").and_return(nil)
      end

      it "displays warning message" do
        expect { cli.logout }.to output(/No active session found/).to_stderr
      end

      it "doesn't attempt to clear session" do
        expect(Tastytrade::SessionManager).not_to receive(:new)
        cli.logout
      end

      it "doesn't exit with error" do
        expect(cli).not_to receive(:exit)
        cli.logout
      end
    end

    context "with missing environment" do
      before do
        allow(config).to receive(:get).with("current_username").and_return("test@example.com")
        allow(config).to receive(:get).with("environment").and_return(nil)
        allow(session_manager).to receive(:clear_session!).and_return(true)
        allow(config).to receive(:delete)
      end

      it "defaults to production environment" do
        expect(Tastytrade::SessionManager).to receive(:new).with(
          username: "test@example.com",
          environment: "production"
        ).and_return(session_manager)
        cli.logout
      end
    end
  end
end
