# frozen_string_literal: true

require "spec_helper"
require "tastytrade/session_manager"
require "tastytrade/keyring_store"
require "tastytrade/cli_config"

RSpec.describe Tastytrade::SessionManager do
  let(:username) { "test@example.com" }
  let(:environment) { "production" }
  let(:manager) { described_class.new(username: username, environment: environment) }
  let(:session) { instance_double(Tastytrade::Session) }
  let(:config) { instance_double(Tastytrade::CLIConfig) }

  before do
    allow(Tastytrade::CLIConfig).to receive(:new).and_return(config)
    allow(config).to receive(:set)
    allow(config).to receive(:delete)
    allow(Tastytrade::KeyringStore).to receive(:available?).and_return(true)
  end

  describe "#initialize" do
    it "sets username and environment" do
      expect(manager.username).to eq(username)
      expect(manager.environment).to eq(environment)
    end

    it "defaults to production environment" do
      manager = described_class.new(username: username)
      expect(manager.environment).to eq("production")
    end
  end

  describe "#save_session" do
    let(:session_token) { "session_token_123" }
    let(:remember_token) { "remember_token_456" }

    before do
      allow(session).to receive(:session_token).and_return(session_token)
      allow(session).to receive(:remember_token).and_return(remember_token)
      allow(Tastytrade::KeyringStore).to receive(:set).and_return(true)
    end

    it "saves session token" do
      expect(Tastytrade::KeyringStore).to receive(:set)
        .with("token_test@example.com_production", session_token)

      manager.save_session(session)
    end

    it "saves config data" do
      expect(config).to receive(:set).with("current_username", username)
      expect(config).to receive(:set).with("environment", environment)
      expect(config).to receive(:set).with("last_login", anything)

      manager.save_session(session)
    end

    context "with remember option" do
      it "saves remember token and password" do
        expect(Tastytrade::KeyringStore).to receive(:set)
          .with("remember_test@example.com_production", remember_token)
        expect(Tastytrade::KeyringStore).to receive(:set)
          .with("password_test@example.com_production", "secret123")

        manager.save_session(session, password: "secret123", remember: true)
      end

      it "doesn't save password if keyring unavailable" do
        allow(Tastytrade::KeyringStore).to receive(:available?).and_return(false)

        expect(Tastytrade::KeyringStore).not_to receive(:set)
          .with("password_test@example.com_production", anything)

        manager.save_session(session, password: "secret123", remember: true)
      end
    end

    context "without remember option" do
      it "doesn't save remember token or password" do
        expect(Tastytrade::KeyringStore).not_to receive(:set)
          .with("remember_test@example.com_production", anything)
        expect(Tastytrade::KeyringStore).not_to receive(:set)
          .with("password_test@example.com_production", anything)

        manager.save_session(session, password: "secret123", remember: false)
      end
    end

    it "handles errors gracefully" do
      allow(Tastytrade::KeyringStore).to receive(:set).and_raise(StandardError, "Save error")

      expect { manager.save_session(session) }.to output(/Failed to save session/).to_stderr
      expect(manager.save_session(session)).to be false
    end
  end

  describe "#load_session" do
    context "with saved token" do
      before do
        allow(Tastytrade::KeyringStore).to receive(:get)
          .with("token_test@example.com_production").and_return("saved_token")
        allow(Tastytrade::KeyringStore).to receive(:get)
          .with("remember_test@example.com_production").and_return("saved_remember")
      end

      it "returns session data hash" do
        result = manager.load_session

        expect(result).to eq({
                               session_token: "saved_token",
                               remember_token: "saved_remember",
                               username: username,
                               environment: environment
                             })
      end
    end

    context "without saved token" do
      before do
        allow(Tastytrade::KeyringStore).to receive(:get)
          .with("token_test@example.com_production").and_return(nil)
      end

      it "returns nil" do
        expect(manager.load_session).to be_nil
      end
    end
  end

  describe "#restore_session" do
    let(:new_session) { instance_double(Tastytrade::Session) }

    before do
      allow(Tastytrade::Session).to receive(:new).and_return(new_session)
      allow(new_session).to receive(:login).and_return(new_session)
    end

    context "with saved remember token" do
      before do
        allow(Tastytrade::KeyringStore).to receive(:get)
          .with("password_test@example.com_production").and_return(nil)
        allow(Tastytrade::KeyringStore).to receive(:get)
          .with("remember_test@example.com_production").and_return("saved_remember")
      end

      it "creates session with remember token" do
        expect(Tastytrade::Session).to receive(:new).with(
          username: username,
          password: nil,
          remember_token: "saved_remember",
          is_test: false
        )

        manager.restore_session
      end
    end

    context "with saved password" do
      before do
        allow(Tastytrade::KeyringStore).to receive(:get)
          .with("remember_test@example.com_production").and_return(nil)
        allow(Tastytrade::KeyringStore).to receive(:get)
          .with("password_test@example.com_production").and_return("saved_password")
      end

      it "creates session with password" do
        expect(Tastytrade::Session).to receive(:new).with(
          username: username,
          password: "saved_password",
          remember_token: nil,
          is_test: false
        )

        manager.restore_session
      end
    end

    context "with sandbox environment" do
      let(:environment) { "sandbox" }

      before do
        allow(Tastytrade::KeyringStore).to receive(:get)
          .with("password_test@example.com_sandbox").and_return("saved_password")
        allow(Tastytrade::KeyringStore).to receive(:get)
          .with("remember_test@example.com_sandbox").and_return(nil)
      end

      it "sets is_test flag" do
        expect(Tastytrade::Session).to receive(:new).with(
          hash_including(is_test: true)
        )

        manager.restore_session
      end
    end

    context "without saved credentials" do
      before do
        allow(Tastytrade::KeyringStore).to receive(:get).and_return(nil)
      end

      it "returns nil" do
        expect(manager.restore_session).to be_nil
      end
    end

    it "handles errors gracefully" do
      allow(Tastytrade::KeyringStore).to receive(:get)
        .with("password_test@example.com_production").and_return("password")
      allow(Tastytrade::KeyringStore).to receive(:get)
        .with("remember_test@example.com_production").and_return(nil)
      allow(new_session).to receive(:login).and_raise(StandardError, "Login error")

      expect { manager.restore_session }.to output(/Failed to restore session/).to_stderr
      expect(manager.restore_session).to be_nil
    end
  end

  describe "#clear_session!" do
    it "deletes all stored credentials" do
      expect(Tastytrade::KeyringStore).to receive(:delete)
        .with("token_test@example.com_production")
      expect(Tastytrade::KeyringStore).to receive(:delete)
        .with("remember_test@example.com_production")
      expect(Tastytrade::KeyringStore).to receive(:delete)
        .with("password_test@example.com_production")

      manager.clear_session!
    end

    it "clears config data" do
      expect(config).to receive(:delete).with("current_username")
      expect(config).to receive(:delete).with("last_login")

      manager.clear_session!
    end
  end

  describe "#saved_credentials?" do
    context "with saved password" do
      before do
        allow(Tastytrade::KeyringStore).to receive(:get)
          .with("password_test@example.com_production").and_return("password")
      end

      it "returns true" do
        expect(manager.saved_credentials?).to be true
      end
    end

    context "with saved remember token" do
      before do
        allow(Tastytrade::KeyringStore).to receive(:get)
          .with("password_test@example.com_production").and_return(nil)
        allow(Tastytrade::KeyringStore).to receive(:get)
          .with("remember_test@example.com_production").and_return("token")
      end

      it "returns true" do
        expect(manager.saved_credentials?).to be true
      end
    end

    context "without saved credentials" do
      before do
        allow(Tastytrade::KeyringStore).to receive(:get).and_return(nil)
      end

      it "returns false" do
        expect(manager.saved_credentials?).to be false
      end
    end
  end
end
