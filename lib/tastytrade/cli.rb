# frozen_string_literal: true

require "thor"
require "tty-table"
require "bigdecimal"
require_relative "cli_helpers"
require_relative "cli_config"
require_relative "session_manager"
require_relative "cli/orders"
require_relative "cli/options"

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
      if (session = Session.from_environment(is_test: options[:test]))
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

    desc "trading_status", "Display account trading status and permissions"
    option :account, type: :string, desc: "Account number (uses default if not specified)"
    def trading_status
      require_authentication!

      account = if options[:account]
        Tastytrade::Models::Account.get(current_session, options[:account])
      else
        current_account || select_account_interactively
      end

      return unless account

      trading_status = account.get_trading_status(current_session)
      display_trading_status(trading_status)
    rescue Tastytrade::Error => e
      error "Failed to fetch trading status: #{e.message}"
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

    desc "option", "Display option chain for a symbol"
    option :symbol, type: :string, required: true, desc: "Symbol to get option chain for"
    option :strikes, type: :numeric, desc: "Limit number of strikes around ATM"
    option :dte, type: :numeric, desc: "Max days to expiration"
    option :moneyness, type: :string, enum: %w[ITM ATM OTM ALL], desc: "Filter by moneyness"
    option :expiration_type, type: :string, enum: %w[weekly monthly quarterly all], desc: "Filter by expiration type"
    option :format, type: :string, enum: %w[table json compact], default: "table", desc: "Output format"
    option :nested, type: :boolean, default: false, desc: "Use nested chain format"
    # Display option chain with filtering and formatting options
    #
    # @example Display full option chain
    #   tastytrade option --symbol SPY
    #
    # @example Display 5 strikes around ATM for near-term expirations
    #   tastytrade option --symbol SPY --strikes 5 --dte 30
    #
    # @example Display only ITM options in JSON format
    #   tastytrade option --symbol SPY --moneyness ITM --format json
    #
    # @example Display only monthly expirations
    #   tastytrade option --symbol SPY --expiration-type monthly
    #
    # @return [void]
    def option
      require_authentication!

      symbol = options[:symbol].upcase
      info "Fetching option chain for #{symbol}..."

      begin
        # Get the option chain
        chain = if options[:nested]
          Tastytrade::Models::NestedOptionChain.get(current_session, symbol)
        else
          Tastytrade::Models::OptionChain.get_chain(current_session, symbol)
        end

        # Apply filters
        if options[:dte]
          chain = chain.filter_by_dte(max_dte: options[:dte])
        end

        if options[:strikes] && !options[:nested]
          # For compact chain, need to get current price
          # For now, we'll skip this filter for compact chains
          info "Note: --strikes filter requires current price (not implemented yet)"
        end

        if options[:expiration_type] && options[:expiration_type] != "all"
          case options[:expiration_type]
          when "weekly"
            chain = chain.weekly_expirations
          when "monthly"
            chain = chain.monthly_expirations
          when "quarterly"
            chain = chain.quarterly_expirations
          end
        end

        # Display based on format
        case options[:format]
        when "json"
          display_option_chain_json(chain)
        when "compact"
          display_option_chain_compact(chain)
        else
          display_option_chain_table(chain)
        end

      rescue Tastytrade::Error => e
        error "Failed to fetch option chain: #{e.message}"
        exit 1
      rescue StandardError => e
        error "Unexpected error: #{e.message}"
        exit 1
      end
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

    # Register the Orders subcommand
    desc "order SUBCOMMAND ...ARGS", "Manage orders"
    subcommand "order", CLI::Orders

    desc "option SUBCOMMAND ...ARGS", "Options trading commands"
    subcommand "option", CLI::Options

    desc "place SYMBOL QUANTITY", "Place an order for equities"
    option :type, default: "market", desc: "Order type (market or limit)"
    option :price, type: :numeric, desc: "Price for limit orders"
    option :action, default: "buy", desc: "Order action (buy or sell)"
    option :dry_run, type: :boolean, default: false, desc: "Simulate order without placing it"
    option :account, type: :string, desc: "Account number (uses default if not specified)"
    # Place an order for equities
    #
    # @example Place a market buy order
    #   tastytrade place AAPL 100
    #
    # @example Place a limit buy order
    #   tastytrade place AAPL 100 --type limit --price 150.50
    #
    # @example Place a sell order
    #   tastytrade place AAPL 100 --action sell
    #
    # @example Dry run an order
    #   tastytrade place AAPL 100 --dry-run
    #
    def place(symbol, quantity)
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
          interactive_orders_menu
        when :options
          interactive_options
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
        menu.choice "Orders - Manage orders", :orders
        menu.choice "Options - Browse option chains", :options
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

    # Interactive option chain browsing with menu-driven navigation
    #
    # Provides a complete interactive workflow for browsing option chains,
    # selecting expirations and strikes, and creating orders.
    #
    # @return [void]
    def interactive_options
      # Get symbol from user
      symbol = prompt.ask("Enter symbol for option chain:") do |q|
        q.modify :up
        q.required true
      end

      info "Fetching option chain for #{symbol}..."

      begin
        # Get the option chain
        chain = Tastytrade::Models::NestedOptionChain.get(current_session, symbol)

        if chain.expirations.empty?
          warning "No options available for #{symbol}"
          return
        end

        # Select expiration
        expiration = select_expiration_interactively(chain)
        return unless expiration

        # Select strike
        strike = select_strike_interactively(expiration)
        return unless strike

        # Select call or put
        option_type = prompt.select("Select option type:", ["Call", "Put", "Back"])
        return if option_type == "Back"

        # Get the selected option symbol
        selected_symbol = option_type == "Call" ? strike.call : strike.put

        # Show option details and actions
        show_option_details_menu(selected_symbol, strike, expiration, option_type)

      rescue Tastytrade::Error => e
        error "Failed to fetch option chain: #{e.message}"
      end
    end

    # Select an expiration date from available options
    #
    # @param chain [Tastytrade::Models::NestedOptionChain] The option chain to select from
    # @return [Tastytrade::Models::NestedOptionChain::Expiration, nil] Selected expiration or nil if cancelled
    def select_expiration_interactively(chain)
      choices = chain.expirations.map do |exp|
        desc = "#{exp.expiration_date} (#{exp.days_to_expiration} DTE) - #{exp.expiration_type}"
        { name: desc, value: exp }
      end

      choices << { name: "Back to main menu", value: :back }

      result = prompt.select("Select expiration:", choices, per_page: 15)
      return nil if result == :back
      result
    end

    # Select a strike price from available options for an expiration
    #
    # @param expiration [Tastytrade::Models::NestedOptionChain::Expiration] The expiration to select strikes from
    # @return [Tastytrade::Models::NestedOptionChain::Strike, nil] Selected strike or nil if cancelled
    def select_strike_interactively(expiration)
      # Group strikes around ATM for easier selection
      strikes = expiration.strikes

      # Sort by strike price
      strikes_sorted = strikes.sort_by { |s| s.strike_price.to_f }

      # Create choices with both call and put info
      choices = strikes_sorted.map do |strike|
        strike_str = format_price(strike.strike_price)
        desc = "Strike #{strike_str} | Call: #{strike.call || "N/A"} | Put: #{strike.put || "N/A"}"
        { name: desc, value: strike }
      end

      choices << { name: "Back to expirations", value: :back }

      result = prompt.select("Select strike:", choices, per_page: 20)
      return nil if result == :back
      result
    end

    # Display option details and action menu
    #
    # Shows option contract details and provides actions like creating buy/sell orders.
    #
    # @param symbol [String] The option symbol
    # @param strike [Tastytrade::Models::NestedOptionChain::Strike] The selected strike
    # @param expiration [Tastytrade::Models::NestedOptionChain::Expiration] The selected expiration
    # @param option_type [String] Either "Call" or "Put"
    # @return [void]
    def show_option_details_menu(symbol, strike, expiration, option_type)
      loop do
        puts
        puts pastel.bold("Option Details")
        puts "Symbol: #{symbol}"
        puts "Type: #{option_type}"
        puts "Strike: #{format_price(strike.strike_price)}"
        puts "Expiration: #{expiration.expiration_date} (#{expiration.days_to_expiration} DTE)"
        puts "Settlement: #{expiration.settlement_type}"
        puts

        choice = prompt.select("What would you like to do?") do |menu|
          menu.choice "Create Buy Order", :buy
          menu.choice "Create Sell Order", :sell
          menu.choice "View current quotes (not implemented)", :quotes
          menu.choice "Add to watchlist (not implemented)", :watchlist
          menu.choice "Back to strikes", :back
        end

        case choice
        when :buy
          create_option_order(symbol, "Buy", option_type)
        when :sell
          create_option_order(symbol, "Sell", option_type)
        when :quotes
          info "Quote viewing not yet implemented"
        when :watchlist
          info "Watchlist feature not yet implemented"
        when :back
          break
        end
      end
    end

    # Create an option order interactively
    #
    # Prompts for order details and submits the order (placeholder implementation).
    #
    # @param symbol [String] The option symbol
    # @param action [String] Either "Buy" or "Sell"
    # @param option_type [String] Either "Call" or "Put"
    # @return [void]
    def create_option_order(symbol, action, option_type)
      account = @current_account || current_account || select_account_interactively
      return unless account

      # Get quantity
      quantity = prompt.ask("Enter number of contracts:", convert: :int) do |q|
        q.validate { |v| v.to_i > 0 }
        q.messages[:valid?] = "Quantity must be greater than 0"
      end

      # Get order type
      order_type = prompt.select("Select order type:", ["Market", "Limit", "Cancel"])
      return if order_type == "Cancel"

      price = nil
      if order_type == "Limit"
        price = prompt.ask("Enter limit price per contract:", convert: :float) do |q|
          q.validate { |v| v.to_f > 0 }
          q.messages[:valid?] = "Price must be greater than 0"
        end
      end

      # Build order description
      order_desc = "#{action} #{quantity} #{symbol} #{option_type} contract(s)"
      order_desc += " at $#{sprintf("%.2f", price)}" if price

      # Confirm order
      environment = current_session.instance_variable_get(:@is_test) ? "SANDBOX" : "PRODUCTION"
      confirm_msg = "Submit this order? (#{environment})\n#{order_desc}"

      if prompt.yes?(pastel.yellow(confirm_msg))
        info "Order submission not yet fully implemented"
        info "Would submit: #{order_desc}"
        # TODO: Implement actual order submission when Order model supports options
      end
    end

    def interactive_orders_menu
      loop do
        menu_prompt = create_vim_prompt

        choice = menu_prompt.select("Orders Menu", per_page: 10) do |menu|
          menu.enum "."
          menu.help "(Use ↑/↓ arrows, vim j/k, numbers, q or ESC to go back)"

          menu.choice "List Orders - View live orders", :list
          menu.choice "Order History - View past orders", :history
          menu.choice "Place Order - Create new order", :place
          menu.choice "Get Order - View order details", :get
          menu.choice "Cancel Order - Cancel an order", :cancel
          menu.choice "Replace Order - Modify existing order", :replace
          menu.choice "Back to Main Menu", :back
        end

        return if @exit_requested || choice == :back

        case choice
        when :list
          interactive_list_orders
        when :history
          interactive_order_history
        when :place
          interactive_place_order_advanced
        when :get
          interactive_get_order
        when :cancel
          interactive_cancel_order
        when :replace
          interactive_replace_order
        end
      end
    end

    def with_error_handling(&block)
      block.call
    rescue SystemExit => e
      # Catch Thor's exit calls
      nil
    rescue Tastytrade::InvalidCredentialsError => e
      show_error("Authentication failed", "Your session has expired. Please login again.")
    rescue Tastytrade::OrderAlreadyFilledError => e
      show_error("Order already filled", "This order has already been executed and cannot be modified.")
    rescue Tastytrade::InsufficientFundsError => e
      show_error("Insufficient funds", "You don't have enough buying power for this order.")
    rescue Tastytrade::MarketClosedError => e
      show_error("Market closed", "Orders cannot be placed while the market is closed.")
    rescue Tastytrade::NetworkTimeoutError => e
      show_error("Network timeout", "Connection timed out. Please check your internet and try again.")
    rescue Tastytrade::Error => e
      show_error("Operation failed", e.message)
    rescue StandardError => e
      show_error("Unexpected error", "An unexpected error occurred: #{e.message}")
    ensure
      prompt.keypress("\nPress any key to continue...", timeout: 30)
    end

    def show_error(title, message)
      puts ""
      puts pastel.red.bold("✗ #{title}")
      puts pastel.red("  #{message}")
      puts ""
    end

    def interactive_list_orders
      account = @current_account || current_account || select_account_interactively
      return unless account

      filter_prompt = create_vim_prompt
      filter = filter_prompt.select("Filter orders by:", per_page: 5) do |menu|
        menu.enum "."
        menu.help "(Select filter or press q/ESC to skip)"
        menu.choice "All orders", :all
        menu.choice "By status", :status
        menu.choice "By symbol", :symbol
      end

      return if @exit_requested

      options = { account: account.account_number }

      case filter
      when :status
        status_options = ["Live", "Filled", "Cancelled", "Expired"]
        status = prompt.select("Select status:", status_options)
        options[:status] = status
      when :symbol
        symbol = prompt.ask("Enter symbol:") { |q| q.modify :up }.upcase
        options[:symbol] = symbol
      end

      orders_command = Tastytrade::CLI::Orders.new
      orders_command.instance_variable_set(:@current_session, current_session)
      orders_command.options = options

      with_error_handling do
        orders_command.list
      end

      # Auto-refresh option
      if prompt.yes?("Auto-refresh orders? (updates every 5 seconds)")
        loop do
          sleep(5)
          system("clear")
          orders_command.list
          break if prompt.keypress("Press any key to stop auto-refresh...", timeout: 0.1)
        end
      end
    end

    def interactive_order_history
      account = @current_account || current_account || select_account_interactively
      return unless account

      # Date range filter
      filter_by_date = prompt.yes?("Filter by date range?")

      options = { account: account.account_number }

      if filter_by_date
        begin
          from_date = prompt.ask("Enter start date (YYYY-MM-DD):") do |q|
            q.validate(/^\d{4}-\d{2}-\d{2}$/, "Must be in YYYY-MM-DD format")
          end
          options[:from] = from_date

          to_date = prompt.ask("Enter end date (YYYY-MM-DD):") do |q|
            q.validate(/^\d{4}-\d{2}-\d{2}$/, "Must be in YYYY-MM-DD format")
          end
          options[:to] = to_date
        rescue Date::Error => e
          error "Invalid date: #{e.message}"
          prompt.keypress("\nPress any key to continue...")
          return
        end
      end

      # Symbol filter
      filter_by_symbol = prompt.yes?("Filter by symbol?")
      if filter_by_symbol
        symbol = prompt.ask("Enter symbol:") { |q| q.modify :up }.upcase
        options[:symbol] = symbol
      end

      # Status filter
      filter_by_status = prompt.yes?("Filter by status?")
      if filter_by_status
        status_options = ["Filled", "Cancelled", "Expired", "Rejected"]
        status = prompt.select("Select status:", status_options)
        options[:status] = status
      end

      orders_command = Tastytrade::CLI::Orders.new
      orders_command.instance_variable_set(:@current_session, current_session)
      orders_command.options = options

      with_error_handling do
        orders_command.history
      end
    end

    def interactive_place_order_advanced
      menu_prompt = create_vim_prompt

      order_mode = menu_prompt.select("Order Entry Mode:", per_page: 5) do |menu|
        menu.enum "."
        menu.help "(Select order complexity level)"
        menu.choice "Quick Order - Basic market/limit orders", :quick
        menu.choice "Standard Order - Common order types (equity & options)", :standard
        menu.choice "Option Strategies - Multi-leg option strategies", :strategies
        menu.choice "Advanced Order - All order types and conditions", :advanced
        menu.choice "Back", :back
      end

      return if @exit_requested || order_mode == :back

      case order_mode
      when :quick
        interactive_place_order_quick
      when :standard
        interactive_place_order_standard
      when :strategies
        interactive_option_strategies
      when :advanced
        interactive_place_order_full
      end
    end

    def interactive_place_order_quick
      puts pastel.cyan.bold("\n📝 Quick Order Entry\n")

      symbol = prompt.ask("Symbol:") { |q| q.modify :up }.upcase
      action = prompt.select("Action:") do |menu|
        menu.choice "Buy", "buy_to_open"
        menu.choice "Sell", "sell_to_close"
      end
      quantity = prompt.ask("Quantity:", convert: :int)
      order_type = prompt.select("Order type:") do |menu|
        menu.choice "Market (immediate execution)", "market"
        menu.choice "Limit (set your price)", "limit"
      end

      price = nil
      if order_type == "limit"
        price = prompt.ask("Limit price:", convert: :float)
      end

      account = @current_account || current_account || select_account_interactively
      return unless account

      # Delegate to Thor command
      orders_command = Tastytrade::CLI::Orders.new
      orders_command.instance_variable_set(:@current_session, current_session)
      orders_command.instance_variable_set(:@current_account, account)
      orders_command.options = {
        account: account.account_number,
        symbol: symbol,
        action: action,
        quantity: quantity,
        type: order_type,
        price: price,
        time_in_force: "day"
      }

      with_error_handling do
        orders_command.place
      end
    end

    def interactive_place_order_standard
      puts pastel.cyan.bold("\n📊 Standard Order Entry\n")

      symbol = prompt.ask("Symbol:") { |q| q.modify :up }.upcase

      # Auto-detect if this is an option symbol (OCC format)
      is_option = symbol.match?(/\A[A-Z0-9]+\s\d{6}[CP]\d{8}\z/)

      if is_option
        puts pastel.yellow("Option symbol detected: #{symbol}")
        quantity_label = "Number of contracts:"
      else
        quantity_label = "Quantity:"
      end

      action = prompt.select("Action:") do |menu|
        menu.choice "Buy to Open", "buy_to_open"
        menu.choice "Sell to Close", "sell_to_close"
        menu.choice "Sell to Open (Short)", "sell_to_open"
        menu.choice "Buy to Close (Cover)", "buy_to_close"
      end

      quantity = prompt.ask(quantity_label, convert: :int)

      order_type = prompt.select("Order type:") do |menu|
        menu.choice "Market", "market"
        menu.choice "Limit", "limit"
        menu.choice "Stop", "stop" unless is_option  # Options typically don't support stop orders
      end

      price = nil
      if order_type == "limit"
        price_label = is_option ? "Limit price per contract:" : "Limit price:"
        price = prompt.ask(price_label, convert: :float)
      elsif order_type == "stop"
        price = prompt.ask("Stop price:", convert: :float)
      end

      time_in_force = prompt.select("Time in force:") do |menu|
        menu.choice "Day (expires at close)", "day"
        menu.choice "GTC (good till cancelled)", "gtc"
      end

      account = @current_account || current_account || select_account_interactively
      return unless account

      # Confirmation
      puts "\nOrder Summary:"
      puts "  Symbol: #{symbol}"
      puts "  Type: #{is_option ? pastel.green("Option") : "Equity"}"
      puts "  Action: #{action}"
      puts "  #{is_option ? "Contracts" : "Quantity"}: #{quantity}"
      puts "  Order Type: #{order_type}"
      puts "  Price: #{price ? format_currency(price) : "Market"}"
      puts "  Time in Force: #{time_in_force.upcase}"
      puts "  Account: #{account.account_number}"

      if is_option && price
        total_premium = price * quantity * 100  # 100 shares per contract
        puts "  Total Premium: #{format_currency(total_premium)}"
      end

      unless prompt.yes?("\nPlace this order?")
        info "Order cancelled"
        return
      end

      orders_command = Tastytrade::CLI::Orders.new
      orders_command.instance_variable_set(:@current_session, current_session)
      orders_command.instance_variable_set(:@current_account, account)
      orders_command.options = {
        account: account.account_number,
        symbol: symbol,
        action: action,
        quantity: quantity,
        type: order_type,
        price: price,
        time_in_force: time_in_force,
        instrument_type: is_option ? "Option" : nil,  # Let CLI::Orders detect automatically if nil
        skip_confirmation: true
      }

      with_error_handling do
        orders_command.place
      end
    end

    def interactive_place_order_full
      info "Advanced order placement with all options"

      # Reuse the existing interactive_order method for now
      # This will be enhanced later with more advanced features
      interactive_order
    end

    def interactive_option_strategies
      puts pastel.cyan.bold("\n🎯 Option Strategy Builder\n")

      account = @current_account || current_account || select_account_interactively
      return unless account

      strategy = prompt.select("Select strategy:") do |menu|
        menu.choice "Vertical Spread (Bull/Bear Call/Put)", :vertical
        menu.choice "Iron Condor", :iron_condor
        menu.choice "Strangle", :strangle
        menu.choice "Straddle", :straddle
        menu.choice "Back", :back
      end

      return if strategy == :back

      case strategy
      when :vertical
        interactive_vertical_spread(account)
      when :iron_condor
        interactive_iron_condor(account)
      when :strangle
        interactive_strangle(account)
      when :straddle
        interactive_straddle(account)
      end
    end

    def interactive_vertical_spread(account)
      puts pastel.green("\n📈 Vertical Spread Setup\n")

      underlying = prompt.ask("Underlying symbol:") { |q| q.modify :up }.upcase

      spread_type = prompt.select("Spread type:") do |menu|
        menu.choice "Bull Call Spread (bullish)", :bull_call
        menu.choice "Bear Call Spread (bearish)", :bear_call
        menu.choice "Bull Put Spread (bullish)", :bull_put
        menu.choice "Bear Put Spread (bearish)", :bear_put
      end

      # For demo purposes, we'll need the user to enter the specific option symbols
      puts "\nEnter the two option symbols for your spread:"
      puts pastel.dim("Example: SPY 240119C00450000")

      long_symbol = prompt.ask("Long option symbol:") { |q| q.modify :up }.upcase
      short_symbol = prompt.ask("Short option symbol:") { |q| q.modify :up }.upcase

      quantity = prompt.ask("Number of spreads:", convert: :int) do |q|
        q.validate { |v| v.to_i > 0 }
      end

      price = prompt.ask("Net debit/credit per spread (use negative for credit):", convert: :float)

      # Show summary
      puts "\n#{pastel.bold("Spread Summary:")}"
      puts "  Strategy: #{spread_type.to_s.split("_").map(&:capitalize).join(" ")}"
      puts "  Underlying: #{underlying}"
      puts "  Long: #{long_symbol}"
      puts "  Short: #{short_symbol}"
      puts "  Quantity: #{quantity} spread(s)"
      puts "  Net #{price >= 0 ? "Debit" : "Credit"}: #{format_currency(price.abs)}"
      puts "  Total Premium: #{format_currency(price.abs * quantity * 100)}"

      if prompt.yes?("\nPlace this spread order?")
        orders_command = Tastytrade::CLI::Orders.new
        orders_command.instance_variable_set(:@current_session, current_session)
        orders_command.instance_variable_set(:@current_account, account)
        orders_command.options = {
          account: account.account_number,
          strategy: "vertical",
          legs: "#{long_symbol},#{short_symbol}",
          quantity: quantity,
          price: price,
          skip_confirmation: true
        }

        with_error_handling do
          orders_command.option_spread
        end
      else
        info "Spread order cancelled"
      end

      prompt.keypress("\nPress any key to continue...")
    end

    def interactive_iron_condor(account)
      puts pastel.green("\n🦅 Iron Condor Setup\n")

      underlying = prompt.ask("Underlying symbol:") { |q| q.modify :up }.upcase

      puts "\nEnter the four option symbols for your iron condor:"
      puts pastel.dim("Order: Short Put, Long Put, Short Call, Long Call")
      puts pastel.dim("Example: SPY 240119P00440000")

      put_short = prompt.ask("Short put symbol:") { |q| q.modify :up }.upcase
      put_long = prompt.ask("Long put symbol (lower strike):") { |q| q.modify :up }.upcase
      call_short = prompt.ask("Short call symbol:") { |q| q.modify :up }.upcase
      call_long = prompt.ask("Long call symbol (higher strike):") { |q| q.modify :up }.upcase

      quantity = prompt.ask("Number of iron condors:", convert: :int) do |q|
        q.validate { |v| v.to_i > 0 }
      end

      price = prompt.ask("Net credit per iron condor:", convert: :float) do |q|
        q.validate { |v| v.to_f > 0 }
      end

      # Show summary
      puts "\n#{pastel.bold("Iron Condor Summary:")}"
      puts "  Underlying: #{underlying}"
      puts "  Put Side:"
      puts "    Short: #{put_short}"
      puts "    Long: #{put_long}"
      puts "  Call Side:"
      puts "    Short: #{call_short}"
      puts "    Long: #{call_long}"
      puts "  Quantity: #{quantity} iron condor(s)"
      puts "  Net Credit: #{format_currency(price)}"
      puts "  Total Credit: #{format_currency(price * quantity * 100)}"

      # Calculate max loss (width of wider spread - credit)
      # This is simplified - actual calculation would need strike prices
      puts pastel.dim("  Max Risk: Width of widest spread - credit received")

      if prompt.yes?("\nPlace this iron condor order?")
        orders_command = Tastytrade::CLI::Orders.new
        orders_command.instance_variable_set(:@current_session, current_session)
        orders_command.instance_variable_set(:@current_account, account)
        orders_command.options = {
          account: account.account_number,
          strategy: "iron_condor",
          legs: "#{put_short},#{put_long},#{call_short},#{call_long}",
          quantity: quantity,
          price: price,
          skip_confirmation: true
        }

        with_error_handling do
          orders_command.option_spread
        end
      else
        info "Iron condor order cancelled"
      end

      prompt.keypress("\nPress any key to continue...")
    end

    def interactive_strangle(account)
      puts pastel.green("\n🔄 Strangle Setup\n")

      underlying = prompt.ask("Underlying symbol:") { |q| q.modify :up }.upcase

      action = prompt.select("Strangle direction:") do |menu|
        menu.choice "Long Strangle (buy both)", :long
        menu.choice "Short Strangle (sell both)", :short
      end

      puts "\nEnter the option symbols for your strangle:"
      puts pastel.dim("Use different strikes for put and call")

      put_symbol = prompt.ask("Put option symbol:") { |q| q.modify :up }.upcase
      call_symbol = prompt.ask("Call option symbol:") { |q| q.modify :up }.upcase

      quantity = prompt.ask("Number of strangles:", convert: :int) do |q|
        q.validate { |v| v.to_i > 0 }
      end

      price_label = action == :long ? "Total debit per strangle:" : "Total credit per strangle:"
      price = prompt.ask(price_label, convert: :float) do |q|
        q.validate { |v| v.to_f > 0 }
      end

      # Show summary
      puts "\n#{pastel.bold("Strangle Summary:")}"
      puts "  Type: #{action == :long ? "Long" : "Short"} Strangle"
      puts "  Underlying: #{underlying}"
      puts "  Put: #{put_symbol}"
      puts "  Call: #{call_symbol}"
      puts "  Quantity: #{quantity} strangle(s)"
      puts "  Net #{action == :long ? "Debit" : "Credit"}: #{format_currency(price)}"
      puts "  Total Premium: #{format_currency(price * quantity * 100)}"

      if prompt.yes?("\nPlace this strangle order?")
        orders_command = Tastytrade::CLI::Orders.new
        orders_command.instance_variable_set(:@current_session, current_session)
        orders_command.instance_variable_set(:@current_account, account)
        orders_command.options = {
          account: account.account_number,
          strategy: "strangle",
          legs: "#{put_symbol},#{call_symbol}",
          quantity: quantity,
          price: price,
          action: action == :long ? "buy" : "sell",
          skip_confirmation: true
        }

        with_error_handling do
          orders_command.option_spread
        end
      else
        info "Strangle order cancelled"
      end

      prompt.keypress("\nPress any key to continue...")
    end

    def interactive_straddle(account)
      puts pastel.green("\n⚖️ Straddle Setup\n")

      underlying = prompt.ask("Underlying symbol:") { |q| q.modify :up }.upcase

      action = prompt.select("Straddle direction:") do |menu|
        menu.choice "Long Straddle (buy both)", :long
        menu.choice "Short Straddle (sell both)", :short
      end

      puts "\nEnter strike and expiration for your straddle:"

      strike = prompt.ask("Strike price:", convert: :float) do |q|
        q.validate { |v| v.to_f > 0 }
      end

      expiration = prompt.ask("Expiration date (YYMMDD):") do |q|
        q.validate(/^\d{6}$/, "Must be in YYMMDD format")
      end

      quantity = prompt.ask("Number of straddles:", convert: :int) do |q|
        q.validate { |v| v.to_i > 0 }
      end

      price_label = action == :long ? "Total debit per straddle:" : "Total credit per straddle:"
      price = prompt.ask(price_label, convert: :float) do |q|
        q.validate { |v| v.to_f > 0 }
      end

      # Show summary
      puts "\n#{pastel.bold("Straddle Summary:")}"
      puts "  Type: #{action == :long ? "Long" : "Short"} Straddle"
      puts "  Underlying: #{underlying}"
      puts "  Strike: #{format_currency(strike)}"
      puts "  Expiration: #{expiration}"
      puts "  Quantity: #{quantity} straddle(s)"
      puts "  Net #{action == :long ? "Debit" : "Credit"}: #{format_currency(price)}"
      puts "  Total Premium: #{format_currency(price * quantity * 100)}"

      if prompt.yes?("\nPlace this straddle order?")
        orders_command = Tastytrade::CLI::Orders.new
        orders_command.instance_variable_set(:@current_session, current_session)
        orders_command.instance_variable_set(:@current_account, account)
        orders_command.options = {
          account: account.account_number,
          strategy: "straddle",
          underlying: underlying,
          strike: strike,
          expiration: expiration,
          quantity: quantity,
          price: price,
          action: action == :long ? "buy" : "sell",
          skip_confirmation: true
        }

        with_error_handling do
          orders_command.option_spread
        end
      else
        info "Straddle order cancelled"
      end

      prompt.keypress("\nPress any key to continue...")
    end

    def interactive_get_order
      account = @current_account || current_account || select_account_interactively
      return unless account

      order_id = prompt.ask("Enter Order ID:")

      orders_command = Tastytrade::CLI::Orders.new
      orders_command.instance_variable_set(:@current_session, current_session)
      orders_command.options = { account: account.account_number }

      with_error_handling do
        orders_command.get(order_id)
      end
    end

    def interactive_cancel_order
      account = @current_account || current_account || select_account_interactively
      return unless account

      info "Fetching cancellable orders..."
      orders = account.get_live_orders(current_session).select(&:cancellable?)

      if orders.empty?
        warning "No cancellable orders found"
        return
      end

      choices = orders.map do |order|
        leg = order.legs.first
        description = [
          order.underlying_symbol,
          leg&.action,
          "#{leg&.quantity} shares",
          format_currency(order.price),
          colorize_status(order.status)
        ].compact.join(" | ")

        { name: "#{order.id[0..7]}... - #{description}", value: order.id }
      end

      order_id = prompt.select("Select order to cancel:", choices)

      # Context-aware confirmation
      confirm_message = if current_session.instance_variable_get(:@is_test)
        "Cancel this order? (SANDBOX)"
      else
        pastel.red("Cancel this order? (PRODUCTION - This action cannot be undone)")
      end

      return unless prompt.yes?(confirm_message)

      orders_command = Tastytrade::CLI::Orders.new
      orders_command.instance_variable_set(:@current_session, current_session)
      orders_command.options = { account: account.account_number }

      with_error_handling do
        orders_command.cancel(order_id)
      end
    end

    def interactive_replace_order
      account = @current_account || current_account || select_account_interactively
      return unless account

      info "Fetching editable orders..."
      orders = account.get_live_orders(current_session).select(&:editable?)

      if orders.empty?
        warning "No editable orders found"
        return
      end

      choices = orders.map do |order|
        leg = order.legs.first
        description = [
          order.underlying_symbol,
          leg&.action,
          "#{leg&.quantity} shares",
          format_currency(order.price),
          colorize_status(order.status)
        ].compact.join(" | ")

        { name: "#{order.id[0..7]}... - #{description}", value: order.id }
      end

      order_id = prompt.select("Select order to replace:", choices)

      orders_command = Tastytrade::CLI::Orders.new
      orders_command.instance_variable_set(:@current_session, current_session)
      orders_command.options = { account: account.account_number }

      with_error_handling do
        orders_command.replace(order_id)
      end
    end

    def colorize_status(status)
      case status
      when "Live"
        pastel.green(status)
      when "Filled"
        pastel.blue(status)
      when "Cancelled", "Rejected", "Expired"
        pastel.red(status)
      when "Received", "Routed"
        pastel.yellow(status)
      else
        status
      end
    end

    # Display option chain in table format
    #
    # Shows expirations and strike counts in a formatted table.
    #
    # @param chain [Tastytrade::Models::OptionChain, Tastytrade::Models::NestedOptionChain] The chain to display
    # @return [void]
    def display_option_chain_table(chain)
      if chain.is_a?(Tastytrade::Models::NestedOptionChain)
        display_nested_option_chain_table(chain)
      else
        display_compact_option_chain_table(chain)
      end
    end

    def display_compact_option_chain_table(chain)
      puts "\n#{pastel.bold("Option Chain for #{chain.underlying_symbol}")}"
      puts "Chain Type: #{chain.option_chain_type}"
      puts "Total Expirations: #{chain.expiration_dates.size}"
      puts

      chain.expiration_dates.each do |exp_date|
        options = chain.options_for_expiration(exp_date)
        next if options.empty?

        puts pastel.cyan("Expiration: #{exp_date}")

        # Group by strike
        strikes = {}
        options.each do |opt|
          strikes[opt.strike_price] ||= {}
          strikes[opt.strike_price][opt.option_type.downcase.to_sym] = opt
        end

        # Create table
        headers = ["Strike", "Call", "Put"]
        rows = strikes.sort.map do |strike, opts|
          [
            format_price(strike),
            opts[:call]&.symbol || "-",
            opts[:put]&.symbol || "-"
          ]
        end

        table = TTY::Table.new(headers, rows)
        puts table.render(:unicode, padding: [0, 1])
        puts
      end
    end

    def display_nested_option_chain_table(chain)
      puts "\n#{pastel.bold("Option Chain for #{chain.underlying_symbol}")}"
      puts "Chain Type: #{chain.option_chain_type}"
      puts "Total Expirations: #{chain.expirations.size}"
      puts

      chain.expirations.each do |expiration|
        puts pastel.cyan("Expiration: #{expiration.expiration_date} (#{expiration.days_to_expiration} DTE)")
        puts "Type: #{expiration.expiration_type}, Settlement: #{expiration.settlement_type}"

        headers = ["Strike", "Call", "Call Streamer", "Put", "Put Streamer"]
        rows = expiration.strikes.map do |strike|
          [
            format_price(strike.strike_price),
            strike.call || "-",
            strike.call_streamer_symbol || "-",
            strike.put || "-",
            strike.put_streamer_symbol || "-"
          ]
        end

        # Limit display if too many strikes
        if rows.size > 20
          mid = rows.size / 2
          display_rows = rows[mid - 10..mid + 9] || rows
          puts "Showing strikes around ATM (20 of #{rows.size} total)"
        else
          display_rows = rows
        end

        table = TTY::Table.new(headers, display_rows)
        puts table.render(:unicode, padding: [0, 1])
        puts
      end
    end

    # Display option chain in JSON format
    #
    # Outputs the chain data as formatted JSON.
    #
    # @param chain [Tastytrade::Models::OptionChain, Tastytrade::Models::NestedOptionChain] The chain to display
    # @return [void]
    def display_option_chain_json(chain)
      require "json"

      if chain.is_a?(Tastytrade::Models::NestedOptionChain)
        data = {
          underlying_symbol: chain.underlying_symbol,
          root_symbol: chain.root_symbol,
          option_chain_type: chain.option_chain_type,
          shares_per_contract: chain.shares_per_contract,
          expirations: chain.expirations.map do |exp|
            {
              expiration_date: exp.expiration_date,
              days_to_expiration: exp.days_to_expiration,
              expiration_type: exp.expiration_type,
              settlement_type: exp.settlement_type,
              strikes: exp.strikes.map do |strike|
                {
                  strike_price: strike.strike_price.to_f,
                  call: strike.call,
                  put: strike.put,
                  call_streamer: strike.call_streamer_symbol,
                  put_streamer: strike.put_streamer_symbol
                }
              end
            }
          end
        }
      else
        data = {
          underlying_symbol: chain.underlying_symbol,
          root_symbol: chain.root_symbol,
          option_chain_type: chain.option_chain_type,
          shares_per_contract: chain.shares_per_contract,
          expirations: chain.expiration_dates.map do |exp_date|
            {
              expiration_date: exp_date.to_s,
              options: chain.options_for_expiration(exp_date).map do |opt|
                {
                  symbol: opt.symbol,
                  option_type: opt.option_type,
                  strike_price: opt.strike_price.to_f,
                  expiration_date: opt.expiration_date.to_s
                }
              end
            }
          end
        }
      end

      puts JSON.pretty_generate(data)
    end

    # Display option chain in compact format
    #
    # Shows a condensed view with expiration summary and option counts.
    #
    # @param chain [Tastytrade::Models::OptionChain, Tastytrade::Models::NestedOptionChain] The chain to display
    # @return [void]
    def display_option_chain_compact(chain)
      puts "\n#{pastel.bold("Option Chain for #{chain.underlying_symbol}")}"

      if chain.is_a?(Tastytrade::Models::NestedOptionChain)
        chain.expirations.each do |exp|
          puts "#{exp.expiration_date}: #{exp.strikes.size} strikes"
        end
      else
        chain.expiration_dates.each do |exp_date|
          options = chain.options_for_expiration(exp_date)
          puts "#{exp_date}: #{options.size} options"
        end
      end
    end

    def format_price(value)
      return "-" if value.nil?
      value.respond_to?(:to_f) ? sprintf("%.2f", value.to_f) : value.to_s
    end
  end
end

# Require after CLI class is defined to avoid module/class conflict
require_relative "cli/positions_formatter"
require_relative "cli/history_formatter"
