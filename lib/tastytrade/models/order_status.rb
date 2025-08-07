# frozen_string_literal: true

module Tastytrade
  module Models
    # Order status constants and helpers
    module OrderStatus
      # Submission phase statuses
      RECEIVED = "Received"
      ROUTED = "Routed"
      IN_FLIGHT = "In Flight"
      CONTINGENT = "Contingent"

      # Working phase statuses
      LIVE = "Live"
      CANCEL_REQUESTED = "Cancel Requested"
      REPLACE_REQUESTED = "Replace Requested"

      # Terminal phase statuses
      FILLED = "Filled"
      CANCELLED = "Cancelled"
      REJECTED = "Rejected"
      EXPIRED = "Expired"
      REMOVED = "Removed"

      # Status groupings
      SUBMISSION_STATUSES = [
        RECEIVED,
        ROUTED,
        IN_FLIGHT,
        CONTINGENT
      ].freeze

      WORKING_STATUSES = [
        LIVE,
        CANCEL_REQUESTED,
        REPLACE_REQUESTED
      ].freeze

      TERMINAL_STATUSES = [
        FILLED,
        CANCELLED,
        REJECTED,
        EXPIRED,
        REMOVED
      ].freeze

      ALL_STATUSES = (
        SUBMISSION_STATUSES +
        WORKING_STATUSES +
        TERMINAL_STATUSES
      ).freeze

      # Check if status is in submission phase
      def self.submission?(status)
        SUBMISSION_STATUSES.include?(status)
      end

      # Check if status is in working phase
      def self.working?(status)
        WORKING_STATUSES.include?(status)
      end

      # Check if status is terminal
      def self.terminal?(status)
        TERMINAL_STATUSES.include?(status)
      end

      # Check if status allows cancellation
      def self.cancellable?(status)
        status == LIVE
      end

      # Check if status allows replacement
      def self.editable?(status)
        status == LIVE
      end

      # Validate status value
      def self.valid?(status)
        ALL_STATUSES.include?(status)
      end
    end
  end
end
