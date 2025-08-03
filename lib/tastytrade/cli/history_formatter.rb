# frozen_string_literal: true

require "tty-table"
require "bigdecimal"

module Tastytrade
  # Formatter for displaying transaction history in various formats
  class HistoryFormatter
    def initialize(pastel: nil)
      @pastel = pastel || Pastel.new
    end

    # Format transactions as a table
    def format_table(transactions, group_by: nil)
      return if transactions.empty?

      case group_by
      when :symbol
        format_by_symbol(transactions)
      when :type
        format_by_type(transactions)
      when :date
        format_by_date(transactions)
      else
        format_detailed_table(transactions)
      end
    end

    private

    def format_detailed_table(transactions)
      headers = ["Date", "Symbol", "Type", "Action", "Qty", "Price", "Value", "Fees", "Net"]
      rows = build_detailed_rows(transactions)

      table = TTY::Table.new(headers, rows)

      begin
        puts table.render(:unicode, padding: [0, 1])
      rescue StandardError
        # Fallback for testing or non-TTY environments
        puts headers.join(" | ")
        puts "-" * 120
        rows.each { |row| puts row.join(" | ") }
      end

      display_detailed_summary(transactions)
    end

    def format_by_symbol(transactions)
      grouped = transactions.group_by(&:symbol)

      grouped.each do |symbol, symbol_transactions|
        next unless symbol # Skip transactions without symbols

        puts @pastel.bold("\n#{symbol}")
        puts "-" * 80

        headers = ["Date", "Type", "Action", "Qty", "Price", "Value", "Net"]
        rows = build_symbol_rows(symbol_transactions)

        table = TTY::Table.new(headers, rows)
        begin
          puts table.render(:unicode, padding: [0, 1])
        rescue StandardError
          puts headers.join(" | ")
          puts "-" * 80
          rows.each { |row| puts row.join(" | ") }
        end

        display_symbol_summary(symbol_transactions)
      end

      display_detailed_summary(transactions)
    end

    def format_by_type(transactions)
      grouped = transactions.group_by(&:transaction_type)

      grouped.each do |type, type_transactions|
        puts @pastel.bold("\n#{type}")
        puts "-" * 80

        headers = ["Date", "Symbol", "Action", "Qty", "Price", "Value", "Net"]
        rows = build_type_rows(type_transactions)

        table = TTY::Table.new(headers, rows)
        begin
          puts table.render(:unicode, padding: [0, 1])
        rescue StandardError
          puts headers.join(" | ")
          puts "-" * 80
          rows.each { |row| puts row.join(" | ") }
        end

        display_type_summary(type_transactions)
      end

      display_detailed_summary(transactions)
    end

    def format_by_date(transactions)
      grouped = transactions.group_by { |t| t.transaction_date&.strftime("%Y-%m-%d") }

      grouped.keys.sort.reverse.each do |date|
        date_transactions = grouped[date]
        next unless date # Skip transactions without dates

        puts @pastel.bold("\n#{date}")
        puts "-" * 80

        headers = ["Symbol", "Type", "Action", "Qty", "Price", "Value", "Net"]
        rows = build_date_rows(date_transactions)

        table = TTY::Table.new(headers, rows)
        begin
          puts table.render(:unicode, padding: [0, 1])
        rescue StandardError
          puts headers.join(" | ")
          puts "-" * 80
          rows.each { |row| puts row.join(" | ") }
        end

        display_date_summary(date_transactions)
      end

      display_detailed_summary(transactions)
    end

    def build_detailed_rows(transactions)
      transactions.map do |transaction|
        [
          format_date(transaction.transaction_date),
          transaction.symbol || "-",
          truncate(transaction.transaction_type, 12),
          truncate(transaction.action || transaction.transaction_sub_type, 12),
          format_quantity(transaction.quantity),
          format_currency(transaction.price),
          format_value(transaction.value, transaction.value_effect),
          format_fees(transaction),
          format_value(transaction.net_value, transaction.net_value_effect)
        ]
      end
    end

    def build_symbol_rows(transactions)
      transactions.map do |transaction|
        [
          format_date(transaction.transaction_date),
          truncate(transaction.transaction_type, 12),
          truncate(transaction.action || transaction.transaction_sub_type, 12),
          format_quantity(transaction.quantity),
          format_currency(transaction.price),
          format_value(transaction.value, transaction.value_effect),
          format_value(transaction.net_value, transaction.net_value_effect)
        ]
      end
    end

    def build_type_rows(transactions)
      transactions.map do |transaction|
        [
          format_date(transaction.transaction_date),
          transaction.symbol || "-",
          truncate(transaction.action || transaction.transaction_sub_type, 12),
          format_quantity(transaction.quantity),
          format_currency(transaction.price),
          format_value(transaction.value, transaction.value_effect),
          format_value(transaction.net_value, transaction.net_value_effect)
        ]
      end
    end

    def build_date_rows(transactions)
      transactions.map do |transaction|
        [
          transaction.symbol || "-",
          truncate(transaction.transaction_type, 12),
          truncate(transaction.action || transaction.transaction_sub_type, 12),
          format_quantity(transaction.quantity),
          format_currency(transaction.price),
          format_value(transaction.value, transaction.value_effect),
          format_value(transaction.net_value, transaction.net_value_effect)
        ]
      end
    end

    def format_date(date)
      return "-" unless date
      date.strftime("%m/%d/%y")
    end

    def format_quantity(quantity)
      return "-" unless quantity
      quantity.to_i.to_s
    end

    def format_currency(amount)
      return "-" unless amount
      "$#{"%.2f" % amount.to_f}"
    end

    def format_value(amount, effect)
      return "-" unless amount

      formatted = format_currency(amount.abs)

      if effect == "Debit" || (amount && amount < 0)
        @pastel.red("-#{formatted}")
      elsif effect == "Credit" || (amount && amount > 0)
        @pastel.green("+#{formatted}")
      else
        formatted
      end
    end

    def format_fees(transaction)
      total_fees = [
        transaction.commission,
        transaction.clearing_fees,
        transaction.regulatory_fees,
        transaction.proprietary_index_option_fees
      ].compact.reduce(BigDecimal("0"), :+)

      return "-" if total_fees.zero?
      format_currency(total_fees)
    end

    def truncate(text, length)
      return "-" unless text
      text.length > length ? "#{text[0...length - 2]}.." : text
    end

    def display_detailed_summary(transactions)
      total_credits = BigDecimal("0")
      total_debits = BigDecimal("0")
      total_fees = BigDecimal("0")

      transactions.each do |t|
        if t.value_effect == "Credit" || (t.value && t.value > 0)
          total_credits += t.value.abs if t.value
        elsif t.value_effect == "Debit" || (t.value && t.value < 0)
          total_debits += t.value.abs if t.value
        end

        total_fees += calculate_total_fees(t)
      end

      net_flow = total_credits - total_debits - total_fees

      puts
      puts @pastel.bold("Transaction Summary")
      puts "-" * 40
      puts "Total Transactions: #{transactions.size}"
      puts "Total Credits: #{@pastel.green(format_currency(total_credits))}"
      puts "Total Debits: #{@pastel.red(format_currency(total_debits))}"
      puts "Total Fees: #{@pastel.yellow(format_currency(total_fees))}"
      puts "Net Cash Flow: #{format_net_flow(net_flow)}"

      # Group by type for summary
      by_type = transactions.group_by(&:transaction_type)
      puts
      puts @pastel.bold("By Transaction Type:")
      by_type.each do |type, type_transactions|
        puts "  #{type}: #{type_transactions.size} transactions"
      end
    end

    def display_symbol_summary(transactions)
      total_value = transactions.sum { |t| t.net_value || BigDecimal("0") }
      puts @pastel.dim("\nSymbol Total: #{format_net_flow(total_value)} (#{transactions.size} transactions)")
    end

    def display_type_summary(transactions)
      total_value = transactions.sum { |t| t.net_value || BigDecimal("0") }
      puts @pastel.dim("\nType Total: #{format_net_flow(total_value)} (#{transactions.size} transactions)")
    end

    def display_date_summary(transactions)
      total_value = transactions.sum { |t| t.net_value || BigDecimal("0") }
      puts @pastel.dim("\nDaily Total: #{format_net_flow(total_value)} (#{transactions.size} transactions)")
    end

    def calculate_total_fees(transaction)
      [
        transaction.commission,
        transaction.clearing_fees,
        transaction.regulatory_fees,
        transaction.proprietary_index_option_fees
      ].compact.reduce(BigDecimal("0"), :+)
    end

    def format_net_flow(amount)
      formatted = format_currency(amount.abs)

      if amount > 0
        @pastel.green("+#{formatted}")
      elsif amount < 0
        @pastel.red("-#{formatted}")
      else
        formatted
      end
    end
  end
end
