# frozen_string_literal: true

require "spec_helper"
require "tastytrade/cli"

RSpec.describe "Tastytrade::CLI authentication commands" do
  let(:cli) { Tastytrade::CLI.new }
  let(:session) { instance_double(Tastytrade::Session) }
  let(:user) { instance_double(Tastytrade::Models::User, email: "test@example.com") }
  let(:prompt) { instance_double(TTY::Prompt) }
  let(:config) { instance_double(Tastytrade::CLIConfig) }
  let(:session_manager) { instance_double(Tastytrade::SessionManager) }

  before do
    allow(cli).to receive(:prompt).and_return(prompt)
    allow(cli).to receive(:config).and_return(config)
    allow(cli).to receive(:exit) # Prevent actual exit during tests
    allow(Tastytrade::SessionManager).to receive(:new).and_return(session_manager)
    allow(session_manager).to receive(:save_session).and_return(true)
  end

  describe "#login" do
    context "with username provided via option" do
      before do
        allow(prompt).to receive(:mask).with("Password:").and_return("secret123")
        allow(Tastytrade::Session).to receive(:new).and_return(session)
        allow(session).to receive(:login).and_return(session)
        allow(session).to receive(:user).and_return(user)
        allow(session).to receive(:session_token).and_return("test_session_token")
        allow(session).to receive(:remember_token).and_return("test_remember_token")
        allow(config).to receive(:set)
      end

      it "uses provided username and prompts for password" do
        expect(prompt).not_to receive(:ask)
        expect(prompt).to receive(:mask).with("Password:")

        cli.options = { username: "test@example.com", test: false, remember: false }
        expect { cli.login }.to output(/Successfully logged in/).to_stdout
      end

      it "creates session with correct parameters" do
        expect(Tastytrade::Session).to receive(:new).with(
          username: "test@example.com",
          password: "secret123",
          remember_me: false,
          is_test: false
        ).and_return(session)

        cli.options = { username: "test@example.com", test: false, remember: false }
        cli.login
      end
    end

    context "with interactive username prompt" do
      before do
        allow(prompt).to receive(:ask).with("Username:").and_return("test@example.com")
        allow(prompt).to receive(:mask).with("Password:").and_return("secret123")
        allow(Tastytrade::Session).to receive(:new).and_return(session)
        allow(session).to receive(:login).and_return(session)
        allow(session).to receive(:user).and_return(user)
        allow(session).to receive(:session_token).and_return("test_session_token")
        allow(session).to receive(:remember_token).and_return("test_remember_token")
        allow(config).to receive(:set)
      end

      it "prompts for both username and password" do
        expect(prompt).to receive(:ask).with("Username:")
        expect(prompt).to receive(:mask).with("Password:")

        cli.options = { test: false, remember: false }
        cli.login
      end
    end

    context "with test environment" do
      before do
        allow(prompt).to receive(:ask).with("Username:").and_return("test@example.com")
        allow(prompt).to receive(:mask).with("Password:").and_return("secret123")
        allow(Tastytrade::Session).to receive(:new).and_return(session)
        allow(session).to receive(:login).and_return(session)
        allow(session).to receive(:user).and_return(user)
        allow(session).to receive(:session_token).and_return("test_session_token")
        allow(session).to receive(:remember_token).and_return("test_remember_token")
        allow(config).to receive(:set)
      end

      it "creates session with test flag" do
        expect(Tastytrade::Session).to receive(:new).with(
          username: "test@example.com",
          password: "secret123",
          remember_me: false,
          is_test: true
        ).and_return(session)

        cli.options = { test: true, remember: false }
        expect { cli.login }.to output(/sandbox environment/).to_stdout
      end

      it "saves sandbox environment to config" do
        # The config is set inside SessionManager#save_session
        expect(Tastytrade::SessionManager).to receive(:new).with(
          username: "test@example.com",
          environment: "sandbox"
        ).and_return(session_manager)

        cli.options = { test: true, remember: false }
        cli.login
      end
    end

    context "with remember option" do
      before do
        allow(prompt).to receive(:ask).with("Username:").and_return("test@example.com")
        allow(prompt).to receive(:mask).with("Password:").and_return("secret123")
        allow(Tastytrade::Session).to receive(:new).and_return(session)
        allow(session).to receive(:login).and_return(session)
        allow(session).to receive(:user).and_return(user)
        allow(session).to receive(:session_token).and_return("test_session_token")
        allow(session).to receive(:remember_token).and_return("test_remember_token")
        allow(config).to receive(:set)
      end

      it "creates session with remember flag" do
        expect(Tastytrade::Session).to receive(:new).with(
          username: "test@example.com",
          password: "secret123",
          remember_me: true,
          is_test: false
        ).and_return(session)

        cli.options = { test: false, remember: true }
        cli.login
      end
    end

    context "on successful login" do
      before do
        allow(prompt).to receive(:ask).with("Username:").and_return("test@example.com")
        allow(prompt).to receive(:mask).with("Password:").and_return("secret123")
        allow(Tastytrade::Session).to receive(:new).and_return(session)
        allow(session).to receive(:login).and_return(session)
        allow(session).to receive(:user).and_return(user)
        allow(session).to receive(:session_token).and_return("test_session_token")
        allow(session).to receive(:remember_token).and_return("test_remember_token")
      end

      it "saves username to config" do
        # The config is set inside SessionManager#save_session
        expect(Tastytrade::SessionManager).to receive(:new).with(
          username: "test@example.com",
          environment: "production"
        ).and_return(session_manager)
        expect(session_manager).to receive(:save_session).with(
          session,
          password: "secret123",
          remember: false
        ).and_return(true)

        cli.options = { test: false, remember: false }
        cli.login
      end

      it "displays success message with user email" do
        allow(config).to receive(:set)

        cli.options = { test: false, remember: false }
        expect { cli.login }.to output(/Successfully logged in as test@example.com/).to_stdout
      end
    end

    context "on authentication error" do
      before do
        allow(prompt).to receive(:ask).with("Username:").and_return("test@example.com")
        allow(prompt).to receive(:mask).with("Password:").and_return("wrong")
        allow(Tastytrade::Session).to receive(:new).and_return(session)
        allow(session).to receive(:login).and_raise(Tastytrade::Error, "Invalid credentials")
      end

      it "displays error message" do
        cli.options = { test: false, remember: false }
        expect(cli).to receive(:exit).with(1)
        expect { cli.login }.to output(/Error: Invalid credentials/).to_stderr
      end

      it "exits with status 1" do
        cli.options = { test: false, remember: false }
        expect(cli).to receive(:exit).with(1)
        cli.login
      end
    end

    context "on unexpected error" do
      before do
        allow(prompt).to receive(:ask).with("Username:").and_return("test@example.com")
        allow(prompt).to receive(:mask).with("Password:").and_return("secret123")
        allow(Tastytrade::Session).to receive(:new).and_raise(StandardError, "Connection timeout")
      end

      it "displays generic error message" do
        cli.options = { test: false, remember: false }
        expect(cli).to receive(:exit).with(1)
        expect { cli.login }.to output(/Error: Login failed: Connection timeout/).to_stderr
      end
    end
  end
end
