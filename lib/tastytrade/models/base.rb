# frozen_string_literal: true

require "time"

module Tastytrade
  module Models
    # Base class for all Tastytrade data models
    class Base
      def initialize(data = {})
        @data = stringify_keys(data)
        parse_attributes
      end

      attr_reader :data

      private

      # Convert snake_case to dash-case for API compatibility
      def to_api_key(key)
        key.to_s.tr("_", "-")
      end

      # Convert dash-case to snake_case for Ruby
      def to_ruby_key(key)
        key.to_s.tr("-", "_")
      end

      def stringify_keys(hash)
        hash.transform_keys(&:to_s)
      end

      # Override in subclasses to define attribute parsing
      def parse_attributes
        # Implemented by subclasses
      end

      # Helper method to parse datetime strings
      def parse_time(value)
        return nil if value.nil? || value.empty?

        Time.parse(value)
      rescue ArgumentError
        nil
      end
    end
  end
end
