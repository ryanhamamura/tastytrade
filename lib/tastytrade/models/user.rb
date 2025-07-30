# frozen_string_literal: true

module Tastytrade
  module Models
    # Represents a Tastytrade user
    class User < Base
      attr_reader :email, :username, :external_id, :is_professional

      def professional?
        @is_professional == true
      end

      private

      def parse_attributes
        @email = @data["email"]
        @username = @data["username"]
        @external_id = @data["external-id"]
        @is_professional = @data["is-professional"]
      end
    end
  end
end
