# frozen_string_literal: true

require "spec_helper"

RSpec.describe Tastytrade::Session, :vcr do
  # Use sandbox credentials from environment
  let(:username) { ENV.fetch("TASTYTRADE_SANDBOX_USERNAME", "test_username") }
  let(:password) { ENV.fetch("TASTYTRADE_SANDBOX_PASSWORD", "test_password") }
  let(:account) { ENV.fetch("TASTYTRADE_SANDBOX_ACCOUNT", "test_account") }

  describe "#initialize" do
    it "creates session with default settings" do
      session = described_class.new(username: username, password: password)

      expect(session.is_test).to be false
      expect(session.user).to be_nil
      expect(session.session_token).to be_nil
    end

    it "creates session with test environment" do
      session = described_class.new(username: username, password: password, is_test: true)

      expect(session.is_test).to be true
    end

    it "creates session with remember_me" do
      session = described_class.new(username: username, password: password, remember_me: true)

      expect(session.remember_token).to be_nil # Not set until login
    end

    it "creates session with remember_token" do
      remember_token = "existing-remember-token"
      session = described_class.new(username: username, remember_token: remember_token)

      expect(session.remember_token).to eq(remember_token)
    end

    it "creates session with timeout" do
      session = described_class.new(username: username, password: password, timeout: 60)

      # Just verify it doesn't raise an error
      expect(session).to be_a(described_class)
    end
  end

  describe "#login" do
    let(:session) { described_class.new(username: username, password: password, is_test: true) }

    it "authenticates and sets user data", vcr: { cassette_name: "session/login_success" } do
      with_market_hours_check("session/login_success") do
        result = session.login

        expect(result).to eq(session) # Returns self for chaining
        expect(session.user).to be_a(Tastytrade::Models::User)
        expect(session.user.email).not_to be_nil
        expect(session.session_token).not_to be_nil
        expect(session.session_token).not_to include(password)
      end
    end

    context "with remember_me enabled" do
      let(:session) { described_class.new(username: username, password: password, is_test: true, remember_me: true) }

      it "stores remember token", vcr: { cassette_name: "session/login_remember" } do
        with_market_hours_check("session/login_remember") do
          session.login

          expect(session.remember_token).not_to be_nil
          expect(session.session_token).not_to be_nil
        end
      end
    end

    context "with remember_token authentication" do
      it "authenticates using remember token", vcr: { cassette_name: "session/login_with_remember_token" } do
        with_market_hours_check("session/login_with_remember_token") do
          # First get a remember token
          initial_session = described_class.new(username: username, password: password, is_test: true,
                                                remember_me: true)
          initial_session.login
          remember_token = initial_session.remember_token

          # Now use it to authenticate
          session = described_class.new(username: username, remember_token: remember_token, is_test: true)
          session.login

          expect(session.session_token).not_to be_nil
          expect(session.user).to be_a(Tastytrade::Models::User)
        end
      end
    end

    context "with session expiration" do
      it "parses and stores session expiration", vcr: { cassette_name: "session/login_with_expiration" } do
        with_market_hours_check("session/login_with_expiration") do
          session.login

          # API may or may not return expiration
          if session.session_expiration
            expect(session.session_expiration).to be_a(Time)
          end
        end
      end
    end
  end

  describe "#validate" do
    let(:session) { described_class.new(username: username, password: password, is_test: true) }

    it "returns true for valid session", vcr: { cassette_name: "session/validate_success" } do
      with_market_hours_check("session/validate_success") do
        session.login
        expect(session.validate).to be true
      end
    end

    it "returns false for invalid session", vcr: { cassette_name: "session/validate_invalid" } do
      with_market_hours_check("session/validate_invalid") do
        # Set an invalid token
        session.instance_variable_set(:@session_token, "invalid-token")
        session.instance_variable_set(:@user, Tastytrade::Models::User.new(email: "test@example.com"))

        expect(session.validate).to be false
      end
    end
  end

  describe "#destroy" do
    let(:session) { described_class.new(username: username, password: password, is_test: true) }

    it "sends DELETE request and clears session data", vcr: { cassette_name: "session/destroy" } do
      with_market_hours_check("session/destroy") do
        # First login
        session.login
        expect(session.session_token).not_to be_nil

        # Then destroy
        session.destroy

        expect(session.session_token).to be_nil
        expect(session.user).to be_nil
        expect(session.remember_token).to be_nil
      end
    end

    it "does nothing if not authenticated" do
      expect(session.session_token).to be_nil

      # Should not raise error
      expect { session.destroy }.not_to raise_error
    end
  end

  describe "HTTP methods" do
    let(:session) { described_class.new(username: username, password: password, is_test: true) }

    describe "#get" do
      it "makes authenticated GET request", vcr: { cassette_name: "session/http_get" } do
        with_market_hours_check("session/http_get") do
          session.login

          result = session.get("/customers/me")

          expect(result).to be_a(Hash)
          expect(result).to have_key("data")
        end
      end
    end

    describe "#post" do
      it "makes authenticated POST request", vcr: { cassette_name: "session/http_post" } do
        with_market_hours_check("session/http_post") do
          session.login

          # Use a safe endpoint that accepts POST (watchlists are safe to create)
          timestamp = Time.now.to_i
          body = {
            "name" => "Test Watchlist #{timestamp}",
            "watchlist-entries" => []
          }
          result = session.post("/watchlists", body)

          expect(result).to be_a(Hash)
        end
      end
    end

    # TODO: Fix in PR #2 - PUT endpoint needs proper setup
    xdescribe "#put" do
      it "makes authenticated PUT request", vcr: { cassette_name: "session/http_put" } do
        with_market_hours_check("session/http_put") do
          session.login

          # First create a watchlist to update
          create_result = session.post("/watchlists", {
                                         "name" => "Test Watchlist",
                                         "watchlist-entries" => []
                                       })
          watchlist_id = create_result.dig("data", "id")

          # Now update it
          body = {
            "name" => "Updated Watchlist",
            "watchlist-entries" => []
          }
          result = session.put("/watchlists/#{watchlist_id}", body)

          expect(result).to be_a(Hash)
        end
      end
    end

    # TODO: Fix in PR #2 - DELETE endpoint needs proper setup
    xdescribe "#delete" do
      it "makes authenticated DELETE request", vcr: { cassette_name: "session/http_delete" } do
        with_market_hours_check("session/http_delete") do
          session.login

          # First create a watchlist to delete
          create_result = session.post("/watchlists", {
                                         "name" => "Test Watchlist for Delete",
                                         "watchlist-entries" => []
                                       })
          watchlist_id = create_result.dig("data", "id")

          # Now delete it
          result = session.delete("/watchlists/#{watchlist_id}")

          expect(result).to be_a(Hash)
        end
      end
    end

    context "when not authenticated" do
      it "raises error on GET" do
        expect { session.get("/test") }.to raise_error(Tastytrade::Error, "Not authenticated")
      end

      it "raises error on POST" do
        expect { session.post("/test") }.to raise_error(Tastytrade::Error, "Not authenticated")
      end

      it "raises error on PUT" do
        expect { session.put("/test") }.to raise_error(Tastytrade::Error, "Not authenticated")
      end

      it "raises error on DELETE" do
        expect { session.delete("/test") }.to raise_error(Tastytrade::Error, "Not authenticated")
      end
    end
  end

  describe "#authenticated?" do
    let(:session) { described_class.new(username: username, password: password, is_test: true) }

    it "returns false when no session token" do
      expect(session.authenticated?).to be false
    end

    it "returns true when session token exists", vcr: { cassette_name: "session/authenticated_check" } do
      with_market_hours_check("session/authenticated_check") do
        session.login
        expect(session.authenticated?).to be true
      end
    end
  end

  describe "#expired?" do
    let(:session) { described_class.new(username: username, password: password, is_test: true) }

    it "returns false when no expiration is set" do
      expect(session.expired?).to be false
    end

    it "returns false when session is not expired", vcr: { cassette_name: "session/expiration_check" } do
      with_market_hours_check("session/expiration_check") do
        session.login

        # Should not be expired immediately after login
        expect(session.expired?).to be false
      end
    end

    it "returns true when session is expired" do
      past_time = Time.now - 3600 # 1 hour ago
      session.instance_variable_set(:@session_expiration, past_time)

      expect(session.expired?).to be true
    end
  end

  describe "#time_until_expiry" do
    let(:session) { described_class.new(username: username, password: password, is_test: true) }

    it "returns nil when no expiration is set" do
      expect(session.time_until_expiry).to be_nil
    end

    it "returns positive seconds when session is not expired" do
      future_time = Time.now + 3600 # 1 hour from now
      session.instance_variable_set(:@session_expiration, future_time)

      time_left = session.time_until_expiry
      expect(time_left).to be > 3590 # Allow for small time difference
      expect(time_left).to be <= 3600
    end

    it "returns negative seconds when session is expired" do
      past_time = Time.now - 3600 # 1 hour ago
      session.instance_variable_set(:@session_expiration, past_time)

      time_left = session.time_until_expiry
      expect(time_left).to be < -3590
      expect(time_left).to be >= -3610 # Allow for small timing differences
    end
  end

  describe "#refresh_session" do
    context "with remember token" do
      it "refreshes session using remember token", vcr: { cassette_name: "session/refresh" } do
        with_market_hours_check("session/refresh") do
          # First login with remember_me to get token
          session = described_class.new(username: username, password: password, is_test: true, remember_me: true)
          session.login
          remember_token = session.remember_token
          expect(remember_token).not_to be_nil

          # Now refresh using that token
          session.instance_variable_set(:@session_token, nil) # Clear session
          result = session.refresh_session

          expect(result).to eq(session)
          expect(session.session_token).not_to be_nil
        end
      end
    end

    context "without remember token" do
      let(:session) { described_class.new(username: username, password: password, is_test: true) }

      it "raises error when no remember token available" do
        expect { session.refresh_session }.to raise_error(Tastytrade::Error, "No remember token available")
      end
    end
  end

  describe "authentication errors" do
    it "raises error for invalid credentials", vcr: { cassette_name: "session/login_invalid" } do
      with_market_hours_check("session/login_invalid") do
        session = described_class.new(username: "invalid@example.com", password: "wrongpass", is_test: true)
        expect { session.login }.to raise_error(Tastytrade::Error)
      end
    end
  end
end
