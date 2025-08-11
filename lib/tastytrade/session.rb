# frozen_string_literal: true

require_relative "models"

module Tastytrade
  # Manages authentication and session state for Tastytrade API
  class Session
    attr_reader :user, :session_token, :remember_token, :is_test, :session_expiration

    # Create a session from environment variables
    #
    # @return [Session, nil] Session instance or nil if environment variables not set
    def self.from_environment(is_test: nil)
      username = ENV["TASTYTRADE_USERNAME"] || ENV["TT_USERNAME"]
      password = ENV["TASTYTRADE_PASSWORD"] || ENV["TT_PASSWORD"]

      return nil unless username && password

      remember = ENV["TASTYTRADE_REMEMBER"]&.downcase == "true" || ENV["TT_REMEMBER"]&.downcase == "true"

      # Use passed is_test value, or check environment variable as fallback
      if is_test.nil?
        is_test = ENV["TASTYTRADE_ENVIRONMENT"]&.downcase == "sandbox" ||
                  ENV["TT_ENVIRONMENT"]&.downcase == "sandbox"
      end

      new(
        username: username,
        password: password,
        remember_me: remember,
        is_test: is_test
      )
    end

    # Initialize a new session
    #
    # @param username [String] Tastytrade username
    # @param password [String] Tastytrade password (optional if remember_token provided)
    # @param remember_me [Boolean] Whether to save remember token
    # @param remember_token [String] Existing remember token for re-authentication
    # @param is_test [Boolean] Use test environment
    def initialize(username:, password: nil, remember_me: false, remember_token: nil, is_test: false, timeout: Client::DEFAULT_TIMEOUT)
      @username = username
      @password = password
      @remember_me = remember_me
      @remember_token = remember_token
      @is_test = is_test
      @client = Client.new(base_url: api_url, timeout: timeout)
    end

    # Authenticate with Tastytrade API
    #
    # @return [Session] Self for method chaining
    # @raise [Tastytrade::Error] If authentication fails
    def login
      response = @client.post("/sessions", login_credentials)
      data = response["data"]

      @user = Models::User.new(data["user"])
      @session_token = data["session-token"]
      @remember_token = data["remember-token"] if @remember_me

      # Track session expiration if provided
      if data["session-expiration"]
        @session_expiration = Time.parse(data["session-expiration"])
      end

      self
    end

    # Validate current session
    #
    # @return [Boolean] True if session is valid
    def validate
      warn "DEBUG: Validating session, user=#{@user&.email}" if ENV["DEBUG_SESSION"]
      response = get("/sessions/validate")
      if ENV["DEBUG_SESSION"]
        warn "DEBUG: Validate response email=#{response["data"]["email"]}, user email=#{@user&.email}"
      end
      response["data"]["email"] == @user.email
    rescue Tastytrade::Error => e
      warn "DEBUG: Validate error: #{e.message}" if ENV["DEBUG_SESSION"]
      false
    end

    # Destroy current session
    #
    # @return [nil]
    def destroy
      delete("/sessions") if @session_token
      @session_token = nil
      @remember_token = nil
      @user = nil
    end

    # Make authenticated GET request
    #
    # @param path [String] API endpoint path
    # @param params [Hash] Query parameters
    # @return [Hash] Parsed response
    def get(path, params = {})
      @client.get(path, params, auth_headers)
    end

    # Make authenticated POST request
    #
    # @param path [String] API endpoint path
    # @param body [Hash] Request body
    # @return [Hash] Parsed response
    def post(path, body = {})
      @client.post(path, body, auth_headers)
    end

    # Make authenticated PUT request
    #
    # @param path [String] API endpoint path
    # @param body [Hash] Request body
    # @return [Hash] Parsed response
    def put(path, body = {})
      @client.put(path, body, auth_headers)
    end

    # Make authenticated DELETE request
    #
    # @param path [String] API endpoint path
    # @return [Hash] Parsed response
    def delete(path)
      @client.delete(path, auth_headers)
    end

    # Check if authenticated
    #
    # @return [Boolean] True if session has token
    def authenticated?
      !@session_token.nil?
    end

    # Check if session is expired
    #
    # @return [Boolean] True if session is expired
    def expired?
      return false unless @session_expiration
      Time.now >= @session_expiration
    end

    # Time remaining until session expires
    #
    # @return [Float, nil] Seconds until expiration
    def time_until_expiry
      return nil unless @session_expiration
      @session_expiration - Time.now
    end

    # Refresh session using remember token
    #
    # @return [Session] Self
    # @raise [Tastytrade::Error] If refresh fails
    def refresh_session
      raise Tastytrade::Error, "No remember token available" unless @remember_token

      # Clear password and re-login with remember token
      @password = nil
      login
    end

    private

    def api_url
      @is_test ? Tastytrade::CERT_URL : Tastytrade::API_URL
    end

    def auth_headers
      raise Tastytrade::Error, "Not authenticated" unless @session_token

      { "Authorization" => @session_token }
    end

    def login_credentials
      credentials = {
        "login" => @username,
        "remember-me" => @remember_me
      }

      # Use remember token if available and no password
      if @remember_token && !@password
        credentials["remember-token"] = @remember_token
      else
        credentials["password"] = @password
      end

      credentials
    end
  end
end
