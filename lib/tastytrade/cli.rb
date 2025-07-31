# frozen_string_literal: true

require "thor"
require_relative "cli_helpers"
require_relative "cli_config"

module Tastytrade
  # Main CLI class for Tastytrade gem
  class CLI < Thor
    include Tastytrade::CLIHelpers
    package_name "Tastytrade"

    # Map common version flags to version command
    map %w[--version -v] => :version

    class_option :test, type: :boolean, default: false, desc: "Use sandbox environment"

    desc "version", "Display version information"
    def version
      puts "Tastytrade CLI v#{Tastytrade::VERSION}"
    end

    desc "login", "Login to Tastytrade"
    option :username, aliases: "-u", desc: "Username"
    option :remember, aliases: "-r", type: :boolean, default: false, desc: "Remember credentials"
    def login
      username = options[:username] || prompt.ask("Username:")
      password = prompt.mask("Password:")

      info "Logging in to #{options[:test] ? 'sandbox' : 'production'} environment..."

      begin
        session = Session.new(
          username: username,
          password: password,
          remember_me: options[:remember],
          is_test: options[:test]
        )
        session.login

        success "Successfully logged in as #{session.user.email}"
        
        # Save session info for future commands
        config.set("current_username", username)
        config.set("environment", options[:test] ? "sandbox" : "production")
        
        # TODO: Implement secure credential storage
      rescue Tastytrade::Error => e
        error e.message
        exit 1
      rescue StandardError => e
        error "Login failed: #{e.message}"
        exit 1
      end
    end

    desc "accounts", "List all accounts"
    def accounts
      puts "Accounts command not yet implemented"
    end

    desc "balance", "Display account balance"
    def balance
      puts "Balance command not yet implemented"
    end
  end
end