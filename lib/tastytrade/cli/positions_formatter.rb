# frozen_string_literal: true

require "tty-table"
require "bigdecimal"

module Tastytrade
  # Formatter for displaying positions in various formats
  class PositionsFormatter
    def initialize(pastel: nil)
      @pastel = pastel || Pastel.new
    end

      # Format positions as a table
    def format_table(positions)
      return if positions.empty?

      headers = ["Symbol", "Quantity", "Type", "Avg Price", "Current Price", "P/L", "P/L %"]
      rows = build_table_rows(positions)

      table = TTY::Table.new(headers, rows)

      begin
        puts table.render(:unicode, padding: [0, 1])
      rescue StandardError
        # Fallback for testing or non-TTY environments
        puts headers.join(" | ")
        puts "-" * 80
        rows.each { |row| puts row.join(" | ") }
      end

      display_summary(positions)
    end

      private

    def build_table_rows(positions)
      positions.map do |position|
        [
          format_symbol(position),
          format_quantity(position),
          position.instrument_type,
          format_currency(position.average_open_price),
          format_currency(position.close_price || BigDecimal("0")),
          format_pl(position.unrealized_pnl),
          format_pl_percentage(position.unrealized_pnl_percentage)
        ]
      end
    end

    def format_symbol(position)
      if position.option?
        position.display_symbol
      else
        position.symbol
      end
    end

    def format_quantity(position)
      quantity = position.quantity.to_i
      if position.short?
        "-#{quantity}"
      else
        quantity.to_s
      end
    end

    def format_currency(amount)
      return "$0.00" unless amount

      formatted = "$#{"%.2f" % amount.to_f}"
      formatted = "-#{formatted}" if amount < 0
      formatted
    end

    def format_pl(amount)
      return "$0.00" unless amount

      formatted = format_currency(amount.abs)

      if amount > 0
        @pastel.green("+#{formatted}")
      elsif amount < 0
        @pastel.red("-#{formatted}")
      else
        formatted
      end
    end

    def format_pl_percentage(percentage)
      return "0.00%" unless percentage

      formatted = "#{"%.2f" % percentage.to_f}%"

      if percentage > 0
        @pastel.green("+#{formatted}")
      elsif percentage < 0
        @pastel.red(formatted.to_s)
      else
        formatted
      end
    end

    def display_summary(positions)
      total_pl = positions.sum { |p| p.unrealized_pnl || BigDecimal("0") }
      winners = positions.count { |p| p.unrealized_pnl && p.unrealized_pnl > 0 }
      losers = positions.count { |p| p.unrealized_pnl && p.unrealized_pnl < 0 }

      puts
      summary = "Summary: #{positions.size} positions | Total P/L: #{format_pl(total_pl)} | "
      summary += "Winners: #{winners}, Losers: #{losers}"
      puts @pastel.dim(summary)
    end
  end
end
