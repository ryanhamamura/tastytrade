# frozen_string_literal: true

require "spec_helper"
require "tastytrade/cli"

RSpec.describe "Tastytrade::CLI environment variable login" do
  let(:cli) { Tastytrade::CLI.new }
  let(:output) { StringIO.new }
  let(:error_output) { StringIO.new }

  let(:mock_session) do
    instance_double(
      Tastytrade::Session,
      login: nil,
      user: instance_double(Tastytrade::Models::User,
                           email: "env@example.com",
                           username: "env_user",
                           external_id: "test-external-id"),
      remember_token: "test_remember_token",
      session_token: "test_session_token",
      session_expiration: Time.now + 3600
    )
  end

  around do |example|
    # Save original environment
    original_env = ENV.to_hash

    # Clear relevant environment variables
    %w[TASTYTRADE_USERNAME TT_USERNAME TASTYTRADE_PASSWORD TT_PASSWORD
       TASTYTRADE_REMEMBER TT_REMEMBER TASTYTRADE_ENVIRONMENT TT_ENVIRONMENT].each do |key|
      ENV.delete(key)
    end

    example.run

    # Restore original environment
    ENV.clear
    ENV.update(original_env)
  end

  before do
    allow($stdout).to receive(:puts) { |msg| output.puts(msg) }
    allow($stderr).to receive(:puts) { |msg| error_output.puts(msg) }
    allow($stderr).to receive(:write) { |msg| error_output.write(msg) }
    allow(Kernel).to receive(:warn) { |msg| error_output.puts(msg) }
    allow(cli).to receive(:exit)
    allow(cli).to receive(:interactive_mode)
  end

  describe "#login with environment variables" do
    context "with TASTYTRADE_ prefixed variables" do
      before do
        ENV["TASTYTRADE_USERNAME"] = "env@example.com"
        ENV["TASTYTRADE_PASSWORD"] = "env_password"

        allow(Tastytrade::Session).to receive(:from_environment).and_return(mock_session)
        allow(mock_session).to receive(:login).and_return(mock_session)
      end

      it "uses environment variables for authentication" do
        expect(Tastytrade::Session).to receive(:from_environment).and_return(mock_session)
        expect(mock_session).to receive(:login)

        cli.login

        expect(output.string).to include("Using credentials from environment variables")
        expect(output.string).to include("Successfully logged in as env@example.com")
      end

      it "saves the session" do
        expect(cli).to receive(:save_user_session).with(
          mock_session,
          hash_including(username: "env@example.com", remember: true),
          "production"
        )

        cli.login
      end

      it "enters interactive mode after login" do
        expect(cli).to receive(:interactive_mode)
        cli.login
      end

      context "when environment login fails" do
        before do
          allow(mock_session).to receive(:login).and_raise(Tastytrade::Error, "Invalid credentials")
          allow(cli).to receive(:prompt).and_return(
            instance_double(TTY::Prompt, ask: "manual@example.com", mask: "manual_password")
          )
          allow(cli).to receive(:save_user_session)
        end

        it "falls back to interactive login" do
          manual_session = instance_double(
            Tastytrade::Session,
            login: nil,
            user: instance_double(Tastytrade::Models::User, email: "manual@example.com"),
            session_token: "manual_session_token",
            session_expiration: nil
          )

          allow(Tastytrade::Session).to receive(:new).and_return(manual_session)

          # Expect the fallback to interactive login
          expect(cli).to receive(:login_credentials).and_call_original

          cli.login

          # Just verify fallback message, error message might be printed before our capture
          expect(output.string).to include("Falling back to interactive login")
        end
      end
    end

    context "with TT_ prefixed variables" do
      before do
        ENV["TT_USERNAME"] = "tt@example.com"
        ENV["TT_PASSWORD"] = "tt_password"

        tt_session = instance_double(
          Tastytrade::Session,
          login: nil,
          user: instance_double(Tastytrade::Models::User,
                               email: "tt@example.com",
                               username: "tt_user",
                               external_id: "tt-external-id"),
          remember_token: nil,
          session_token: "tt_session_token",
          session_expiration: nil
        )

        allow(Tastytrade::Session).to receive(:from_environment).and_return(tt_session)
        allow(tt_session).to receive(:login).and_return(tt_session)
      end

      it "uses TT_ prefixed environment variables" do
        expect(Tastytrade::Session).to receive(:from_environment)
        cli.login
        expect(output.string).to include("Using credentials from environment variables")
      end
    end

    context "with sandbox environment" do
      before do
        ENV["TASTYTRADE_USERNAME"] = "test@example.com"
        ENV["TASTYTRADE_PASSWORD"] = "test_password"
        ENV["TASTYTRADE_ENVIRONMENT"] = "sandbox"

        allow(cli).to receive(:options).and_return({ test: true })
        # Mock the session to report it's a test session
        allow(mock_session).to receive(:instance_variable_get).with(:@is_test).and_return(true)
        allow(Tastytrade::Session).to receive(:from_environment).and_return(mock_session)
      end

      it "logs into sandbox environment" do
        cli.login
        expect(output.string).to include("Logging in to sandbox environment")
      end
    end

    context "without environment variables" do
      before do
        allow(Tastytrade::Session).to receive(:from_environment).and_return(nil)
        allow(cli).to receive(:prompt).and_return(
          instance_double(TTY::Prompt, ask: "manual@example.com", mask: "manual_password")
        )
        allow(cli).to receive(:save_user_session)
      end

      it "prompts for credentials interactively" do
        manual_session = instance_double(
          Tastytrade::Session,
          login: nil,
          user: instance_double(Tastytrade::Models::User, email: "manual@example.com")
        )

        allow(Tastytrade::Session).to receive(:new).and_return(manual_session)

        expect(cli).to receive(:login_credentials).and_call_original
        cli.login
      end

      it "does not mention environment variables" do
        manual_session = instance_double(
          Tastytrade::Session,
          login: nil,
          user: instance_double(Tastytrade::Models::User, email: "manual@example.com")
        )

        allow(Tastytrade::Session).to receive(:new).and_return(manual_session)

        cli.login
        expect(output.string).not_to include("Using credentials from environment variables")
      end
    end
  end
end
