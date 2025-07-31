# frozen_string_literal: true

require "spec_helper"

RSpec.describe Tastytrade::Session do
  let(:username) { "testuser" }
  let(:password) { "testpass" }
  let(:client) { instance_double(Tastytrade::Client) }

  before do
    allow(Tastytrade::Client).to receive(:new).and_return(client)
  end

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
      expect(Tastytrade::Client).to have_received(:new).with(base_url: Tastytrade::CERT_URL, timeout: 30)
    end

    it "creates session with remember_me" do
      session = described_class.new(username: username, password: password, remember_me: true)

      expect(session.remember_token).to be_nil # Not set until login
    end

    it "creates session with remember_token" do
      remember_token = "existing-remember-token"
      session = described_class.new(username: username, remember_token: remember_token)

      expect(session.remember_token).to eq(remember_token)
      expect(session.instance_variable_get(:@password)).to be_nil
    end

    it "creates session with timeout" do
      session = described_class.new(username: username, password: password, timeout: 60)

      expect(Tastytrade::Client).to have_received(:new).with(base_url: Tastytrade::API_URL, timeout: 60)
    end
  end

  describe "#login" do
    let(:session) { described_class.new(username: username, password: password) }
    let(:login_response) do
      {
        "data" => {
          "user" => {
            "email" => "test@example.com",
            "username" => "testuser",
            "external-id" => "ext-123"
          },
          "session-token" => "test-session-token"
        }
      }
    end

    it "authenticates and sets user data" do
      expect(client).to receive(:post).with("/sessions", {
                                              "login" => username,
                                              "password" => password,
                                              "remember-me" => false
                                            }).and_return(login_response)

      result = session.login

      expect(result).to eq(session) # Returns self for chaining
      expect(session.user).to be_a(Tastytrade::Models::User)
      expect(session.user.email).to eq("test@example.com")
      expect(session.session_token).to eq("test-session-token")
    end

    context "with remember_me enabled" do
      let(:session) { described_class.new(username: username, password: password, remember_me: true) }
      let(:login_response) do
        super().tap do |response|
          response["data"]["remember-token"] = "test-remember-token"
        end
      end

      it "stores remember token" do
        expect(client).to receive(:post).with("/sessions", {
                                                "login" => username,
                                                "password" => password,
                                                "remember-me" => true
                                              }).and_return(login_response)

        session.login

        expect(session.remember_token).to eq("test-remember-token")
      end
    end

    context "with remember_token authentication" do
      let(:remember_token) { "existing-remember-token" }
      let(:session) { described_class.new(username: username, remember_token: remember_token) }

      it "authenticates using remember token" do
        expect(client).to receive(:post).with("/sessions", {
                                                "login" => username,
                                                "remember-token" => remember_token,
                                                "remember-me" => false
                                              }).and_return(login_response)

        session.login

        expect(session.session_token).to eq("test-session-token")
      end

      it "does not send password when using remember token" do
        expect(client).to receive(:post) do |_path, body|
          expect(body).not_to have_key("password")
          login_response
        end

        session.login
      end
    end

    context "with session expiration" do
      let(:login_response_with_expiration) do
        login_response.tap do |response|
          response["data"]["session-expiration"] = "2024-01-01T12:00:00Z"
        end
      end

      it "parses and stores session expiration" do
        expect(client).to receive(:post).and_return(login_response_with_expiration)

        session.login

        expect(session.session_expiration).to be_a(Time)
        expect(session.session_expiration.iso8601).to eq("2024-01-01T12:00:00Z")
      end
    end
  end

  describe "#validate" do
    let(:session) { described_class.new(username: username, password: password) }
    let(:user) { instance_double(Tastytrade::Models::User, email: "test@example.com") }

    before do
      session.instance_variable_set(:@user, user)
      session.instance_variable_set(:@session_token, "token")
    end

    it "returns true for valid session" do
      expect(client).to receive(:get).with("/sessions/validate", {}, { "Authorization" => "token" })
                                     .and_return({ "data" => { "email" => "test@example.com" } })

      expect(session.validate).to be true
    end

    it "returns false for invalid session" do
      expect(client).to receive(:get).with("/sessions/validate", {}, { "Authorization" => "token" })
                                     .and_return({ "data" => { "email" => "different@example.com" } })

      expect(session.validate).to be false
    end

    it "returns false on error" do
      expect(client).to receive(:get).and_raise(Tastytrade::Error, "Unauthorized")

      expect(session.validate).to be false
    end
  end

  describe "#destroy" do
    let(:session) { described_class.new(username: username, password: password) }

    before do
      session.instance_variable_set(:@session_token, "token")
      session.instance_variable_set(:@user, "user")
      session.instance_variable_set(:@remember_token, "remember")
    end

    it "sends DELETE request and clears session data" do
      expect(client).to receive(:delete).with("/sessions", { "Authorization" => "token" })

      session.destroy

      expect(session.session_token).to be_nil
      expect(session.user).to be_nil
      expect(session.remember_token).to be_nil
    end

    it "does nothing if not authenticated" do
      session.instance_variable_set(:@session_token, nil)

      expect(client).not_to receive(:delete)

      session.destroy
    end
  end

  describe "HTTP methods" do
    let(:session) { described_class.new(username: username, password: password) }
    let(:auth_headers) { { "Authorization" => "token" } }

    before do
      session.instance_variable_set(:@session_token, "token")
    end

    describe "#get" do
      it "makes authenticated GET request" do
        expect(client).to receive(:get).with("/test", { foo: "bar" }, auth_headers)
                                       .and_return({ "data" => "result" })

        result = session.get("/test", { foo: "bar" })

        expect(result).to eq({ "data" => "result" })
      end
    end

    describe "#post" do
      it "makes authenticated POST request" do
        body = { key: "value" }
        expect(client).to receive(:post).with("/test", body, auth_headers)
                                        .and_return({ "data" => "result" })

        result = session.post("/test", body)

        expect(result).to eq({ "data" => "result" })
      end
    end

    describe "#put" do
      it "makes authenticated PUT request" do
        body = { key: "value" }
        expect(client).to receive(:put).with("/test", body, auth_headers)
                                       .and_return({ "data" => "result" })

        result = session.put("/test", body)

        expect(result).to eq({ "data" => "result" })
      end
    end

    describe "#delete" do
      it "makes authenticated DELETE request" do
        expect(client).to receive(:delete).with("/test", auth_headers)
                                          .and_return({ "data" => "result" })

        result = session.delete("/test")

        expect(result).to eq({ "data" => "result" })
      end
    end

    context "when not authenticated" do
      before do
        session.instance_variable_set(:@session_token, nil)
      end

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
    let(:session) { described_class.new(username: username, password: password) }

    it "returns false when no session token" do
      expect(session.authenticated?).to be false
    end

    it "returns true when session token exists" do
      session.instance_variable_set(:@session_token, "token")
      expect(session.authenticated?).to be true
    end
  end

  describe "#expired?" do
    let(:session) { described_class.new(username: username, password: password) }

    it "returns false when no expiration is set" do
      expect(session.expired?).to be false
    end

    it "returns false when session is not expired" do
      future_time = Time.now + 3600 # 1 hour from now
      session.instance_variable_set(:@session_expiration, future_time)

      expect(session.expired?).to be false
    end

    it "returns true when session is expired" do
      past_time = Time.now - 3600 # 1 hour ago
      session.instance_variable_set(:@session_expiration, past_time)

      expect(session.expired?).to be true
    end
  end

  describe "#time_until_expiry" do
    let(:session) { described_class.new(username: username, password: password) }

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
    let(:session) { described_class.new(username: username, password: password, remember_me: true) }
    let(:refresh_response) do
      {
        "data" => {
          "user" => {
            "email" => "test@example.com",
            "username" => "testuser"
          },
          "session-token" => "new-session-token",
          "session-expiration" => "2024-01-01T12:00:00Z"
        }
      }
    end

    context "with remember token" do
      before do
        session.instance_variable_set(:@remember_token, "valid-remember-token")
      end

      it "refreshes session using remember token" do
        expect(client).to receive(:post).with("/sessions", {
                                                "login" => username,
                                                "remember-token" => "valid-remember-token",
                                                "remember-me" => true
                                              }).and_return(refresh_response)

        result = session.refresh_session

        expect(result).to eq(session)
        expect(session.session_token).to eq("new-session-token")
        expect(session.instance_variable_get(:@password)).to be_nil
      end

      it "updates session expiration on refresh" do
        expect(client).to receive(:post).and_return(refresh_response)

        session.refresh_session

        expect(session.session_expiration).to be_a(Time)
        expect(session.session_expiration.iso8601).to eq("2024-01-01T12:00:00Z")
      end
    end

    context "without remember token" do
      it "raises error when no remember token available" do
        expect { session.refresh_session }.to raise_error(Tastytrade::Error, "No remember token available")
      end
    end
  end
end
