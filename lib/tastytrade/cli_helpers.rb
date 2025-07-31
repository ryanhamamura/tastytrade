# frozen_string_literal: true

require "pastel"
require "tty-prompt"

module Tastytrade
  # Common CLI helper methods
  module CLIHelpers
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      # Ensure consistent exit behavior
      def exit_on_failure?
        true
      end
    end

    # Colorization helper
    def pastel
      @pastel ||= Pastel.new
    end

    # Interactive prompt helper
    def prompt
      @prompt ||= TTY::Prompt.new
    end

    # Configuration helper
    def config
      @config ||= CLIConfig.new
    end

    # Print error message in red
    def error(message)
      warn pastel.red("Error: #{message}")
    end

    # Print warning message in yellow
    def warning(message)
      warn pastel.yellow("Warning: #{message}")
    end

    # Print success message in green
    def success(message)
      puts pastel.green("✓ #{message}")
    end

    # Print info message
    def info(message)
      puts pastel.cyan("→ #{message}")
    end

    # Format currency values
    def format_currency(value)
      return "$0.00" if value.nil? || value.zero?

      formatted = format("$%.2f", value.abs)
      # Add thousand separators
      formatted.gsub!(/(\d)(?=(\d\d\d)+(?!\d))/, '\\1,')
      value.negative? ? "-#{formatted}" : formatted
    end

    # Color code value based on positive/negative
    def color_value(value, format_as_currency: true)
      return pastel.dim("$0.00") if value.nil? || value.zero?

      formatted = format_as_currency ? format_currency(value) : value.to_s

      if value.positive?
        pastel.green(formatted)
      else
        pastel.red(formatted)
      end
    end

    # Get current session if authenticated
    def current_session
      @current_session ||= load_session
    rescue StandardError => e
      error("Failed to load session: #{e.message}")
      nil
    end

    # Check if user is authenticated
    def authenticated?
      !current_session.nil?
    end

    # Require authentication or exit
    def require_authentication!
      return if authenticated?

      error("You must be logged in to use this command.")
      info("Run 'tastytrade login' to authenticate.")
      exit 1
    end

    private

    def load_session
      # Try to load saved session
      username = config.get("current_username")
      environment = config.get("environment") || "production"

      return nil unless username

      manager = SessionManager.new(username: username, environment: environment)
      session_data = manager.load_session

      return nil unless session_data && session_data[:session_token]

      # Create session with saved token
      session = Session.new(
        username: session_data[:username],
        password: nil,
        is_test: environment == "sandbox"
      )

      # Set the tokens directly
      session.instance_variable_set(:@session_token, session_data[:session_token])
      session.instance_variable_set(:@remember_token, session_data[:remember_token])

      # Validate the session is still active
      if session.validate
        session
      else
        # Session expired, try to restore with saved credentials
        manager.restore_session
      end
    rescue StandardError
      nil
    end
  end
end
