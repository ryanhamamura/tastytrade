# frozen_string_literal: true

require "tty-table"
require "pastel"
require "csv"
require "json"

module Tastytrade
  # Formatter for displaying option chains with advanced formatting, colors, and Greeks
  #
  # This class provides professional visualization of option chains with features including:
  # - ITM/ATM/OTM color coding for visual strike identification
  # - Bid/ask price coloring to highlight market sides
  # - Volume and open interest formatting with K/M suffixes
  # - Greeks display with appropriate decimal precision
  # - Multiple display formats (detailed, compact, greeks-focused)
  # - Export capabilities to CSV and JSON formats
  # - Performance optimization for large chains
  #
  # @example Basic usage with color output
  #   formatter = OptionChainFormatter.new(pastel: Pastel.new)
  #   puts formatter.format_table(option_chain, current_price: 450.25)
  #
  # @example Display with Greeks
  #   formatter = OptionChainFormatter.new
  #   puts formatter.format_table(chain,
  #     current_price: 450.25,
  #     show_greeks: true,
  #     format: :greeks
  #   )
  #
  # @example Export to CSV for analysis
  #   csv_data = formatter.to_csv(option_chain, current_price: 450.25)
  #   File.write("spy_chain_#{Date.today}.csv", csv_data)
  #
  # @example Export to JSON for API response
  #   json_data = formatter.to_json(option_chain, current_price: 450.25)
  #   response = JSON.parse(json_data)
  #
  # @note The formatter automatically limits display to 21 strikes around ATM
  #   for chains with more than 20 strikes per expiration
  class OptionChainFormatter
    # Initialize a new OptionChainFormatter
    #
    # @param pastel [Pastel] Pastel instance for colorization
    def initialize(pastel: nil)
      @pastel = pastel || Pastel.new(enabled: false)
    end

    # Format option chain as a colored table
    #
    # @param chain [Tastytrade::Models::OptionChain, Tastytrade::Models::NestedOptionChain] Option chain data
    # @param current_price [BigDecimal, Float] Current underlying price for moneyness calculation
    # @param show_greeks [Boolean] Whether to display Greeks columns
    # @param format [Symbol] Display format (:detailed, :compact, :greeks)
    # @return [String] Formatted table output
    def format_table(chain, current_price: nil, show_greeks: false, format: :detailed)
      return format_empty_chain(chain) if chain_empty?(chain)

      output = []
      output << format_header(chain, current_price)

      if chain.is_a?(Tastytrade::Models::NestedOptionChain)
        output << format_nested_chain(chain, current_price, show_greeks, format)
      else
        output << format_compact_chain(chain, current_price, show_greeks, format)
      end

      output.join("\n")
    end

    # Export option chain to CSV format
    #
    # @param chain [Tastytrade::Models::OptionChain, Tastytrade::Models::NestedOptionChain] Option chain data
    # @param current_price [BigDecimal, Float] Current underlying price
    # @return [String] CSV formatted data
    def to_csv(chain, current_price: nil)
      CSV.generate do |csv|
        csv << csv_headers

        if chain.is_a?(Tastytrade::Models::NestedOptionChain)
          chain.expirations.each do |exp|
            exp.strikes.each do |strike|
              csv << build_csv_row(strike, exp.expiration_date, exp.days_to_expiration, current_price)
            end
          end
        else
          chain.expiration_dates.each do |exp_date|
            options = chain.options_for_expiration(exp_date)
            strikes = group_options_by_strike(options)
            strikes.each do |strike_price, opts|
              csv << build_csv_row_from_options(opts, exp_date, current_price)
            end
          end
        end
      end
    end

    # Export option chain to JSON format
    #
    # @param chain [Tastytrade::Models::OptionChain, Tastytrade::Models::NestedOptionChain] Option chain data
    # @param current_price [BigDecimal, Float] Current underlying price
    # @return [String] JSON formatted data
    def to_json(chain, current_price: nil)
      data = {
        underlying_symbol: chain.underlying_symbol,
        current_price: current_price&.to_f,
        timestamp: Time.now.iso8601,
        chain_type: chain.option_chain_type,
        expirations: []
      }

      if chain.is_a?(Tastytrade::Models::NestedOptionChain)
        data[:expirations] = format_nested_json(chain, current_price)
      else
        data[:expirations] = format_compact_json(chain, current_price)
      end

      JSON.pretty_generate(data)
    end

    private

    def format_header(chain, current_price)
      header = []
      header << @pastel.bold("#{chain.underlying_symbol} Option Chain")
      header << "Current Price: #{format_currency(current_price)}" if current_price
      header << "━" * terminal_width
      header.join(" - ")
    end

    def format_nested_chain(chain, current_price, show_greeks, format)
      output = []

      chain.expirations.each do |exp|
        output << format_expiration_header(exp)

        case format
        when :detailed
          output << format_detailed_strikes(exp.strikes, current_price, show_greeks)
        when :compact
          output << format_compact_strikes(exp.strikes, current_price)
        when :greeks
          output << format_greeks_strikes(exp.strikes, current_price)
        end

        output << ""
      end

      output.join("\n")
    end

    def format_expiration_header(exp)
      header = []
      header << @pastel.cyan.bold("#{exp.expiration_date} (#{exp.days_to_expiration} DTE)")
      header << "Type: #{exp.expiration_type}, Settlement: #{exp.settlement_type}"
      header.join(" - ")
    end

    def format_detailed_strikes(strikes, current_price, show_greeks)
      return "No strikes available" if strikes.empty?

      # Find ATM strike for centering
      atm_strike = find_atm_strike(strikes.map(&:strike_price), current_price)

      # Build table headers
      headers = build_detailed_headers(show_greeks)

      # Build rows
      rows = strikes.map do |strike|
        build_detailed_row(strike, current_price, atm_strike, show_greeks)
      end

      # Limit display around ATM if too many strikes
      limited_rows = rows
      message = nil
      if rows.size > 20
        limited_rows = limit_strikes_around_atm(rows, strikes, atm_strike)
        message = @pastel.dim("Showing strikes around ATM (#{limited_rows.size} of #{strikes.size} total)")
      end

      result = render_table(headers, limited_rows)
      message ? "#{message}\n#{result}" : result
    end

    def build_detailed_headers(show_greeks)
      headers = []

      # Call side headers
      headers += ["Vol", "OI", "Bid", "Ask"]
      headers += ["Δ", "IV"] if show_greeks

      # Strike column
      headers << "Strike"

      # Put side headers
      headers += ["IV", "Δ"] if show_greeks
      headers += ["Bid", "Ask", "OI", "Vol"]

      headers
    end

    def build_detailed_row(strike, current_price, atm_strike, show_greeks)
      row = []

      # Call data
      if strike.call
        call_opt = fetch_option_data(strike.call)
        row += [
          format_volume(call_opt[:volume]),
          format_volume(call_opt[:open_interest]),
          color_bid(call_opt[:bid]),
          color_ask(call_opt[:ask])
        ]

        if show_greeks
          row += [
            format_delta(call_opt[:delta]),
            format_iv(call_opt[:implied_volatility])
          ]
        end
      else
        row += show_greeks ? ["-", "-", "-", "-", "-", "-"] : ["-", "-", "-", "-"]
      end

      # Strike price with moneyness coloring
      row << format_strike_with_moneyness(strike.strike_price, current_price, atm_strike)

      # Put data
      if strike.put
        put_opt = fetch_option_data(strike.put)

        if show_greeks
          row += [
            format_iv(put_opt[:implied_volatility]),
            format_delta(put_opt[:delta])
          ]
        end

        row += [
          color_bid(put_opt[:bid]),
          color_ask(put_opt[:ask]),
          format_volume(put_opt[:open_interest]),
          format_volume(put_opt[:volume])
        ]
      else
        row += show_greeks ? ["-", "-", "-", "-", "-", "-"] : ["-", "-", "-", "-"]
      end

      row
    end

    def format_strike_with_moneyness(strike_price, current_price, atm_strike)
      formatted = format_currency(strike_price)

      return formatted unless current_price

      # Determine moneyness and apply color
      if strike_price == atm_strike
        @pastel.yellow.bold(formatted + "*")
      elsif strike_price < current_price
        # ITM for calls, OTM for puts
        @pastel.green(formatted)
      else
        # OTM for calls, ITM for puts
        @pastel.red(formatted)
      end
    end

    def color_bid(price)
      return "-" if price.nil? || price == 0
      @pastel.green(format_currency(price))
    end

    def color_ask(price)
      return "-" if price.nil? || price == 0
      @pastel.red(format_currency(price))
    end

    def format_volume(volume)
      return "-" unless volume && volume > 0

      case volume
      when 0...1000
        volume.to_s
      when 1000...1_000_000
        "#{(volume / 1000.0).round(1)}K"
      else
        "#{(volume / 1_000_000.0).round(1)}M"
      end
    end

    def format_delta(delta)
      return "-" unless delta
      format("%.3f", delta)
    end

    def format_iv(iv)
      return "-" unless iv
      "#{(iv * 100).round(1)}%"
    end

    def format_currency(amount)
      return "-" unless amount
      "$#{"%.2f" % amount.to_f}"
    end

    def find_atm_strike(strikes, current_price)
      return strikes[strikes.size / 2] unless current_price

      strikes.min_by { |strike| (strike - current_price).abs }
    end

    def limit_strikes_around_atm(rows, strikes, atm_strike)
      atm_index = strikes.index { |s| s.strike_price == atm_strike }
      return rows unless atm_index

      start_idx = [0, atm_index - 10].max
      end_idx = [strikes.size - 1, atm_index + 10].min

      # Note: message is printed separately in format_detailed_strikes
      rows[start_idx..end_idx]
    end

    def render_table(headers, rows)
      begin
        table = TTY::Table.new(headers, rows)
        table.render(:unicode,
          padding: [0, 1],
          alignments: [:right] * headers.size,
          border: { style: :dim }
        )
      rescue StandardError
        # Fallback for non-TTY environments
        fallback_render(headers, rows)
      end
    end

    def fallback_render(headers, rows)
      output = []
      output << headers.join(" | ")
      output << "-" * (headers.size * 10)
      rows.each { |row| output << row.join(" | ") }
      output.join("\n")
    end

    def fetch_option_data(option_symbol)
      # This would normally fetch real option data
      # For now, return placeholder data structure
      {
        bid: nil,
        ask: nil,
        volume: nil,
        open_interest: nil,
        delta: nil,
        gamma: nil,
        theta: nil,
        vega: nil,
        implied_volatility: nil
      }
    end

    def format_greeks_strikes(strikes, current_price)
      return "No strikes available" if strikes.empty?

      headers = ["Strike", "Call Δ", "Call γ", "Call θ", "Call ν", "Put Δ", "Put γ", "Put θ", "Put ν"]

      rows = strikes.map do |strike|
        row = [format_strike_with_moneyness(strike.strike_price, current_price, nil)]

        # Call Greeks
        if strike.call
          call_data = fetch_option_data(strike.call)
          row += [
            format_delta(call_data[:delta]),
            format_greek(call_data[:gamma]),
            format_greek(call_data[:theta]),
            format_greek(call_data[:vega])
          ]
        else
          row += ["-", "-", "-", "-"]
        end

        # Put Greeks
        if strike.put
          put_data = fetch_option_data(strike.put)
          row += [
            format_delta(put_data[:delta]),
            format_greek(put_data[:gamma]),
            format_greek(put_data[:theta]),
            format_greek(put_data[:vega])
          ]
        else
          row += ["-", "-", "-", "-"]
        end

        row
      end

      render_table(headers, rows)
    end

    def format_greek(value)
      return "-" unless value
      format("%.4f", value)
    end

    def format_compact_strikes(strikes, current_price)
      return "No strikes available" if strikes.empty?

      headers = ["Strike", "Call", "Put"]

      rows = strikes.map do |strike|
        [
          format_strike_with_moneyness(strike.strike_price, current_price, nil),
          strike.call || "-",
          strike.put || "-"
        ]
      end

      render_table(headers, rows)
    end

    def format_compact_chain(chain, current_price, show_greeks, format)
      output = []

      chain.expiration_dates.each do |exp_date|
        options = chain.options_for_expiration(exp_date)
        next if options.empty?

        output << @pastel.cyan.bold(exp_date.to_s)

        strikes = group_options_by_strike(options)

        case format
        when :detailed
          output << format_detailed_options(strikes, current_price, show_greeks)
        when :compact
          output << format_compact_options(strikes, current_price)
        when :greeks
          output << format_greeks_options(strikes, current_price)
        end

        output << ""
      end

      output.join("\n")
    end

    def group_options_by_strike(options)
      strikes = {}
      options.each do |opt|
        strikes[opt.strike_price] ||= {}
        strikes[opt.strike_price][opt.option_type.downcase.to_sym] = opt
      end
      strikes.sort.to_h
    end

    def format_detailed_options(strikes, current_price, show_greeks)
      headers = build_detailed_headers(show_greeks)
      atm_strike = find_atm_strike(strikes.keys, current_price)

      rows = strikes.map do |strike_price, opts|
        build_detailed_option_row(strike_price, opts, current_price, atm_strike, show_greeks)
      end

      render_table(headers, rows)
    end

    def build_detailed_option_row(strike_price, opts, current_price, atm_strike, show_greeks)
      row = []

      # Call data
      if opts[:call]
        row += [
          format_volume(opts[:call].volume),
          format_volume(opts[:call].open_interest),
          color_bid(opts[:call].bid),
          color_ask(opts[:call].ask)
        ]

        if show_greeks
          row += [
            format_delta(opts[:call].delta),
            format_iv(opts[:call].implied_volatility)
          ]
        end
      else
        row += show_greeks ? ["-", "-", "-", "-", "-", "-"] : ["-", "-", "-", "-"]
      end

      # Strike
      row << format_strike_with_moneyness(strike_price, current_price, atm_strike)

      # Put data
      if opts[:put]
        if show_greeks
          row += [
            format_iv(opts[:put].implied_volatility),
            format_delta(opts[:put].delta)
          ]
        end

        row += [
          color_bid(opts[:put].bid),
          color_ask(opts[:put].ask),
          format_volume(opts[:put].open_interest),
          format_volume(opts[:put].volume)
        ]
      else
        row += show_greeks ? ["-", "-", "-", "-", "-", "-"] : ["-", "-", "-", "-"]
      end

      row
    end

    def chain_empty?(chain)
      if chain.is_a?(Tastytrade::Models::NestedOptionChain)
        chain.expirations.empty?
      else
        chain.expiration_dates.empty?
      end
    end

    def format_empty_chain(chain)
      @pastel.yellow("No options available for #{chain.underlying_symbol}")
    end

    def terminal_width
      TTY::Screen.width rescue 80
    end

    def csv_headers
      [
        "Expiration", "DTE", "Strike", "Moneyness",
        "Call Symbol", "Call Bid", "Call Ask", "Call Volume", "Call OI", "Call Delta", "Call IV",
        "Put Symbol", "Put Bid", "Put Ask", "Put Volume", "Put OI", "Put Delta", "Put IV"
      ]
    end

    def build_csv_row(strike, exp_date, dte, current_price)
      moneyness = calculate_moneyness(strike.strike_price, current_price)

      row = [exp_date, dte, strike.strike_price, moneyness]

      # Call data
      if strike.call
        call_data = fetch_option_data(strike.call)
        row += [
          strike.call,
          call_data[:bid],
          call_data[:ask],
          call_data[:volume],
          call_data[:open_interest],
          call_data[:delta],
          call_data[:implied_volatility]
        ]
      else
        row += [nil] * 7
      end

      # Put data
      if strike.put
        put_data = fetch_option_data(strike.put)
        row += [
          strike.put,
          put_data[:bid],
          put_data[:ask],
          put_data[:volume],
          put_data[:open_interest],
          put_data[:delta],
          put_data[:implied_volatility]
        ]
      else
        row += [nil] * 7
      end

      row
    end

    def build_csv_row_from_options(opts, exp_date, current_price)
      strike_price = opts.values.first.strike_price
      moneyness = calculate_moneyness(strike_price, current_price)

      row = [exp_date, nil, strike_price, moneyness]

      # Call data
      if opts[:call]
        row += [
          opts[:call].symbol,
          opts[:call].bid,
          opts[:call].ask,
          opts[:call].volume,
          opts[:call].open_interest,
          opts[:call].delta,
          opts[:call].implied_volatility
        ]
      else
        row += [nil] * 7
      end

      # Put data
      if opts[:put]
        row += [
          opts[:put].symbol,
          opts[:put].bid,
          opts[:put].ask,
          opts[:put].volume,
          opts[:put].open_interest,
          opts[:put].delta,
          opts[:put].implied_volatility
        ]
      else
        row += [nil] * 7
      end

      row
    end

    def calculate_moneyness(strike_price, current_price)
      return "Unknown" unless current_price

      diff = ((strike_price - current_price) / current_price * 100).round(2)

      case diff.abs
      when 0..1
        "ATM"
      else
        diff < 0 ? "ITM" : "OTM"
      end
    end

    def format_nested_json(chain, current_price)
      chain.expirations.map do |exp|
        {
          expiration_date: exp.expiration_date,
          days_to_expiration: exp.days_to_expiration,
          expiration_type: exp.expiration_type,
          strikes: exp.strikes.map { |s| format_strike_json(s, current_price) }
        }
      end
    end

    def format_compact_json(chain, current_price)
      chain.expiration_dates.map do |exp_date|
        options = chain.options_for_expiration(exp_date)
        strikes = group_options_by_strike(options)

        {
          expiration_date: exp_date,
          strikes: strikes.map { |strike, opts| format_options_json(strike, opts, current_price) }
        }
      end
    end

    def format_strike_json(strike, current_price)
      {
        strike_price: strike.strike_price.to_f,
        moneyness: calculate_moneyness(strike.strike_price, current_price),
        call: strike.call ? format_option_json(strike.call) : nil,
        put: strike.put ? format_option_json(strike.put) : nil
      }
    end

    def format_options_json(strike_price, opts, current_price)
      {
        strike_price: strike_price.to_f,
        moneyness: calculate_moneyness(strike_price, current_price),
        call: opts[:call] ? format_option_details_json(opts[:call]) : nil,
        put: opts[:put] ? format_option_details_json(opts[:put]) : nil
      }
    end

    def format_option_json(symbol)
      data = fetch_option_data(symbol)
      {
        symbol: symbol,
        bid: data[:bid],
        ask: data[:ask],
        volume: data[:volume],
        open_interest: data[:open_interest],
        delta: data[:delta],
        gamma: data[:gamma],
        theta: data[:theta],
        vega: data[:vega],
        implied_volatility: data[:implied_volatility]
      }
    end

    def format_option_details_json(option)
      {
        symbol: option.symbol,
        bid: option.bid,
        ask: option.ask,
        volume: option.volume,
        open_interest: option.open_interest,
        delta: option.delta,
        gamma: option.gamma,
        theta: option.theta,
        vega: option.vega,
        implied_volatility: option.implied_volatility
      }
    end
  end
end
