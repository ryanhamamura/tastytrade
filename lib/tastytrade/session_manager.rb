# frozen_string_literal: true

require_relative "keyring_store"
require "json"

module Tastytrade
  # Manages session persistence and token storage
  class SessionManager
    SESSION_KEY_PREFIX = "session"
    TOKEN_KEY_PREFIX = "token"
    REMEMBER_KEY_PREFIX = "remember"

    attr_reader :username, :environment

    def initialize(username:, environment: "production")
      @username = username
      @environment = environment
    end

    # Save session data securely
    #
    # @param session [Tastytrade::Session] The session to save
    # @param password [String] The password (only saved if remember is true)
    # @param remember [Boolean] Whether to save credentials for auto-login
    def save_session(session, password: nil, remember: false)
      # Always save the session token
      save_token(session.session_token)

      # Save session expiration if available
      save_session_expiration(session.session_expiration) if session.session_expiration

      if remember && session.remember_token
        save_remember_token(session.remember_token)
        save_password(password) if password && KeyringStore.available?
      end

      # Save session metadata
      config = CLIConfig.new
      config.set("current_username", username)
      config.set("environment", environment)
      config.set("last_login", Time.now.to_s)

      true
    rescue StandardError => e
      warn "Failed to save session: #{e.message}"
      false
    end

    # Load saved session if available
    #
    # @return [Hash, nil] Session data or nil if not found
    def load_session
      token = load_token
      return nil unless token

      {
        session_token: token,
        remember_token: load_remember_token,
        session_expiration: load_session_expiration,
        username: username,
        environment: environment
      }
    end

    # Create a new session from saved credentials
    #
    # @return [Tastytrade::Session, nil] Authenticated session or nil
    def restore_session
      password = load_password
      remember_token = load_remember_token

      return nil unless password || remember_token

      session = Session.new(
        username: username,
        password: password,
        remember_token: remember_token,
        is_test: environment == "sandbox"
      )

      session.login
      session
    rescue StandardError => e
      warn "Failed to restore session: #{e.message}"
      nil
    end

    # Clear all stored session data
    def clear_session!
      KeyringStore.delete(token_key)
      KeyringStore.delete(remember_token_key)
      KeyringStore.delete(password_key)
      KeyringStore.delete(session_expiration_key)

      config = CLIConfig.new
      config.delete("current_username")
      config.delete("last_login")

      true
    end

    # Check if we have stored credentials
    def saved_credentials?
      !load_password.nil? || !load_remember_token.nil?
    end

    private

    def token_key
      "#{TOKEN_KEY_PREFIX}_#{username}_#{environment}"
    end

    def remember_token_key
      "#{REMEMBER_KEY_PREFIX}_#{username}_#{environment}"
    end

    def password_key
      "password_#{username}_#{environment}"
    end

    def session_expiration_key
      "#{SESSION_KEY_PREFIX}_expiration_#{username}_#{environment}"
    end

    def save_token(token)
      KeyringStore.set(token_key, token)
    end

    def load_token
      KeyringStore.get(token_key)
    end

    def save_remember_token(token)
      KeyringStore.set(remember_token_key, token)
    end

    def load_remember_token
      KeyringStore.get(remember_token_key)
    end

    def save_password(password)
      KeyringStore.set(password_key, password)
    end

    def load_password
      KeyringStore.get(password_key)
    end

    def save_session_expiration(expiration)
      KeyringStore.set(session_expiration_key, expiration.iso8601)
    end

    def load_session_expiration
      value = KeyringStore.get(session_expiration_key)
      value ? Time.parse(value).iso8601 : nil
    rescue StandardError
      nil
    end
  end
end
