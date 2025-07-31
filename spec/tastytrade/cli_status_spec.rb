# frozen_string_literal: true

require "spec_helper"
require "tastytrade/cli"

RSpec.describe "Tastytrade::CLI status command" do
  def capture_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end
  let(:cli) { Tastytrade::CLI.new }
  let(:config) { instance_double(Tastytrade::CLIConfig) }
  let(:session) { instance_double(Tastytrade::Session) }
  let(:user) { instance_double(Tastytrade::Models::User, email: "test@example.com") }

  before do
    allow(cli).to receive(:config).and_return(config)
    allow(config).to receive(:get).with("current_username").and_return("testuser")
    allow(config).to receive(:get).with("environment").and_return("production")
  end

  describe "#status" do
    context "when not authenticated" do
      before do
        allow(cli).to receive(:current_session).and_return(nil)
      end

      it "displays warning about no active session" do
        expect { cli.status }.to output(/No active session/).to_stderr
      end

      it "suggests login command" do
        expect { cli.status }.to output(/Run 'tastytrade login' to authenticate/).to_stdout
      end
    end

    context "when authenticated" do
      before do
        allow(cli).to receive(:current_session).and_return(session)
        allow(session).to receive(:user).and_return(user)
      end

      context "without session expiration" do
        before do
          allow(session).to receive(:session_expiration).and_return(nil)
          allow(session).to receive(:remember_token).and_return(nil)
        end

        it "displays session status" do
          output = capture_stdout { cli.status }
          expect(output).to include("Session Status:")
          expect(output).to include("User: test@example.com")
          expect(output).to include("Environment: production")
          expect(output).to include("Status: Active")
          expect(output).to include("Expires in: Unknown")
          expect(output).to include("Remember token: Not available")
          expect(output).to include("Auto-refresh: Disabled")
        end
      end

      context "with non-expired session" do
        let(:future_time) { Time.now + 3600 }

        before do
          allow(session).to receive(:session_expiration).and_return(future_time)
          allow(session).to receive(:expired?).and_return(false)
          allow(session).to receive(:time_until_expiry).and_return(3600)
          allow(session).to receive(:remember_token).and_return("token123")
        end

        it "displays active status with time remaining" do
          output = capture_stdout { cli.status }
          expect(output).to include("Status: Active")
          expect(output).to include("Expires in: 1h 0m")
          expect(output).to include("Remember token: Available")
          expect(output).to include("Auto-refresh: Enabled")
        end
      end

      context "with expired session" do
        let(:past_time) { Time.now - 3600 }

        before do
          allow(session).to receive(:session_expiration).and_return(past_time)
          allow(session).to receive(:expired?).and_return(true)
          allow(session).to receive(:remember_token).and_return(nil)
        end

        it "displays expired status" do
          output = capture_stdout { cli.status }
          expect(output).to include("Status: Expired")
          expect(output).to include("Remember token: Not available")
          expect(output).to include("Auto-refresh: Disabled")
        end
      end
    end
  end

  describe "#refresh" do
    context "when not authenticated" do
      before do
        allow(cli).to receive(:current_session).and_return(nil)
      end

      it "displays error and exits" do
        expect { cli.refresh }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
        expect {
          begin
            cli.refresh
          rescue SystemExit
          end
        }.to output(/No active session to refresh/).to_stderr
      end
    end

    context "when authenticated without remember token" do
      before do
        allow(cli).to receive(:current_session).and_return(session)
        allow(session).to receive(:remember_token).and_return(nil)
      end

      it "displays error about missing remember token" do
        expect { cli.refresh }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
        expect {
          begin
            cli.refresh
          rescue SystemExit
          end
        }.to output(/No remember token available/).to_stderr
      end

      it "suggests using --remember flag" do
        expect {
          begin
            cli.refresh
          rescue SystemExit
          end
        }.to output(/Login with --remember flag/).to_stdout
      end
    end

    context "when authenticated with remember token" do
      let(:manager) { instance_double(Tastytrade::SessionManager) }

      before do
        allow(cli).to receive(:current_session).and_return(session)
        allow(session).to receive(:remember_token).and_return("token123")
        allow(session).to receive(:user).and_return(user)
        allow(Tastytrade::SessionManager).to receive(:new).and_return(manager)
      end

      context "on successful refresh" do
        before do
          allow(session).to receive(:refresh_session).and_return(session)
          allow(session).to receive(:time_until_expiry).and_return(3600)
          allow(manager).to receive(:save_session).and_return(true)
        end

        it "refreshes the session" do
          expect(session).to receive(:refresh_session)
          cli.refresh
        end

        it "saves the refreshed session" do
          expect(manager).to receive(:save_session).with(session)
          cli.refresh
        end

        it "displays success message" do
          expect { cli.refresh }.to output(/Session refreshed successfully/).to_stdout
        end

        it "displays new expiration time" do
          expect { cli.refresh }.to output(/Session expires in 1h 0m/).to_stdout
        end
      end

      context "on refresh failure" do
        before do
          allow(session).to receive(:refresh_session)
            .and_raise(Tastytrade::TokenRefreshError, "Invalid token")
        end

        it "displays error and exits" do
          expect { cli.refresh }.to raise_error(SystemExit) do |error|
            expect(error.status).to eq(1)
          end
          expect {
            begin
              cli.refresh
            rescue SystemExit
            end
          }.to output(/Failed to refresh session: Invalid token/).to_stderr
        end
      end
    end
  end
end
