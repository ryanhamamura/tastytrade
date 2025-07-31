# frozen_string_literal: true

require "thor"
require "tty-table"
require_relative "cli_helpers"
require_relative "cli_config"
require_relative "session_manager"

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
      credentials = login_credentials
      environment = options[:test] ? "sandbox" : "production"

      info "Logging in to #{environment} environment..."
      session = authenticate_user(credentials)

      save_user_session(session, credentials, environment)

      # Enter interactive mode after successful login
      @current_session = session
      interactive_mode
    rescue Tastytrade::Error => e
      error e.message
      exit 1
    rescue StandardError => e
      error "Login failed: #{e.message}"
      exit 1
    end

    private

    def login_credentials
      {
        username: options[:username] || prompt.ask("Username:"),
        password: prompt.mask("Password:"),
        remember: options[:remember]
      }
    end

    def authenticate_user(credentials)
      session = Session.new(
        username: credentials[:username],
        password: credentials[:password],
        remember_me: credentials[:remember],
        is_test: options[:test]
      )
      session.login
      success "Successfully logged in as #{session.user.email}"
      session
    end

    def save_user_session(session, credentials, environment)
      manager = SessionManager.new(
        username: credentials[:username],
        environment: environment
      )

      if manager.save_session(session, password: credentials[:password], remember: credentials[:remember])
        info "Session saved securely" if credentials[:remember]
      else
        warning "Failed to save session credentials"
      end
    end

    public

    desc "logout", "Logout from Tastytrade"
    def logout
      session_info = current_session_info
      return warning("No active session found") unless session_info

      clear_user_session(session_info)
    end

    private

    def current_session_info
      username = config.get("current_username")
      return nil unless username

      {
        username: username,
        environment: config.get("environment") || "production"
      }
    end

    def clear_user_session(session_info)
      manager = SessionManager.new(
        username: session_info[:username],
        environment: session_info[:environment]
      )

      if manager.clear_session! && clear_config_data?
        success "Successfully logged out"
      else
        error "Failed to logout completely"
        exit 1
      end
    end

    def clear_config_data?
      config.delete("current_username")
      config.delete("environment")
      config.delete("last_login")
      true
    end

    public

    desc "accounts", "List all accounts"
    def accounts
      require_authentication!
      info "Fetching accounts..."

      accounts = fetch_accounts
      return if accounts.nil? || accounts.empty?

      display_accounts_table(accounts)
      handle_account_selection(accounts)
    rescue Tastytrade::Error => e
      error "Failed to fetch accounts: #{e.message}"
      exit 1
    rescue StandardError => e
      error "Unexpected error: #{e.message}"
      exit 1
    end

    private

    def fetch_accounts
      accounts = Tastytrade::Models::Account.get_all(current_session)
      if accounts.empty?
        warning "No accounts found"
        nil
      else
        accounts
      end
    end

    def display_accounts_table(accounts)
      current_account_number = config.get("current_account_number")
      headers = ["", "Account", "Nickname", "Type", "Status"]
      rows = build_account_rows(accounts, current_account_number)

      render_table(headers, rows)
      puts "\n#{pastel.dim("Total accounts:")} #{accounts.size}"
    end

    def build_account_rows(accounts, current_account_number)
      accounts.map do |account|
        indicator = account.account_number == current_account_number ? "→" : " "
        [
          indicator,
          account.account_number,
          account.nickname || "-",
          account.account_type_name || "Unknown",
          pastel.green("Active")
        ]
      end
    end

    def render_table(headers, rows)
      table = TTY::Table.new(headers, rows)
      puts table.render(:unicode, padding: [0, 1])
    rescue StandardError
      # Fallback for testing or non-TTY environments
      puts headers.join(" | ")
      puts "-" * 50
      rows.each { |row| puts row.join(" | ") }
    end

    def handle_account_selection(accounts)
      current_account_number = config.get("current_account_number")

      if accounts.size == 1
        config.set("current_account_number", accounts.first.account_number)
        info "Using account: #{accounts.first.account_number}"
      elsif !current_account_number || accounts.none? { |a| a.account_number == current_account_number }
        info "Use 'tastytrade select' to choose an account"
      end
    end

    public

    desc "select", "Select an account to use"
    def select
      require_authentication!

      accounts = fetch_accounts
      return if accounts.nil? || accounts.empty?

      handle_single_account(accounts) || prompt_for_account_selection(accounts)
    rescue Tastytrade::Error => e
      error "Failed to fetch accounts: #{e.message}"
      exit 1
    rescue StandardError => e
      error "Unexpected error: #{e.message}"
      exit 1
    end

    private

    def handle_single_account(accounts)
      return false unless accounts.size == 1

      config.set("current_account_number", accounts.first.account_number)
      success "Using account: #{accounts.first.account_number}"
      true
    end

    def prompt_for_account_selection(accounts)
      choices = build_account_choices(accounts)
      selected = prompt.select("Choose an account:", choices)

      config.set("current_account_number", selected)
      success "Selected account: #{selected}"
    end

    def build_account_choices(accounts)
      current_account_number = config.get("current_account_number")

      accounts.map do |account|
        label = build_account_label(account, current_account_number)
        { name: label, value: account.account_number }
      end
    end

    def build_account_label(account, current_account_number)
      label = account.account_number.to_s
      label += " - #{account.nickname}" if account.nickname
      label += " (#{account.account_type_name})" if account.account_type_name
      label += " [current]" if account.account_number == current_account_number
      label
    end

    public

    desc "balance", "Display account balance"
    def balance
      puts "Balance command not yet implemented"
    end

    desc "interactive", "Enter interactive mode"
    def interactive
      require_authentication!
      interactive_mode
    end

    private

    def interactive_mode
      info "Welcome to Tastytrade!"

      loop do
        choice = show_main_menu

        case choice
        when :accounts
          interactive_accounts
        when :select
          interactive_select
        when :balance
          interactive_balance
        when :portfolio
          info "Portfolio command not yet implemented"
        when :positions
          info "Positions command not yet implemented"
        when :orders
          info "Orders command not yet implemented"
        when :settings
          info "Settings command not yet implemented"
        when :exit
          break
        end
      end

      info "Goodbye!"
    end

    def show_main_menu
      account_info = current_account_number ? " (Account: #{current_account_number})" : " (No account selected)"

      # Create a fresh prompt instance to avoid event handler accumulation
      menu_prompt = TTY::Prompt.new

      # Add vim-style navigation
      menu_prompt.on(:keypress) do |event|
        case event.value
        when "j"
          menu_prompt.trigger(:keydown)
        when "k"
          menu_prompt.trigger(:keyup)
        when "q"
          return :exit
        end
      end

      menu_prompt.select("Main Menu#{account_info}", per_page: 10) do |menu|
        menu.enum "."  # Enable number shortcuts with . delimiter
        menu.help "(Use ↑/↓ arrows, vim j/k, or numbers 1-8)"

        menu.choice "Accounts - View all accounts", :accounts
        menu.choice "Select Account - Choose active account", :select
        menu.choice "Balance - View account balance", :balance
        menu.choice "Portfolio - View holdings", :portfolio
        menu.choice "Positions - View open positions", :positions
        menu.choice "Orders - View recent orders", :orders
        menu.choice "Settings - Configure preferences", :settings
        menu.choice "Exit", :exit
      end
    end

    def interactive_accounts
      accounts = fetch_accounts
      return if accounts.nil? || accounts.empty?

      display_accounts_table(accounts)

      prompt.keypress("\nPress any key to continue...")
    rescue Tastytrade::Error => e
      error "Failed to fetch accounts: #{e.message}"
      prompt.keypress("\nPress any key to continue...")
    end

    def interactive_select
      accounts = fetch_accounts
      return if accounts.nil? || accounts.empty?

      if accounts.size == 1
        handle_single_account(accounts)
      else
        prompt_for_account_selection(accounts)
      end

      prompt.keypress("\nPress any key to continue...")
    rescue Tastytrade::Error => e
      error "Failed to fetch accounts: #{e.message}"
      prompt.keypress("\nPress any key to continue...")
    end

    def interactive_balance
      info "Balance command not yet implemented"
      prompt.keypress("\nPress any key to continue...")
    end
  end
end
