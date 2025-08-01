# frozen_string_literal: true

require "fileutils"
require "json"

module Tastytrade
  # Secure file-based credential storage
  module FileStore
    class << self
      # Store a credential in a file
      #
      # @param key [String] The credential key
      # @param value [String] The credential value
      # @return [Boolean] Success status
      def set(key, value)
        return false if key.nil? || value.nil?

        ensure_storage_directory
        File.write(credential_path(key), value.to_s, mode: "w", perm: 0o600)
        true
      rescue StandardError => e
        warn "Failed to store credential: #{e.message}" if ENV["DEBUG_SESSION"]
        false
      end

      # Retrieve a credential from a file
      #
      # @param key [String] The credential key
      # @return [String, nil] The credential value or nil if not found
      def get(key)
        return nil if key.nil?

        path = credential_path(key)
        return nil unless File.exist?(path)

        File.read(path).strip
      rescue StandardError => e
        warn "Failed to retrieve credential: #{e.message}" if ENV["DEBUG_SESSION"]
        nil
      end

      # Delete a credential file
      #
      # @param key [String] The credential key
      # @return [Boolean] Success status
      def delete(key)
        return false if key.nil?

        path = credential_path(key)
        return true unless File.exist?(path)

        File.delete(path)
        true
      rescue StandardError => e
        warn "Failed to delete credential: #{e.message}" if ENV["DEBUG_SESSION"]
        false
      end

      # Check if file storage is available
      #
      # @return [Boolean] Always true for file storage
      def available?
        true
      end

      private

      def storage_directory
        @storage_directory ||= File.expand_path("~/.config/tastytrade/credentials")
      end

      def ensure_storage_directory
        FileUtils.mkdir_p(storage_directory, mode: 0o700)
      end

      def credential_path(key)
        # Sanitize key to be filesystem-safe
        safe_key = key.to_s.gsub(/[^a-zA-Z0-9._@-]/, "_")
        File.join(storage_directory, "#{safe_key}.cred")
      end
    end
  end
end
