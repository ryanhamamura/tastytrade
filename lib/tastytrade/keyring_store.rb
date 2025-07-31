# frozen_string_literal: true

require "keyring"

module Tastytrade
  # Secure credential storage using system keyring
  class KeyringStore
    SERVICE_NAME = "tastytrade-ruby"

    class << self
      # Store a credential securely
      #
      # @param key [String] The credential key
      # @param value [String] The credential value
      # @return [Boolean] Success status
      def set(key, value)
        return false if key.nil? || value.nil?

        backend.set_password(SERVICE_NAME, key.to_s, value.to_s)
        true
      rescue StandardError => e
        warn "Failed to store credential: #{e.message}"
        false
      end

      # Retrieve a credential
      #
      # @param key [String] The credential key
      # @return [String, nil] The credential value or nil if not found
      def get(key)
        return nil if key.nil?

        backend.get_password(SERVICE_NAME, key.to_s)
      rescue StandardError => e
        warn "Failed to retrieve credential: #{e.message}"
        nil
      end

      # Delete a credential
      #
      # @param key [String] The credential key
      # @return [Boolean] Success status
      def delete(key)
        return false if key.nil?

        backend.delete_password(SERVICE_NAME, key.to_s)
        true
      rescue StandardError => e
        warn "Failed to delete credential: #{e.message}"
        false
      end

      # Check if keyring is available
      #
      # @return [Boolean] True if keyring backend is available
      def available?
        !backend.nil?
      rescue StandardError
        false
      end

      private

      def backend
        @backend ||= Keyring.new
      rescue StandardError => e
        warn "Keyring not available: #{e.message}"
        nil
      end
    end
  end
end
