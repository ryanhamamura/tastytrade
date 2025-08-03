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
    long_desc <<-LONGDESC
    Login to your Tastytrade account.#{" "}

    Credentials can be provided via:
    - Environment variables: TASTYTRADE_USERNAME, TASTYTRADE_PASSWORD (or TT_USERNAME, TT_PASSWORD)
    - Command line option: --username (password will be prompted)
    - Interactive prompts (default)

    Optional environment variables:
    - TASTYTRADE_ENVIRONMENT=sandbox (or TT_ENVIRONMENT) for test environment
    - TASTYTRADE_REMEMBER=true (or TT_REMEMBER) to save session for auto-refresh

    Examples:
      $ tastytrade login
      $ tastytrade login --username user@example.com
      $ tastytrade login --no-interactive  # Skip interactive mode
      $ TASTYTRADE_USERNAME=user@example.com TASTYTRADE_PASSWORD=pass tastytrade login --no-interactive
    LONGDESC
    option :username, aliases: "-u", desc: "Username"
    option :remember, aliases: "-r", type: :boolean, default: false, desc: "Remember credentials"
    option :no_interactive, type: :boolean, default: false, desc: "Skip interactive mode after login"
    def login
      # Try environment variables first
      if (session = Session.from_environment)
        environment = session.instance_variable_get(:@is_test) ? "sandbox" : "production"
        info "Using credentials from environment variables..."
        info "Logging in to #{environment} environment..."

        begin
          session.login
          success "Successfully logged in as #{session.user.email}"

          save_user_session(session, {
                              username: session.user.email,
                              remember: session.remember_token ? true : false
                            }, environment)

          @current_session = session
          interactive_mode unless options[:no_interactive]
          return
        rescue Tastytrade::Error => e
          error "Environment variable login failed: #{e.message}"
          info "Falling back to interactive login..."
        end
      end

      # Fall back to interactive login
      environment = options[:test] ? "sandbox" : "production"
      credentials = login_credentials
      info "Logging in to #{environment} environment..."
      session = authenticate_user(credentials)

      # Update credentials with actual email from session
      credentials_with_email = credentials.merge(username: session.user.email)
      save_user_session(session, credentials_with_email, environment)

      # Enter interactive mode after successful login (unless --no-interactive)
      @current_session = session
      interactive_mode unless options[:no_interactive]
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

      # Save the configuration first
      config.set("current_username", credentials[:username])
      config.set("environment", environment)
      config.set("last_login", Time.now.to_s)

      if manager.save_session(session, password: credentials[:password], remember: credentials[:remember])
        info "Session saved securely"
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

    desc "positions", "Display account positions"
    option :account, type: :string, desc: "Account number (uses default if not specified)"
    option :symbol, type: :string, desc: "Filter by symbol"
    option :underlying_symbol, type: :string, desc: "Filter by underlying symbol"
    option :include_closed, type: :boolean, default: false, desc: "Include closed positions"
    # Display account positions with optional filtering
    #
    # @example Display all open positions
    #   tastytrade positions
    #
    # @example Display positions for a specific symbol
    #   tastytrade positions --symbol AAPL
    #
    # @example Display option positions for an underlying symbol
    #   tastytrade positions --underlying-symbol SPY
    #
    # @example Include closed positions
    #   tastytrade positions --include-closed
    #
    # @example Display positions for a specific account
    #   tastytrade positions --account 5WX12345
    #
    def positions
      require_authentication!

      # Get the account to use
      account = if options[:account]
        Tastytrade::Models::Account.get(current_session, options[:account])
      else
        current_account || select_account_interactively
      end

      return unless account

      info "Fetching positions for account #{account.account_number}..."

      # Fetch positions with filters
      positions = account.get_positions(
        current_session,
        symbol: options[:symbol],
        underlying_symbol: options[:underlying_symbol],
        include_closed: options[:include_closed]
      )

      if positions.empty?
        warning "No positions found"
        return
      end

      # Display positions using formatter
      formatter = Tastytrade::PositionsFormatter.new(pastel: pastel)
      formatter.format_table(positions)
    rescue Tastytrade::Error => e
      error "Failed to fetch positions: #{e.message}"
      exit 1
    rescue StandardError => e
      error "Unexpected error: #{e.message}"
      exit 1
    end

    desc "history", "Display transaction history"
    option :account, type: :string, desc: "Account number (uses default if not specified)"
    option :start_date, type: :string, desc: "Start date (YYYY-MM-DD)"
    option :end_date, type: :string, desc: "End date (YYYY-MM-DD)"
    option :symbol, type: :string, desc: "Filter by symbol"
    option :type, type: :string, desc: "Filter by transaction type"
    option :group_by, type: :string, desc: "Group transactions by: symbol, type, or date"
    option :limit, type: :numeric, desc: "Limit number of transactions"
    # Display transaction history with optional filtering and grouping
    #
    # @example Display all transactions
    #   tastytrade history
    #
    # @example Display transactions for a specific symbol
    #   tastytrade history --symbol AAPL
    #
    # @example Display transactions for a date range
    #   tastytrade history --start-date 2024-01-01 --end-date 2024-12-31
    #
    # @example Group transactions by symbol
    #   tastytrade history --group-by symbol
    #
    # @example Filter by transaction type
    #   tastytrade history --type Trade
    #
    def history
      require_authentication!

      # Get the account to use
      account = if options[:account]
        Tastytrade::Models::Account.get(current_session, options[:account])
      else
        current_account || select_account_interactively
      end

      return unless account

      info "Fetching transaction history for account #{account.account_number}..."

      # Build filter options
      filter_options = {}
      filter_options[:start_date] = Date.parse(options[:start_date]) if options[:start_date]
      filter_options[:end_date] = Date.parse(options[:end_date]) if options[:end_date]
      filter_options[:symbol] = options[:symbol].upcase if options[:symbol]
      filter_options[:transaction_types] = [options[:type]] if options[:type]
      filter_options[:per_page] = options[:limit] if options[:limit]

      # Fetch transactions
      transactions = account.get_transactions(current_session, **filter_options)

      if transactions.empty?
        warning "No transactions found"
        return
      end

      # Display transactions using formatter
      formatter = Tastytrade::HistoryFormatter.new(pastel: pastel)
      group_by = options[:group_by]&.to_sym
      formatter.format_table(transactions, group_by: group_by)
    rescue Date::Error => e
      error "Invalid date format: #{e.message}. Use YYYY-MM-DD format."
      exit 1
    rescue Tastytrade::Error => e
      error "Failed to fetch transaction history: #{e.message}"
      exit 1
    rescue StandardError => e
      error "Unexpected error: #{e.message}"
      exit 1
    end

    desc "buying_power", "Display buying power status"
    option :account, type: :string, desc: "Account number (uses default if not specified)"
    # Display buying power status and usage
    #
    # @example Display buying power status
    #   tastytrade buying_power
    #
    # @example Display buying power for specific account
    #   tastytrade buying_power --account 5WX12345
    #
    def buying_power
      require_authentication!

      # Get the account to use
      account = if options[:account]
        Tastytrade::Models::Account.get(current_session, options[:account])
      else
        current_account || select_account_interactively
      end

      return unless account

      info "Fetching buying power status for account #{account.account_number}..."

      balance = account.get_balances(current_session)

      # Create buying power status table
      headers = ["Buying Power Type", "Available", "Usage %", "Status"]
      rows = [
        [
          "Equity Buying Power",
          format_currency(balance.equity_buying_power),
          "#{balance.buying_power_usage_percentage.to_s("F")}%",
          format_bp_status(balance.buying_power_usage_percentage)
        ],
        [
          "Derivative Buying Power",
          format_currency(balance.derivative_buying_power),
          "#{balance.derivative_buying_power_usage_percentage.to_s("F")}%",
          format_bp_status(balance.derivative_buying_power_usage_percentage)
        ],
        [
          "Day Trading Buying Power",
          format_currency(balance.day_trading_buying_power),
          "-",
          balance.day_trading_buying_power > 0 ? pastel.green("Available") : pastel.yellow("N/A")
        ]
      ]

      table = TTY::Table.new(headers, rows)

      puts
      begin
        puts table.render(:unicode, padding: [0, 1])
      rescue StandardError
        # Fallback for testing or non-TTY environments
        puts headers.join(" | ")
        puts "-" * 80
        rows.each { |row| puts row.join(" | ") }
      end

      # Display additional metrics
      puts
      puts "Additional Information:"
      puts "  Available Trading Funds: #{format_currency(balance.available_trading_funds)}"
      puts "  Cash Balance: #{format_currency(balance.cash_balance)}"
      puts "  Net Liquidating Value: #{format_currency(balance.net_liquidating_value)}"

      # Display warnings if needed
      if balance.high_buying_power_usage?
        puts
        warning "High buying power usage detected! Consider reducing positions."
      end
    rescue Tastytrade::Error => e
      error "Failed to fetch buying power status: #{e.message}"
      exit 1
    rescue StandardError => e
      error "Unexpected error: #{e.message}"
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

    desc "order SYMBOL QUANTITY", "Place an order for equities"
    option :type, default: "market", desc: "Order type (market or limit)"
    option :price, type: :numeric, desc: "Price for limit orders"
    option :action, default: "buy", desc: "Order action (buy or sell)"
    option :dry_run, type: :boolean, default: false, desc: "Simulate order without placing it"
    option :account, type: :string, desc: "Account number (uses default if not specified)"
    # Place an order for equities
    #
    # @example Place a market buy order
    #   tastytrade order AAPL 100
    #
    # @example Place a limit buy order
    #   tastytrade order AAPL 100 --type limit --price 150.50
    #
    # @example Place a sell order
    #   tastytrade order AAPL 100 --action sell
    #
    # @example Dry run an order
    #   tastytrade order AAPL 100 --dry-run
    #
    def order(symbol, quantity)
      require_authentication!

      # Get the account to use
      account = if options[:account]
        Tastytrade::Models::Account.get(current_session, options[:account])
      else
        current_account || select_account_interactively
      end

      return unless account

      # Create the order leg
      action = case options[:action].downcase
               when "buy"
                 Tastytrade::OrderAction::BUY_TO_OPEN
               when "sell"
                 Tastytrade::OrderAction::SELL_TO_CLOSE
               else
                 error "Invalid action: #{options[:action]}. Must be 'buy' or 'sell'"
                 exit 1
      end

      leg = Tastytrade::OrderLeg.new(
        action: action,
        symbol: symbol.upcase,
        quantity: quantity
      )

      # Create the order
      order_type = case options[:type].downcase
                   when "market"
                     Tastytrade::OrderType::MARKET
                   when "limit"
                     Tastytrade::OrderType::LIMIT
                   else
                     error "Invalid order type: #{options[:type]}. Must be 'market' or 'limit'"
                     exit 1
      end

      begin
        order = Tastytrade::Order.new(
          type: order_type,
          legs: leg,
          price: options[:price]
        )
      rescue ArgumentError => e
        error e.message
        exit 1
      end

      # Place the order
      order_desc = "#{options[:type]} #{options[:action]} order for #{quantity} shares of #{symbol}"
      info "Placing #{options[:dry_run] ? "simulated " : ""}#{order_desc}..."

      begin
        # First do a dry run to check buying power impact
        dry_run_response = account.place_order(current_session, order, dry_run: true)

        # Check if this is a BuyingPowerEffect object
        if dry_run_response.buying_power_effect.is_a?(Tastytrade::Models::BuyingPowerEffect)
          bp_effect = dry_run_response.buying_power_effect
          bp_usage = bp_effect.buying_power_usage_percentage

          if bp_usage > 80
            warning "This order will use #{bp_usage.to_s("F")}% of your buying power!"

            # Fetch current balance for more context
            balance = account.get_balances(current_session)
            puts ""
            puts "Current Buying Power Status:"
            puts "  Available Trading Funds: #{format_currency(balance.available_trading_funds)}"
            puts "  Equity Buying Power: #{format_currency(balance.equity_buying_power)}"
            puts "  Current BP Usage: #{balance.buying_power_usage_percentage.to_s("F")}%"
            puts ""

            unless options[:dry_run]
              unless prompt.yes?("Are you sure you want to proceed with this order?")
                info "Order cancelled"
                return
              end
            end
          end
        end

        # Place the actual order if not dry run
        if options[:dry_run]
          response = dry_run_response
          success "Dry run successful!"
        else
          response = account.place_order(current_session, order, dry_run: false)
          success "Order placed successfully!"
        end

        puts ""
        puts "Order Details:"
        if response.order_id && !response.order_id.empty?
          puts "  Order ID: #{response.order_id}"
        end
        if response.status && !response.status.empty?
          puts "  Status: #{response.status}"
        end
        if response.account_number && !response.account_number.empty?
          puts "  Account: #{response.account_number}"
        end

        # Handle both BigDecimal and BuyingPowerEffect
        if response.buying_power_effect
          if response.buying_power_effect.is_a?(Tastytrade::Models::BuyingPowerEffect)
            bp_effect = response.buying_power_effect
            puts "  Buying Power Impact: #{format_currency(bp_effect.buying_power_change_amount)}"
            puts "  BP Usage: #{bp_effect.buying_power_usage_percentage.to_s("F")}%"
          else
            puts "  Buying Power Effect: #{format_currency(response.buying_power_effect)}"
          end
        end

        if response.warnings.any?
          puts ""
          warning "Warnings:"
          response.warnings.each do |w|
            if w.is_a?(Hash)
              puts "  - #{w["message"] || w["code"]}"
            else
              puts "  - #{w}"
            end
          end
        end
      rescue Tastytrade::Error => e
        error "Failed to place order: #{e.message}"
        exit 1
      end
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
          interactive_positions
        when :history
          interactive_history
        when :orders
          interactive_order
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
        menu.help "(Use ↑/↓ arrows, vim j/k, numbers 1-9, q or ESC to quit)"

        menu.choice "Accounts - View all accounts", :accounts
        menu.choice "Select Account - Choose active account", :select
        menu.choice "Balance - View account balance", :balance
        menu.choice "Portfolio - View holdings", :portfolio
        menu.choice "Positions - View open positions", :positions
        menu.choice "History - View transaction history", :history
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
        interactive_positions
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

    def interactive_positions
      account = @current_account || current_account || select_account_interactively
      return unless account

      info "Fetching positions for account #{account.account_number}..."

      positions = account.get_positions(current_session)

      if positions.empty?
        warning "No positions found"
        prompt.keypress("\nPress any key to continue...")
        return
      end

      formatter = Tastytrade::PositionsFormatter.new(pastel: pastel)
      formatter.format_table(positions)

      prompt.keypress("\nPress any key to continue...")
    rescue Tastytrade::Error => e
      error "Failed to fetch positions: #{e.message}"
      prompt.keypress("\nPress any key to continue...")
    rescue StandardError => e
      error "Unexpected error: #{e.message}"
      prompt.keypress("\nPress any key to continue...")
    end

    def interactive_history
      account = @current_account || current_account || select_account_interactively
      return unless account

      # Create vim-enabled prompt for grouping option
      group_prompt = create_vim_prompt
      grouping = group_prompt.select("How would you like to view transactions?", per_page: 5) do |menu|
        menu.enum "."
        menu.help "(Use ↑/↓ arrows, vim j/k, numbers 1-5, q or ESC to go back)"
        menu.choice "All transactions (detailed)", nil
        menu.choice "Group by symbol", :symbol
        menu.choice "Group by type", :type
        menu.choice "Group by date", :date
        menu.choice "Back to main menu", :back
      end

      return if @exit_requested || grouping == :back

      # Ask for date range
      filter_by_date = prompt.yes?("Filter by date range?")

      filter_options = {}
      if filter_by_date
        begin
          start_date = prompt.ask("Enter start date (YYYY-MM-DD):") do |q|
            q.validate(/^\d{4}-\d{2}-\d{2}$/, "Must be in YYYY-MM-DD format")
          end
          filter_options[:start_date] = Date.parse(start_date)

          end_date = prompt.ask("Enter end date (YYYY-MM-DD):") do |q|
            q.validate(/^\d{4}-\d{2}-\d{2}$/, "Must be in YYYY-MM-DD format")
          end
          filter_options[:end_date] = Date.parse(end_date)
        rescue Date::Error => e
          error "Invalid date: #{e.message}"
          prompt.keypress("\nPress any key to continue...")
          return
        end
      end

      # Ask for symbol filter
      filter_by_symbol = prompt.yes?("Filter by symbol?")
      if filter_by_symbol
        symbol = prompt.ask("Enter symbol:") { |q| q.modify :up }.upcase
        filter_options[:symbol] = symbol
      end

      info "Fetching transaction history for account #{account.account_number}..."

      transactions = account.get_transactions(current_session, **filter_options)

      if transactions.empty?
        warning "No transactions found"
        prompt.keypress("\nPress any key to continue...")
        return
      end

      formatter = Tastytrade::HistoryFormatter.new(pastel: pastel)
      formatter.format_table(transactions, group_by: grouping)

      prompt.keypress("\nPress any key to continue...")
    rescue Tastytrade::Error => e
      error "Failed to fetch transaction history: #{e.message}"
      prompt.keypress("\nPress any key to continue...")
    rescue StandardError => e
      error "Unexpected error: #{e.message}"
      prompt.keypress("\nPress any key to continue...")
    end

    def interactive_order
      account = @current_account || current_account || select_account_interactively
      return unless account

      # Get order details
      symbol = prompt.ask("Enter symbol:") { |q| q.modify :up }.upcase
      quantity = prompt.ask("Enter quantity:", convert: :int) do |q|
        q.validate(/^\d+$/, "Must be a positive number")
      end

      # Create vim-enabled prompt for order type
      order_type_prompt = create_vim_prompt
      order_type = order_type_prompt.select("Select order type:", per_page: 2) do |menu|
        menu.enum "."
        menu.help "(Use ↑/↓ arrows, vim j/k, numbers 1-2, q or ESC to go back)"
        menu.choice "Market - Execute at current market price", "Market"
        menu.choice "Limit - Execute at specified price or better", "Limit"
      end

      return if @exit_requested

      price = nil
      if order_type == "Limit"
        price = prompt.ask("Enter limit price:", convert: :float) do |q|
          q.validate(/^\d+(\.\d+)?$/, "Must be a valid price")
        end
      end

      # Create vim-enabled prompt for action
      action_prompt = create_vim_prompt
      action = action_prompt.select("Select action:", per_page: 2) do |menu|
        menu.enum "."
        menu.help "(Use ↑/↓ arrows, vim j/k, numbers 1-2, q or ESC to go back)"
        menu.choice "Buy - Purchase shares", "Buy"
        menu.choice "Sell - Sell shares", "Sell"
      end

      return if @exit_requested

      # Show order summary
      puts "\nOrder Summary:"
      puts "  Symbol: #{symbol}"
      puts "  Quantity: #{quantity}"
      puts "  Type: #{order_type}"
      puts "  Price: #{price ? format_currency(price) : "Market"}" if order_type == "Limit"
      puts "  Action: #{action}"
      puts "  Account: #{account.account_number}"

      dry_run = prompt.yes?("\nRun as simulation (dry run)?")

      if prompt.yes?("\nPlace this order?")
        # Create the order
        order_action = action == "Buy" ? Tastytrade::OrderAction::BUY_TO_OPEN : Tastytrade::OrderAction::SELL_TO_CLOSE

        leg = Tastytrade::OrderLeg.new(
          action: order_action,
          symbol: symbol,
          quantity: quantity
        )

        order_type_constant = order_type == "Market" ? Tastytrade::OrderType::MARKET : Tastytrade::OrderType::LIMIT

        begin
          order = Tastytrade::Order.new(
            type: order_type_constant,
            legs: leg,
            price: price
          )

          info "Placing #{dry_run ? "simulated " : ""}order..."

          # First do a dry run to check buying power impact
          dry_run_response = account.place_order(current_session, order, dry_run: true)

          # Check buying power impact
          if dry_run_response.buying_power_effect.is_a?(Tastytrade::Models::BuyingPowerEffect)
            bp_effect = dry_run_response.buying_power_effect
            bp_usage = bp_effect.buying_power_usage_percentage

            if bp_usage > 80
              warning "This order will use #{bp_usage.to_s("F")}% of your buying power!"

              # Fetch current balance for more context
              balance = account.get_balances(current_session)
              puts ""
              puts "Current Buying Power Status:"
              puts "  Available Trading Funds: #{format_currency(balance.available_trading_funds)}"
              puts "  Equity Buying Power: #{format_currency(balance.equity_buying_power)}"
              puts "  Current BP Usage: #{balance.buying_power_usage_percentage.to_s("F")}%"
              puts ""

              unless dry_run
                unless prompt.yes?("Are you sure you want to proceed with this order?")
                  info "Order cancelled"
                  prompt.keypress("\nPress any key to continue...")
                  return
                end
              end
            end
          end

          # Place the actual order if not dry run
          response = if dry_run
            dry_run_response
          else
            account.place_order(current_session, order, dry_run: false)
          end

          success "#{dry_run ? "Dry run" : "Order placed"} successfully!"

          puts "\nOrder Details:"
          puts "  Order ID: #{response.order_id}" if response.order_id && !response.order_id.empty?
          puts "  Status: #{response.status}" if response.status && !response.status.empty?

          # Handle both BigDecimal and BuyingPowerEffect
          if response.buying_power_effect
            if response.buying_power_effect.is_a?(Tastytrade::Models::BuyingPowerEffect)
              bp_effect = response.buying_power_effect
              puts "  Buying Power Impact: #{format_currency(bp_effect.buying_power_change_amount)}"
              puts "  BP Usage: #{bp_effect.buying_power_usage_percentage.to_s("F")}%"
            else
              puts "  Buying Power Effect: #{format_currency(response.buying_power_effect)}"
            end
          end

          if response.warnings.any?
            warning "Warnings:"
            response.warnings.each { |w| puts "  - #{w}" }
          end
        rescue Tastytrade::Error => e
          error "Failed to place order: #{e.message}"
        rescue ArgumentError => e
          error e.message
        end
      else
        info "Order cancelled"
      end

      prompt.keypress("\nPress any key to continue...")
    rescue Interrupt
      nil
    rescue => e
      error "Failed to place order: #{e.message}"
      prompt.keypress("\nPress any key to continue...")
    end
  end
end

# Require after CLI class is defined to avoid module/class conflict
require_relative "cli/positions_formatter"
require_relative "cli/history_formatter"
