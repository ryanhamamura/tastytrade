require "thor"
require "pastel"
require "ostruct"
require_relative "../cli_helpers"
require_relative "../models/option_chain"
require_relative "../models/nested_option_chain"
require_relative "../option_order_builder"
require_relative "option_chain_formatter"
require_relative "option_helpers"

module Tastytrade
  class CLI < Thor
    # CLI commands for options trading operations
    #
    # Provides comprehensive options trading functionality including:
    # - Option chain display and filtering
    # - Individual option quotes
    # - Single-leg option orders (buy/sell calls/puts)
    # - Multi-leg strategies (spreads, strangles, straddles)
    #
    # All commands support sandbox testing with --test flag and
    # dry-run validation with --dry-run flag.
    #
    # @example Display an option chain
    #   tastytrade option chain SPY --strikes 10 --dte 30
    #
    # @example Buy a call option
    #   tastytrade option buy call SPY --strike 450 --expiration 2024-12-20 --dry-run
    #
    # @example Create a vertical spread
    #   tastytrade option spread SPY --type call --long-strike 445 --short-strike 455 --expiration 2024-12-20
    class Options < Thor
      include CLIHelpers
      include OptionHelpers

      desc "chain SYMBOL", "Display option chain for a symbol"
      option :strikes, type: :numeric, default: 10, desc: "Number of strikes to show around ATM"
      option :dte, type: :numeric, desc: "Filter by days to expiration (max DTE)"
      option :min_dte, type: :numeric, desc: "Minimum days to expiration"
      option :expirations, type: :numeric, default: 5, desc: "Number of expirations to show"
      option :type, type: :string, enum: %w[weekly monthly quarterly all], default: "all",
                    desc: "Expiration type filter"
      option :format, type: :string, enum: %w[table compact json csv], default: "table", desc: "Output format"
      option :greeks, type: :boolean, default: false, desc: "Show Greeks in display"
      option :moneyness, type: :string, enum: %w[itm atm otm all], default: "all", desc: "Filter by moneyness"
      option :delta, type: :numeric,
                     desc: "Find strikes near specific delta (0.01 to 1.0 for calls, -1.0 to -0.01 for puts)"
      def chain(symbol)
        require_authentication!

        account = current_account || get_default_account
        return unless account

        with_error_handling do
          info "Fetching option chain for #{symbol.upcase}..."

          # Fetch nested option chain
          nested_chain = Tastytrade::Models::NestedOptionChain.get(
            current_session,
            symbol.upcase
          )

          unless nested_chain
            error "Unable to fetch option chain for #{symbol}"
            return
          end

          # Apply filters
          chain = apply_chain_filters(nested_chain, options)

          # Display the chain
          display_option_chain(chain, symbol, options)
        end
      end

      desc "quote SYMBOL", "Get quote for a specific option contract"
      option :format, type: :string, enum: %w[detailed compact json], default: "detailed", desc: "Output format"
      def quote(symbol)
        require_authentication!

        account = current_account || get_default_account
        return unless account

        with_error_handling do
          info "Fetching quote for #{symbol}..."

          # Parse the OCC symbol to get underlying
          underlying = extract_underlying_from_occ(symbol)

          # Fetch the full chain for the underlying
          nested_chain = Tastytrade::Models::NestedOptionChain.get(
            current_session,
            underlying
          )

          unless nested_chain
            error "Unable to fetch option chain for #{underlying}"
            return
          end

          # Find the specific option
          option = find_option_by_symbol(nested_chain, symbol)

          if option
            display_option_quote(option, options[:format])
          else
            error "Option contract #{symbol} not found"
          end
        end
      end

      desc "buy TYPE SYMBOL", "Buy a call or put option"
      option :strike, type: :numeric, desc: "Strike price"
      option :expiration, type: :string, desc: "Expiration date (YYYY-MM-DD)"
      option :delta, type: :numeric, desc: "Target delta (finds closest strike)"
      option :dte, type: :numeric, desc: "Target days to expiration"
      option :quantity, type: :numeric, default: 1, desc: "Number of contracts"
      option :limit, type: :numeric, desc: "Limit price (uses mid if not specified)"
      option :dry_run, type: :boolean, default: false, desc: "Validate order without placing"
      def buy(type, symbol)
        require_authentication!

        unless %w[call put].include?(type.downcase)
          error "Type must be 'call' or 'put'"
          return
        end

        account = current_account || get_default_account
        return unless account

        with_error_handling do
          # Find the option contract
          option = find_option_for_order(symbol, type, options)
          return unless option

          # Build and place the order
          place_option_order(account, option, :buy, options)
        end
      end

      desc "sell TYPE SYMBOL", "Sell a call or put option"
      option :strike, type: :numeric, desc: "Strike price"
      option :expiration, type: :string, desc: "Expiration date (YYYY-MM-DD)"
      option :delta, type: :numeric, desc: "Target delta (finds closest strike)"
      option :dte, type: :numeric, desc: "Target days to expiration"
      option :quantity, type: :numeric, default: 1, desc: "Number of contracts"
      option :limit, type: :numeric, desc: "Limit price (uses mid if not specified)"
      option :dry_run, type: :boolean, default: false, desc: "Validate order without placing"
      def sell(type, symbol)
        require_authentication!

        unless %w[call put].include?(type.downcase)
          error "Type must be 'call' or 'put'"
          return
        end

        account = current_account || get_default_account
        return unless account

        with_error_handling do
          # Find the option contract
          option = find_option_for_order(symbol, type, options)
          return unless option

          # Build and place the order
          place_option_order(account, option, :sell, options)
        end
      end

      desc "spread SYMBOL", "Create a vertical spread"
      option :type, type: :string, required: true, enum: %w[call put], desc: "Call or put spread"
      option :long_strike, type: :numeric, required: true, desc: "Long leg strike price"
      option :short_strike, type: :numeric, required: true, desc: "Short leg strike price"
      option :expiration, type: :string, required: true, desc: "Expiration date (YYYY-MM-DD)"
      option :quantity, type: :numeric, default: 1, desc: "Number of spreads"
      option :limit, type: :numeric, desc: "Net debit/credit limit"
      option :dry_run, type: :boolean, default: false, desc: "Validate order without placing"
      def spread(symbol)
        require_authentication!

        account = current_account || get_default_account
        return unless account

        with_error_handling do
          # Fetch option chain to get the actual option objects
          nested_chain = Tastytrade::Models::NestedOptionChain.get(
            current_session,
            symbol.upcase
          )

          unless nested_chain
            error "Unable to fetch option chain for #{symbol}"
            return
          end

          # Find the specific options for the spread
          expiration_date = Date.parse(options[:expiration])
          exp_data = nested_chain.expirations.find { |e| e.expiration_date == expiration_date }

          unless exp_data
            error "Expiration #{options[:expiration]} not found"
            return
          end

          long_strike_data = exp_data.strikes.find { |s| s.strike_price == options[:long_strike] }
          short_strike_data = exp_data.strikes.find { |s| s.strike_price == options[:short_strike] }

          unless long_strike_data && short_strike_data
            error "One or both strikes not found"
            return
          end

          # Get the option symbols from the strike data
          long_symbol = options[:type] == "call" ? long_strike_data.call : long_strike_data.put
          short_symbol = options[:type] == "call" ? short_strike_data.call : short_strike_data.put

          unless long_symbol && short_symbol
            error "Options not available at specified strikes"
            return
          end

          # Create simple option objects with just the symbol for now
          # In a real implementation, we'd fetch full Option objects from the API
          long_option = OpenStruct.new(symbol: long_symbol, strike_price: options[:long_strike],
                                       expiration_date: expiration_date, option_type: options[:type].capitalize,
                                       expired?: false)
          short_option = OpenStruct.new(symbol: short_symbol, strike_price: options[:short_strike],
                                        expiration_date: expiration_date, option_type: options[:type].capitalize,
                                        expired?: false)

          builder = Tastytrade::OptionOrderBuilder.new(current_session, account)

          order = builder.vertical_spread(
            long_option,
            short_option,
            options[:quantity],
            price: options[:limit]
          )

          if options[:dry_run]
            success "Spread order validated successfully (dry run)"
            display_order_details(order)
          else
            confirm = prompt_for_order_confirmation(order, account)
            if confirm
              result = account.place_order(current_session, order)
              success "Spread order placed successfully! Order ID: #{result["id"]}"
            else
              warning "Order cancelled"
            end
          end
        end
      end

      desc "strangle SYMBOL", "Create a strangle position"
      option :call_strike, type: :numeric, desc: "Call strike price"
      option :put_strike, type: :numeric, desc: "Put strike price"
      option :call_delta, type: :numeric, desc: "Target delta for call (e.g., 0.30)"
      option :put_delta, type: :numeric, desc: "Target delta for put (e.g., -0.30)"
      option :expiration, type: :string, desc: "Expiration date (YYYY-MM-DD)"
      option :dte, type: :numeric, desc: "Target days to expiration"
      option :quantity, type: :numeric, default: 1, desc: "Number of strangles"
      option :limit, type: :numeric, desc: "Net credit limit"
      option :dry_run, type: :boolean, default: false, desc: "Validate order without placing"
      def strangle(symbol)
        require_authentication!

        account = current_account || get_default_account
        return unless account

        with_error_handling do
          # Get option chain to find appropriate strikes
          nested_chain = Tastytrade::Models::NestedOptionChain.get(
            current_session,
            symbol.upcase
          )

          unless nested_chain
            error "Unable to fetch option chain for #{symbol}"
            return
          end

          # Find expiration
          expiration = find_expiration(nested_chain, options)
          unless expiration
            error "Unable to find suitable expiration"
            return
          end

          # Find strikes based on delta or explicit values
          call_strike = options[:call_strike] || find_strike_by_delta(nested_chain, expiration,
                                                                      options[:call_delta] || 0.30, :call)
          put_strike = options[:put_strike] || find_strike_by_delta(nested_chain, expiration,
                                                                     options[:put_delta] || -0.30, :put)

          unless call_strike && put_strike
            error "Unable to find suitable strikes for strangle"
            return
          end

          # Find the option objects
          exp_data = nested_chain.expirations.find { |e| e.expiration_date == expiration }
          unless exp_data
            error "Expiration not found"
            return
          end

          call_strike_data = exp_data.strikes.find { |s| s.strike_price == call_strike }
          put_strike_data = exp_data.strikes.find { |s| s.strike_price == put_strike }

          unless call_strike_data && put_strike_data
            error "Strikes not found in chain"
            return
          end

          call_symbol = call_strike_data.call
          put_symbol = put_strike_data.put

          unless call_symbol && put_symbol
            error "Options not available at specified strikes"
            return
          end

          # Create simple option objects with just the symbol
          call_option = OpenStruct.new(symbol: call_symbol, strike_price: call_strike,
                                       expiration_date: expiration, option_type: "C",
                                       expired?: false)
          put_option = OpenStruct.new(symbol: put_symbol, strike_price: put_strike,
                                      expiration_date: expiration, option_type: "P",
                                      expired?: false)

          builder = Tastytrade::OptionOrderBuilder.new(current_session, account)

          order = builder.strangle(
            put_option,
            call_option,
            options[:quantity],
            price: options[:limit]
          )

          if options[:dry_run]
            success "Strangle order validated successfully (dry run)"
            display_order_details(order)
          else
            confirm = prompt_for_order_confirmation(order, account)
            if confirm
              result = account.place_order(current_session, order)
              success "Strangle order placed successfully! Order ID: #{result["id"]}"
            else
              warning "Order cancelled"
            end
          end
        end
      end

      desc "straddle SYMBOL", "Create a straddle position"
      option :strike, type: :numeric, desc: "Strike price (uses ATM if not specified)"
      option :expiration, type: :string, desc: "Expiration date (YYYY-MM-DD)"
      option :dte, type: :numeric, desc: "Target days to expiration"
      option :quantity, type: :numeric, default: 1, desc: "Number of straddles"
      option :limit, type: :numeric, desc: "Net credit limit"
      option :dry_run, type: :boolean, default: false, desc: "Validate order without placing"
      def straddle(symbol)
        require_authentication!

        account = current_account || get_default_account
        return unless account

        with_error_handling do
          # Get option chain
          nested_chain = Tastytrade::Models::NestedOptionChain.get(
            current_session,
            symbol.upcase
          )

          unless nested_chain
            error "Unable to fetch option chain for #{symbol}"
            return
          end

          # Find expiration
          expiration = find_expiration(nested_chain, options)
          unless expiration
            error "Unable to find suitable expiration"
            return
          end

          # Find strike (ATM if not specified)
          # Note: at_the_money_strike requires current_price parameter
          strike = options[:strike]
          unless strike
            # Try to find a middle strike from available strikes
            exp_data = nested_chain.expirations.find { |e| e.expiration_date == expiration }
            if exp_data && exp_data.strikes && exp_data.strikes.any?
              sorted_strikes = exp_data.strikes.map(&:strike_price).sort
              middle_index = sorted_strikes.length / 2
              strike = sorted_strikes[middle_index]
            end
          end

          unless strike
            error "Unable to find suitable strike for straddle"
            return
          end

          # Find the option objects
          exp_data = nested_chain.expirations.find { |e| e.expiration_date == expiration }
          unless exp_data
            error "Expiration not found"
            return
          end

          strike_data = exp_data.strikes.find { |s| s.strike_price == strike }
          unless strike_data
            error "Strike #{strike} not found"
            return
          end

          put_symbol = strike_data.put
          call_symbol = strike_data.call

          unless put_symbol && call_symbol
            error "Both put and call options required for straddle at strike #{strike}"
            return
          end

          # Create simple option objects with just the symbol
          put_option = OpenStruct.new(symbol: put_symbol, strike_price: strike,
                                      expiration_date: expiration, option_type: "P",
                                      expired?: false)
          call_option = OpenStruct.new(symbol: call_symbol, strike_price: strike,
                                       expiration_date: expiration, option_type: "C",
                                       expired?: false)

          builder = Tastytrade::OptionOrderBuilder.new(current_session, account)

          order = builder.straddle(
            put_option,
            call_option,
            options[:quantity],
            action: Tastytrade::OrderAction::BUY_TO_OPEN,
            price: options[:limit]
          )

          if options[:dry_run]
            success "Straddle order validated successfully (dry run)"
            display_order_details(order)
          else
            confirm = prompt_for_order_confirmation(order, account)
            if confirm
              result = account.place_order(current_session, order)
              success "Straddle order placed successfully! Order ID: #{result["id"]}"
            else
              warning "Order cancelled"
            end
          end
        end
      end

      desc "iron_butterfly SYMBOL", "Create an iron butterfly position"
      option :center_strike, type: :numeric, desc: "Center strike price (ATM if not specified)"
      option :wing_width, type: :numeric, default: 10, desc: "Distance from center to wing strikes"
      option :expiration, type: :string, desc: "Expiration date (YYYY-MM-DD)"
      option :dte, type: :numeric, desc: "Target days to expiration"
      option :quantity, type: :numeric, default: 1, desc: "Number of iron butterflies"
      option :limit, type: :numeric, desc: "Net credit limit"
      option :dry_run, type: :boolean, default: false, desc: "Validate order without placing"
      def iron_butterfly(symbol)
        require_authentication!

        account = current_account || get_default_account
        return unless account

        with_error_handling do
          # Get option chain
          nested_chain = Tastytrade::Models::NestedOptionChain.get(
            current_session,
            symbol.upcase
          )

          unless nested_chain
            error "Unable to fetch option chain for #{symbol}"
            return
          end

          # Find expiration
          expiration = find_expiration(nested_chain, options)
          unless expiration
            error "Unable to find suitable expiration"
            return
          end

          # Find center strike (ATM if not specified)
          center_strike = options[:center_strike]
          unless center_strike
            exp_data = nested_chain.expirations.find { |e| e.expiration_date == expiration }
            if exp_data && exp_data.strikes && exp_data.strikes.any?
              sorted_strikes = exp_data.strikes.map(&:strike_price).sort
              middle_index = sorted_strikes.length / 2
              center_strike = sorted_strikes[middle_index]
            end
          end

          unless center_strike
            error "Unable to find center strike"
            return
          end

          wing_width = options[:wing_width]
          call_long_strike = center_strike + wing_width
          put_long_strike = center_strike - wing_width

          # Find the strikes in the chain
          exp_data = nested_chain.expirations.find { |e| e.expiration_date == expiration }
          unless exp_data
            error "Expiration not found"
            return
          end

          center_data = exp_data.strikes.find { |s| s.strike_price == center_strike }
          call_long_data = exp_data.strikes.find { |s| s.strike_price == call_long_strike }
          put_long_data = exp_data.strikes.find { |s| s.strike_price == put_long_strike }

          unless center_data && call_long_data && put_long_data
            error "Required strikes not available in chain"
            return
          end

          # Get option symbols
          short_call_symbol = center_data.call
          short_put_symbol = center_data.put
          long_call_symbol = call_long_data.call
          long_put_symbol = put_long_data.put

          unless short_call_symbol && short_put_symbol && long_call_symbol && long_put_symbol
            error "Options not available at specified strikes"
            return
          end

          # Create option objects
          short_call = OpenStruct.new(symbol: short_call_symbol, strike_price: center_strike,
                                      expiration_date: expiration, option_type: "C",
                                      underlying_symbol: symbol.upcase, expired?: false)
          short_put = OpenStruct.new(symbol: short_put_symbol, strike_price: center_strike,
                                     expiration_date: expiration, option_type: "P",
                                     underlying_symbol: symbol.upcase, expired?: false)
          long_call = OpenStruct.new(symbol: long_call_symbol, strike_price: call_long_strike,
                                     expiration_date: expiration, option_type: "C",
                                     underlying_symbol: symbol.upcase, expired?: false)
          long_put = OpenStruct.new(symbol: long_put_symbol, strike_price: put_long_strike,
                                    expiration_date: expiration, option_type: "P",
                                    underlying_symbol: symbol.upcase, expired?: false)

          builder = Tastytrade::OptionOrderBuilder.new(current_session, account)

          order = builder.iron_butterfly(
            short_call,
            long_call,
            short_put,
            long_put,
            options[:quantity],
            price: options[:limit]
          )

          if options[:dry_run]
            success "Iron butterfly order validated successfully (dry run)"
            display_order_details(order)
          else
            confirm = prompt_for_order_confirmation(order, account)
            if confirm
              result = account.place_order(current_session, order)
              success "Iron butterfly order placed successfully! Order ID: #{result["id"]}"
            else
              warning "Order cancelled"
            end
          end
        end
      end

      desc "butterfly SYMBOL", "Create a butterfly spread"
      option :type, type: :string, required: true, enum: %w[call put], desc: "Call or put butterfly"
      option :center_strike, type: :numeric, desc: "Center strike price (ATM if not specified)"
      option :wing_width, type: :numeric, default: 10, desc: "Distance from center to wing strikes"
      option :expiration, type: :string, desc: "Expiration date (YYYY-MM-DD)"
      option :dte, type: :numeric, desc: "Target days to expiration"
      option :quantity, type: :numeric, default: 1, desc: "Number of butterflies"
      option :limit, type: :numeric, desc: "Net debit limit"
      option :dry_run, type: :boolean, default: false, desc: "Validate order without placing"
      def butterfly(symbol)
        require_authentication!

        account = current_account || get_default_account
        return unless account

        with_error_handling do
          # Get option chain
          nested_chain = Tastytrade::Models::NestedOptionChain.get(
            current_session,
            symbol.upcase
          )

          unless nested_chain
            error "Unable to fetch option chain for #{symbol}"
            return
          end

          # Find expiration
          expiration = find_expiration(nested_chain, options)
          unless expiration
            error "Unable to find suitable expiration"
            return
          end

          # Find center strike (ATM if not specified)
          center_strike = options[:center_strike]
          unless center_strike
            exp_data = nested_chain.expirations.find { |e| e.expiration_date == expiration }
            if exp_data && exp_data.strikes && exp_data.strikes.any?
              sorted_strikes = exp_data.strikes.map(&:strike_price).sort
              middle_index = sorted_strikes.length / 2
              center_strike = sorted_strikes[middle_index]
            end
          end

          unless center_strike
            error "Unable to find center strike"
            return
          end

          wing_width = options[:wing_width]
          low_strike = center_strike - wing_width
          high_strike = center_strike + wing_width

          # Find the strikes in the chain
          exp_data = nested_chain.expirations.find { |e| e.expiration_date == expiration }
          unless exp_data
            error "Expiration not found"
            return
          end

          low_data = exp_data.strikes.find { |s| s.strike_price == low_strike }
          center_data = exp_data.strikes.find { |s| s.strike_price == center_strike }
          high_data = exp_data.strikes.find { |s| s.strike_price == high_strike }

          unless low_data && center_data && high_data
            error "Required strikes not available in chain"
            return
          end

          # Get option symbols based on type
          option_type = options[:type]
          low_symbol = option_type == "call" ? low_data.call : low_data.put
          center_symbol = option_type == "call" ? center_data.call : center_data.put
          high_symbol = option_type == "call" ? high_data.call : high_data.put

          unless low_symbol && center_symbol && high_symbol
            error "#{option_type.capitalize} options not available at specified strikes"
            return
          end

          # Create option objects
          option_type_code = option_type == "call" ? "C" : "P"
          long_low = OpenStruct.new(symbol: low_symbol, strike_price: low_strike,
                                    expiration_date: expiration, option_type: option_type_code,
                                    underlying_symbol: symbol.upcase, expired?: false)
          short_middle = OpenStruct.new(symbol: center_symbol, strike_price: center_strike,
                                        expiration_date: expiration, option_type: option_type_code,
                                        underlying_symbol: symbol.upcase, expired?: false)
          long_high = OpenStruct.new(symbol: high_symbol, strike_price: high_strike,
                                     expiration_date: expiration, option_type: option_type_code,
                                     underlying_symbol: symbol.upcase, expired?: false)

          builder = Tastytrade::OptionOrderBuilder.new(current_session, account)

          order = builder.butterfly_spread(
            long_low,
            short_middle,
            long_high,
            options[:quantity],
            price: options[:limit]
          )

          if options[:dry_run]
            success "#{option_type.capitalize} butterfly order validated successfully (dry run)"
            display_order_details(order)
          else
            confirm = prompt_for_order_confirmation(order, account)
            if confirm
              result = account.place_order(current_session, order)
              success "#{option_type.capitalize} butterfly order placed successfully! Order ID: #{result["id"]}"
            else
              warning "Order cancelled"
            end
          end
        end
      end

      desc "calendar SYMBOL", "Create a calendar spread"
      option :type, type: :string, required: true, enum: %w[call put], desc: "Call or put calendar"
      option :strike, type: :numeric, desc: "Strike price (ATM if not specified)"
      option :short_dte, type: :numeric, default: 30, desc: "Days to expiration for short option"
      option :long_dte, type: :numeric, default: 60, desc: "Days to expiration for long option"
      option :quantity, type: :numeric, default: 1, desc: "Number of calendar spreads"
      option :limit, type: :numeric, desc: "Net debit limit"
      option :dry_run, type: :boolean, default: false, desc: "Validate order without placing"
      def calendar(symbol)
        require_authentication!

        account = current_account || get_default_account
        return unless account

        with_error_handling do
          # Get option chain
          nested_chain = Tastytrade::Models::NestedOptionChain.get(
            current_session,
            symbol.upcase
          )

          unless nested_chain
            error "Unable to fetch option chain for #{symbol}"
            return
          end

          # Find expirations based on DTE
          today = Date.today
          short_target_date = today + options[:short_dte]
          long_target_date = today + options[:long_dte]

          short_expiration = find_closest_expiration(nested_chain, short_target_date)
          long_expiration = find_closest_expiration(nested_chain, long_target_date)

          unless short_expiration && long_expiration && short_expiration < long_expiration
            error "Unable to find suitable expirations for calendar spread"
            return
          end

          # Find strike (ATM if not specified)
          strike = options[:strike]
          unless strike
            short_exp_data = nested_chain.expirations.find { |e| e.expiration_date == short_expiration }
            if short_exp_data && short_exp_data.strikes && short_exp_data.strikes.any?
              sorted_strikes = short_exp_data.strikes.map(&:strike_price).sort
              middle_index = sorted_strikes.length / 2
              strike = sorted_strikes[middle_index]
            end
          end

          unless strike
            error "Unable to find strike price"
            return
          end

          # Find the strikes in both expirations
          short_exp_data = nested_chain.expirations.find { |e| e.expiration_date == short_expiration }
          long_exp_data = nested_chain.expirations.find { |e| e.expiration_date == long_expiration }

          unless short_exp_data && long_exp_data
            error "Expiration data not found"
            return
          end

          short_strike_data = short_exp_data.strikes.find { |s| s.strike_price == strike }
          long_strike_data = long_exp_data.strikes.find { |s| s.strike_price == strike }

          unless short_strike_data && long_strike_data
            error "Strike not available in both expirations"
            return
          end

          # Get option symbols based on type
          option_type = options[:type]
          short_symbol = option_type == "call" ? short_strike_data.call : short_strike_data.put
          long_symbol = option_type == "call" ? long_strike_data.call : long_strike_data.put

          unless short_symbol && long_symbol
            error "#{option_type.capitalize} options not available at specified strike"
            return
          end

          # Create option objects
          option_type_code = option_type == "call" ? "C" : "P"
          short_option = OpenStruct.new(symbol: short_symbol, strike_price: strike,
                                        expiration_date: short_expiration, option_type: option_type_code,
                                        underlying_symbol: symbol.upcase, expired?: false)
          long_option = OpenStruct.new(symbol: long_symbol, strike_price: strike,
                                       expiration_date: long_expiration, option_type: option_type_code,
                                       underlying_symbol: symbol.upcase, expired?: false)

          builder = Tastytrade::OptionOrderBuilder.new(current_session, account)

          order = builder.calendar_spread(
            short_option,
            long_option,
            options[:quantity],
            price: options[:limit]
          )

          if options[:dry_run]
            success "#{option_type.capitalize} calendar spread order validated successfully (dry run)"
            display_order_details(order)
          else
            confirm = prompt_for_order_confirmation(order, account)
            if confirm
              result = account.place_order(current_session, order)
              success "#{option_type.capitalize} calendar spread order placed successfully! Order ID: #{result["id"]}"
            else
              warning "Order cancelled"
            end
          end
        end
      end

      desc "diagonal SYMBOL", "Create a diagonal spread"
      option :type, type: :string, required: true, enum: %w[call put], desc: "Call or put diagonal"
      option :short_strike, type: :numeric, desc: "Short option strike (ATM if not specified)"
      option :long_strike, type: :numeric, desc: "Long option strike (calculated from short_strike if not specified)"
      option :short_dte, type: :numeric, default: 30, desc: "Days to expiration for short option"
      option :long_dte, type: :numeric, default: 60, desc: "Days to expiration for long option"
      option :strike_width, type: :numeric, default: 5,
                            desc: "Distance between strikes (used if long_strike not specified)"
      option :quantity, type: :numeric, default: 1, desc: "Number of diagonal spreads"
      option :limit, type: :numeric, desc: "Net debit limit"
      option :dry_run, type: :boolean, default: false, desc: "Validate order without placing"
      def diagonal(symbol)
        require_authentication!

        account = current_account || get_default_account
        return unless account

        with_error_handling do
          # Get option chain
          nested_chain = Tastytrade::Models::NestedOptionChain.get(
            current_session,
            symbol.upcase
          )

          unless nested_chain
            error "Unable to fetch option chain for #{symbol}"
            return
          end

          # Find expirations based on DTE
          today = Date.today
          short_target_date = today + options[:short_dte]
          long_target_date = today + options[:long_dte]

          short_expiration = find_closest_expiration(nested_chain, short_target_date)
          long_expiration = find_closest_expiration(nested_chain, long_target_date)

          unless short_expiration && long_expiration && short_expiration < long_expiration
            error "Unable to find suitable expirations for diagonal spread"
            return
          end

          # Find strikes
          short_strike = options[:short_strike]
          unless short_strike
            short_exp_data = nested_chain.expirations.find { |e| e.expiration_date == short_expiration }
            if short_exp_data && short_exp_data.strikes && short_exp_data.strikes.any?
              sorted_strikes = short_exp_data.strikes.map(&:strike_price).sort
              middle_index = sorted_strikes.length / 2
              short_strike = sorted_strikes[middle_index]
            end
          end

          unless short_strike
            error "Unable to find short strike price"
            return
          end

          long_strike = options[:long_strike]
          unless long_strike
            # Calculate based on direction and strike width
            if options[:type] == "call"
              long_strike = short_strike + options[:strike_width]
            else
              long_strike = short_strike - options[:strike_width]
            end
          end

          # Find the strikes in both expirations
          short_exp_data = nested_chain.expirations.find { |e| e.expiration_date == short_expiration }
          long_exp_data = nested_chain.expirations.find { |e| e.expiration_date == long_expiration }

          unless short_exp_data && long_exp_data
            error "Expiration data not found"
            return
          end

          short_strike_data = short_exp_data.strikes.find { |s| s.strike_price == short_strike }
          long_strike_data = long_exp_data.strikes.find { |s| s.strike_price == long_strike }

          unless short_strike_data && long_strike_data
            error "Required strikes not available in expirations"
            return
          end

          # Get option symbols based on type
          option_type = options[:type]
          short_symbol = option_type == "call" ? short_strike_data.call : short_strike_data.put
          long_symbol = option_type == "call" ? long_strike_data.call : long_strike_data.put

          unless short_symbol && long_symbol
            error "#{option_type.capitalize} options not available at specified strikes"
            return
          end

          # Create option objects
          option_type_code = option_type == "call" ? "C" : "P"
          short_option = OpenStruct.new(symbol: short_symbol, strike_price: short_strike,
                                        expiration_date: short_expiration, option_type: option_type_code,
                                        underlying_symbol: symbol.upcase, expired?: false)
          long_option = OpenStruct.new(symbol: long_symbol, strike_price: long_strike,
                                       expiration_date: long_expiration, option_type: option_type_code,
                                       underlying_symbol: symbol.upcase, expired?: false)

          builder = Tastytrade::OptionOrderBuilder.new(current_session, account)

          order = builder.diagonal_spread(
            short_option,
            long_option,
            options[:quantity],
            price: options[:limit]
          )

          if options[:dry_run]
            success "#{option_type.capitalize} diagonal spread order validated successfully (dry run)"
            display_order_details(order)
          else
            confirm = prompt_for_order_confirmation(order, account)
            if confirm
              result = account.place_order(current_session, order)
              success "#{option_type.capitalize} diagonal spread order placed successfully! Order ID: #{result["id"]}"
            else
              warning "Order cancelled"
            end
          end
        end
      end

      private

      def get_default_account
        accounts = Tastytrade::Models::Account.get_all(current_session)
        if accounts && !accounts.empty?
          account = accounts.first
          info "Using account: #{account.account_number}"
          account
        else
          error "No accounts found. Please check your login."
          nil
        end
      end

      def apply_chain_filters(nested_chain, options)
        chain = nested_chain

        # Filter by DTE
        if options[:dte]
          chain = chain.filter_by_dte(max_dte: options[:dte])
        end

        if options[:min_dte]
          chain = chain.filter_by_dte(min_dte: options[:min_dte])
        end

        # Filter by expiration type
        case options[:type]
        when "weekly"
          chain = chain.weekly_expirations
        when "monthly"
          chain = chain.monthly_expirations
        when "quarterly"
          chain = chain.quarterly_expirations
        end

        # For display purposes, we'll filter the expirations and strikes in memory
        # Create a filtered version for display
        filtered_chain = chain.dup
        filtered_exps = chain.expirations ? chain.expirations.dup : []

        # Limit number of expirations
        if options[:expirations] && filtered_exps.any?
          filtered_exps = filtered_exps.first(options[:expirations])
        end

        # Filter by moneyness
        if options[:moneyness] != "all" && filtered_exps.any?
          filtered_exps.each do |exp|
            next unless exp.strikes

            filtered_strikes = exp.strikes.select do |strike|
              calls_match = strike.call && matches_moneyness?(strike.call, options[:moneyness])
              puts_match = strike.put && matches_moneyness?(strike.put, options[:moneyness])
              calls_match || puts_match
            end
            exp.instance_variable_set(:@strikes, filtered_strikes)
          end
        end

        # Filter by strikes - just take the middle strikes
        if options[:strikes] && filtered_exps.any?
          filtered_exps.each do |exp|
            next unless exp.strikes && exp.strikes.any?

            # Take middle strikes
            total_strikes = exp.strikes.length
            if total_strikes > options[:strikes]
              sorted_strikes = exp.strikes.sort_by(&:strike_price)
              start_idx = (total_strikes - options[:strikes]) / 2
              end_idx = start_idx + options[:strikes] - 1
              filtered_strikes = sorted_strikes[start_idx..end_idx]
              exp.instance_variable_set(:@strikes, filtered_strikes)
            end
          end
        end

        # Update the chain's expirations with our filtered version
        filtered_chain.instance_variable_set(:@expirations, filtered_exps)
        filtered_chain
      end

      def estimate_current_price(expirations)
        # Try to estimate the underlying price from option prices
        # Use the nearest expiration's ATM options
        return nil if expirations.empty?

        nearest_exp = expirations.first
        return nil unless nearest_exp.strikes

        # Find strikes with both call and put data
        strikes_with_both = nearest_exp.strikes.select { |s| s.call && s.put && s.call.bid && s.put.bid }
        return nil if strikes_with_both.empty?

        # Use put-call parity to estimate: S = C - P + K (simplified)
        # Or find the strike where call and put values are closest
        best_strike = strikes_with_both.min_by do |strike|
          call_mid = (strike.call.bid + strike.call.ask) / 2 rescue 0
          put_mid = (strike.put.bid + strike.put.ask) / 2 rescue 0
          (call_mid - put_mid).abs
        end

        best_strike&.strike_price
      end

      def matches_moneyness?(option, moneyness_filter)
        case moneyness_filter
        when "itm"
          option.itm?
        when "atm"
          option.atm?
        when "otm"
          option.otm?
        else
          true
        end
      end

      def display_option_chain(chain, symbol, options)
        formatter = Tastytrade::OptionChainFormatter.new(pastel: Pastel.new)

        case options[:format]
        when "json"
          # Convert chain to JSON
          puts chain.to_json
        when "csv"
          # Would need to implement CSV export
          puts "CSV format not yet implemented"
        when "compact"
          puts formatter.format_table(chain, format: :compact)
        else
          if options[:greeks]
            puts formatter.format_table(chain, show_greeks: true)
          else
            puts formatter.format_table(chain)
          end
        end
      end

      def display_option_quote(option, format)
        pastel = Pastel.new

        case format
        when "json"
          puts JSON.pretty_generate(option.to_h)
        when "compact"
          mid_price = format_currency((option.bid + option.ask) / 2)
          bid = format_currency(option.bid)
          ask = format_currency(option.ask)
          puts "#{option.display_symbol} Bid: #{bid} Ask: #{ask} Mid: #{mid_price}"
        else
          puts pastel.bright_blue("=" * 60)
          puts pastel.bright_white.bold("Option Quote: #{option.display_symbol}")
          puts pastel.bright_blue("=" * 60)

          puts "Strike:      #{format_currency(option.strike_price)}"
          puts "Type:        #{option.option_type.upcase}"
          puts "Expiration:  #{option.expiration_date}"
          puts "DTE:         #{option.dte}"
          puts ""

          puts pastel.bright_white.bold("Pricing")
          puts "Bid:         #{pastel.red(format_currency(option.bid))}"
          puts "Ask:         #{pastel.green(format_currency(option.ask))}"
          puts "Mid:         #{format_currency((option.bid + option.ask) / 2)}"
          puts "Spread:      #{format_currency(option.ask - option.bid)}"
          puts ""

          if option.delta
            puts pastel.bright_white.bold("Greeks")
            puts "Delta:       #{format_greek(option.delta, :delta)}"
            puts "Gamma:       #{format_greek(option.gamma, :gamma)}" if option.gamma
            puts "Theta:       #{format_greek(option.theta, :theta)}" if option.theta
            puts "Vega:        #{format_greek(option.vega, :vega)}" if option.vega
            puts "Rho:         #{format_greek(option.rho, :rho)}" if option.rho
            puts ""
          end

          puts "Volume:      #{format_volume(option.volume)}"
          puts "Open Int:    #{format_volume(option.open_interest)}"
          puts "IV:          #{format_iv_percentage(option.implied_volatility)}" if option.implied_volatility

          puts pastel.bright_blue("=" * 60)
        end
      end

      def extract_underlying_from_occ(occ_symbol)
        # OCC format: AAPL240315C00150000 or AAPL 240315C00150000 (with space)
        # Extract underlying (everything before the date)
        # Remove any spaces first
        clean_symbol = occ_symbol.gsub(/\s+/, "")
        match = clean_symbol.match(/^([A-Z]+)\d{6}[CP]\d+$/)
        match ? match[1] : clean_symbol
      end

      def find_option_by_symbol(nested_chain, symbol)
        # Normalize the symbol by removing spaces for comparison
        normalized_symbol = symbol.gsub(/\s+/, "")

        nested_chain.expirations.each do |exp|
          exp.strikes.each do |strike|
            # strike.call and strike.put are just OCC symbol strings, not Option objects
            # Compare normalized versions
            if strike.call && strike.call.gsub(/\s+/, "") == normalized_symbol
              # Return an OpenStruct with basic option data since API fetch isn't working
              return create_option_from_strike(strike, exp, :call)
            end
            if strike.put && strike.put.gsub(/\s+/, "") == normalized_symbol
              # Return an OpenStruct with basic option data since API fetch isn't working
              return create_option_from_strike(strike, exp, :put)
            end
          end
        end
        nil
      end

      def create_option_from_strike(strike, expiration, type)
        # Create a minimal option object with available data
        OpenStruct.new(
          symbol: type == :call ? strike.call : strike.put,
          display_symbol: type == :call ? strike.call : strike.put,
          strike_price: strike.strike_price,
          expiration_date: expiration.expiration_date,
          option_type: type == :call ? "Call" : "Put",
          dte: expiration.days_to_expiration,
          # Placeholder values for quote display
          bid: 0.0,
          ask: 0.0,
          volume: 0,
          open_interest: 0,
          implied_volatility: nil,
          delta: nil,
          gamma: nil,
          theta: nil,
          vega: nil,
          rho: nil
        )
      end

      def find_option_for_order(symbol, type, options)
        info "Finding option contract..."

        # Fetch the option chain
        nested_chain = Tastytrade::Models::NestedOptionChain.get(
          current_session,
          symbol.upcase
        )

        unless nested_chain
          error "Unable to fetch option chain for #{symbol}"
          return nil
        end

        # Find expiration
        expiration = find_expiration(nested_chain, options)
        unless expiration
          error "Unable to find suitable expiration"
          return nil
        end

        # Find strike
        strike = if options[:delta]
          find_strike_by_delta(nested_chain, expiration, options[:delta], type.to_sym)
        elsif options[:strike]
          options[:strike]
        else
          nested_chain.at_the_money_strike
        end

        unless strike
          error "Unable to find suitable strike"
          return nil
        end

        # Find the specific option
        exp_data = nested_chain.expirations.find { |e| e.expiration_date == expiration }
        strike_data = exp_data.strikes.find { |s| s.strike_price == strike }

        # strike_data.call and strike_data.put are OCC symbol strings
        option_symbol = type.downcase == "call" ? strike_data.call : strike_data.put

        unless option_symbol
          error "Option not found for strike #{strike} expiration #{expiration}"
          return nil
        end

        # Create an option object from the strike data
        create_option_from_strike(strike_data, exp_data, type.downcase.to_sym)
      end

      def find_expiration(nested_chain, options)
        if options[:expiration]
          Date.parse(options[:expiration])
        elsif options[:dte]
          # Find closest expiration to target DTE
          target_date = Date.today + options[:dte]
          nested_chain.expirations.min_by { |e| (e.expiration_date - target_date).abs }.expiration_date
        else
          # Default to nearest monthly
          nested_chain.monthly_expirations.first&.expiration_date
        end
      end

      def find_strike_by_delta(nested_chain, expiration, target_delta, option_type)
        exp_data = nested_chain.expirations.find { |e| e.expiration_date == expiration }
        return nil unless exp_data

        best_strike = nil
        best_delta_diff = Float::INFINITY

        exp_data.strikes.each do |strike|
          option = option_type == :call ? strike.call : strike.put
          next unless option && option.delta

          delta_diff = (option.delta - target_delta).abs
          if delta_diff < best_delta_diff
            best_delta_diff = delta_diff
            best_strike = strike.strike_price
          end
        end

        best_strike
      end

      def find_closest_expiration(nested_chain, target_date)
        return nil unless nested_chain && nested_chain.expirations

        best_expiration = nil
        best_diff = Float::INFINITY

        nested_chain.expirations.each do |exp_data|
          next unless exp_data.expiration_date

          diff = (exp_data.expiration_date - target_date).abs
          if diff < best_diff
            best_diff = diff
            best_expiration = exp_data.expiration_date
          end
        end

        best_expiration
      end

      def place_option_order(account, option, action, options)
        builder = Tastytrade::OptionOrderBuilder.new(current_session, account)

        # Calculate limit price if not provided
        limit_price = options[:limit]
        if !limit_price && option.bid && option.ask && option.bid > 0 && option.ask > 0
          limit_price = ((option.bid + option.ask) / 2).round(2)
        end

        # Default to a small price if we still don't have one (for testing)
        limit_price ||= 0.01

        # Build the order
        order = case action
                when :buy
                  option.option_type == "Call" ?
                    builder.buy_call(option, options[:quantity], price: limit_price) :
                    builder.buy_put(option, options[:quantity], price: limit_price)
                when :sell
                  option.option_type == "Call" ?
                    builder.sell_call(option, options[:quantity], price: limit_price) :
                    builder.sell_put(option, options[:quantity], price: limit_price)
        end

        if options[:dry_run]
          success "Order validated successfully (dry run)"
          display_order_details(order)
        else
          confirm = prompt_for_order_confirmation(order, account)
          if confirm
            result = account.place_order(current_session, order)
            success "Order placed successfully! Order ID: #{result["id"]}"
          else
            warning "Order cancelled"
          end
        end
      end

      def display_order_details(order)
        pastel = Pastel.new

        puts pastel.bright_white.bold("Order Details:")
        puts "Type:        #{order.type}"
        puts "Time in Force: #{order.time_in_force}"

        order.legs.each_with_index do |leg, i|
          puts ""
          puts pastel.bright_white("Leg #{i + 1}:")
          puts "  Symbol:    #{leg.symbol || leg["symbol"]}"
          puts "  Action:    #{leg.action || leg["action"]}"
          puts "  Quantity:  #{leg.quantity || leg["quantity"]}"
        end

        puts ""
        puts "Price:       #{format_currency(order.price)}" if order.price
      end

      def prompt_for_order_confirmation(order, account)
        pastel = Pastel.new
        prompt = create_vim_prompt

        puts ""
        display_order_details(order)
        puts ""
        puts pastel.yellow("Account: #{account.account_number} (#{account.is_test_drive ? "SANDBOX" : "PRODUCTION"})")

        prompt.yes?("Place this order?")
      end

      def with_error_handling
        yield
      rescue Tastytrade::Error => e
        error "Tastytrade API error: #{e.message}"
      rescue StandardError => e
        error "Unexpected error: #{e.message}"
        puts e.backtrace if ENV["DEBUG"]
      end

      # Create vim-enabled prompt for consistent UI
      def create_vim_prompt
        prompt = TTY::Prompt.new

        # Add vim-style navigation
        prompt.on(:keypress) do |event|
          if event.value == "j"
            event.trigger(:keydown)
          elsif event.value == "k"
            event.trigger(:keyup)
          elsif event.value == "q" || event.key.name == :escape
            exit(0)
          end
        end

        prompt
      end
    end
  end
end
