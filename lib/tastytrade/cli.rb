# frozen_string_literal: true

require "thor"
require "tty-table"
require "bigdecimal"
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
    rescue Tastytrade::InvalidCredentialsError => e
      error "Invalid credentials: #{e.message}"
      exit 1
    rescue Tastytrade::SessionExpiredError => e
      error "Session expired: #{e.message}"
      info "Please login again"
      exit 1
    rescue Tastytrade::NetworkTimeoutError => e
      error "Network timeout: #{e.message}"
      info "Check your internet connection and try again"
      exit 1
    rescue Tastytrade::Error => e
      error e.message
      exit 1
    rescue StandardError => e
      error "Login failed: #{e.message}"
      exit 1
    end

    private

    def format_time_remaining(seconds)
      return "unknown time" unless seconds && seconds > 0

      hours = (seconds / 3600).to_i
      minutes = ((seconds % 3600) / 60).to_i

      if hours > 0
        "#{hours}h #{minutes}m"
      else
        "#{minutes}m"
      end
    end

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

    def create_vim_prompt
      menu_prompt = TTY::Prompt.new
      @exit_requested = false

      # Add vim-style navigation
      menu_prompt.on(:keypress) do |event|
        case event.value
        when "j"
          menu_prompt.trigger(:keydown)
        when "k"
          menu_prompt.trigger(:keyup)
        when "q", "\e", "\e[" # q or ESC key
          @exit_requested = true
          menu_prompt.trigger(:keyenter) # Select current item to exit the menu
        end
      end

      menu_prompt
    end

    def handle_single_account(accounts)
      return false unless accounts.size == 1

      account = accounts.first
      config.set("current_account_number", account.account_number)
      @current_account = account # Cache the account object
      success "Using account: #{account.account_number}"
      true
    end

    def prompt_for_account_selection(accounts)
      choices = build_account_choices(accounts)
      selected = prompt.select("Choose an account:", choices)

      config.set("current_account_number", selected)
      # Cache the selected account object
      @current_account = accounts.find { |a| a.account_number == selected }
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
    option :all, type: :boolean, desc: "Show balances for all accounts"
    def balance
      require_authentication!

      if options[:all]
        display_all_account_balances
      else
        account = current_account
        unless account
          account = select_account_interactively
          return unless account
        end
        display_account_balance(account)
      end
    rescue => e
      error "Failed to fetch balance: #{e.message}"
      exit 1
    end

    desc "status", "Check session status"
    def status
      session = current_session
      unless session
        warning "No active session"
        info "Run 'tastytrade login' to authenticate"
        return
      end

      puts "Session Status:"
      puts "  User: #{session.user.email}"
      puts "  Environment: #{config.get("environment") || "production"}"

      if session.session_expiration
        if session.expired?
          puts "  Status: #{pastel.red("Expired")}"
        else
          time_left = format_time_remaining(session.time_until_expiry)
          puts "  Status: #{pastel.green("Active")}"
          puts "  Expires in: #{time_left}"
        end
      else
        puts "  Status: #{pastel.green("Active")}"
        puts "  Expires in: Unknown"
      end

      puts "  Remember token: #{session.remember_token ? pastel.green("Available") : pastel.red("Not available")}"
      puts "  Auto-refresh: #{session.remember_token ? pastel.green("Enabled") : pastel.yellow("Disabled")}"
    end

    desc "refresh", "Refresh the current session"
    def refresh
      session = current_session
      unless session
        error "No active session to refresh"
        exit 1
      end

      unless session.remember_token
        error "No remember token available for refresh"
        info "Login with --remember flag to enable session refresh"
        exit 1
      end

      info "Refreshing session..."

      begin
        session.refresh_session

        # Save refreshed session
        manager = SessionManager.new(
          username: session.user.email,
          environment: config.get("environment") || "production"
        )
        manager.save_session(session)

        success "Session refreshed successfully"
        info "Session expires in #{format_time_remaining(session.time_until_expiry)}" if session.time_until_expiry
      rescue Tastytrade::TokenRefreshError => e
        error "Failed to refresh session: #{e.message}"
        exit 1
      end
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

      menu_prompt = create_vim_prompt

      result = menu_prompt.select("Main Menu#{account_info}", per_page: 10) do |menu|
        menu.enum "."  # Enable number shortcuts with . delimiter
        menu.help "(Use ↑/↓ arrows, vim j/k, numbers 1-8, q or ESC to quit)"

        menu.choice "Accounts - View all accounts", :accounts
        menu.choice "Select Account - Choose active account", :select
        menu.choice "Balance - View account balance", :balance
        menu.choice "Portfolio - View holdings", :portfolio
        menu.choice "Positions - View open positions", :positions
        menu.choice "Orders - View recent orders", :orders
        menu.choice "Settings - Configure preferences", :settings
        menu.choice "Exit", :exit
      end

      # Handle q or ESC key press
      @exit_requested ? :exit : result
    rescue Interrupt
      # Handle Ctrl+C gracefully
      :exit
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
      # Try to use cached account first, only fetch if needed
      account = @current_account

      # If no cached account, check if we have an account number saved
      if !account && current_account_number
        begin
          account = Tastytrade::Models::Account.get(current_session, current_account_number)
          @current_account = account # Cache it
        rescue => e
          # Don't show error here, will try to select account below
          account = nil
        end
      end

      # If still no account, let user select one
      account ||= select_account_interactively
      return unless account

      display_account_balance(account)

      menu_prompt = create_vim_prompt

      action = menu_prompt.select("What would you like to do?", per_page: 10) do |menu|
        menu.enum "."  # Enable number shortcuts with . delimiter
        menu.help "(Use ↑/↓ arrows, vim j/k, numbers 1-4, q or ESC to go back)"

        menu.choice "View positions", :positions
        menu.choice "Switch account", :switch
        menu.choice "Refresh", :refresh
        menu.choice "Back to main menu", :back
      end

      # Handle q or ESC key press
      return if @exit_requested || action == :back

      case action
      when :positions
        info "Positions view not yet implemented"
        prompt.keypress("\nPress any key to continue...")
        interactive_balance # Show balance menu again
      when :switch
        interactive_select
        interactive_balance if current_account_number # Check for account number instead of making API call
      when :refresh
        @current_account = nil # Clear cache to force refresh
        interactive_balance
      end
    rescue Interrupt
      # Handle Ctrl+C gracefully - go back to main menu
      nil
    rescue => e
      error "Failed to fetch balance: #{e.message}"
      prompt.keypress("\nPress any key to continue...")
    end

    def display_account_balance(account)
      balance = account.get_balances(current_session)

      table = TTY::Table.new(
        title: "#{account.nickname || account.account_number} - Account Balance",
        header: ["Metric", "Value"],
        rows: [
          ["Cash Balance", format_currency(balance.cash_balance)],
          ["Net Liquidating Value", format_currency(balance.net_liquidating_value)],
          ["Equity Buying Power", format_currency(balance.equity_buying_power)],
          ["Day Trading BP", format_currency(balance.day_trading_buying_power)],
          ["Available Trading Funds", format_currency(balance.available_trading_funds)],
          ["BP Usage", "#{balance.buying_power_usage_percentage.to_s("F")}%"]
        ]
      )

      puts
      begin
        puts table.render(:unicode, padding: [0, 1])
      rescue StandardError
        # Fallback for testing or non-TTY environments
        puts "#{account.nickname || account.account_number} - Account Balance"
        puts "-" * 50
        table.rows.each do |row|
          puts "#{row[0]}: #{row[1]}"
        end
      end

      # Add color-coded BP warning if > 80%
      if balance.high_buying_power_usage?
        puts
        warning "High buying power usage: #{balance.buying_power_usage_percentage.to_s("F")}%"
      end
    end

    def display_all_account_balances
      info "Fetching balances for all accounts..."
      accounts = Tastytrade::Models::Account.get_all(current_session)
      total_nlv = BigDecimal("0")

      accounts.each do |account|
        balance = account.get_balances(current_session)
        total_nlv += balance.net_liquidating_value
        display_account_balance(account)
        puts
      end

      puts
      info "Total Net Liquidating Value: #{format_currency(total_nlv)}"
    end

    def select_account_interactively
      accounts = fetch_accounts
      return nil if accounts.nil? || accounts.empty?

      if accounts.size == 1
        accounts.first
      else
        choices = accounts.map do |account|
          label = build_account_label(account, nil)
          [label, account]
        end.to_h

        prompt.select("Select an account:", choices)
      end
    end
  end
end
