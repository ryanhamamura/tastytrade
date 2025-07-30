# frozen_string_literal: true

require_relative "models"

module Tastytrade
  # Manages authentication and session state for Tastytrade API
  class Session
    attr_reader :user, :session_token, :remember_token, :is_test

    # Initialize a new session
    #
    # @param username [String] Tastytrade username
    # @param password [String] Tastytrade password
    # @param remember_me [Boolean] Whether to save remember token
    # @param is_test [Boolean] Use test environment
    def initialize(username:, password:, remember_me: false, is_test: false)
      @username = username
      @password = password
      @remember_me = remember_me
      @is_test = is_test
      @client = Client.new(base_url: api_url)
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

      self
    end

    # Validate current session
    #
    # @return [Boolean] True if session is valid
    def validate
      response = get("/sessions/validate")
      response["data"]["email"] == @user.email
    rescue Tastytrade::Error
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

    private

    def api_url
      @is_test ? Tastytrade::CERT_URL : Tastytrade::API_URL
    end

    def auth_headers
      raise Tastytrade::Error, "Not authenticated" unless @session_token

      { "Authorization" => @session_token }
    end

    def login_credentials
      {
        "login" => @username,
        "password" => @password,
        "remember-me" => @remember_me
      }
    end
  end
end
