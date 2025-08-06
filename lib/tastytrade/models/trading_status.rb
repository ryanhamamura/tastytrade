# frozen_string_literal: true

require "bigdecimal"
require "date"

module Tastytrade
  module Models
    # Represents the trading status and permissions for an account
    #
    # @attr_reader [String] account_number The account number
    # @attr_reader [String] equities_margin_calculation_type Type of margin calculation for equities
    # @attr_reader [String] fee_schedule_name Fee schedule applied to the account
    # @attr_reader [BigDecimal] futures_margin_rate_multiplier Margin rate multiplier for futures
    # @attr_reader [Boolean] has_intraday_equities_margin Whether intraday equities margin is enabled
    # @attr_reader [Integer] id Trading status record ID
    # @attr_reader [Boolean] is_aggregated_at_clearing Whether account is aggregated at clearing
    # @attr_reader [Boolean] is_closed Whether the account is closed
    # @attr_reader [Boolean] is_closing_only Whether account is restricted to closing trades only
    # @attr_reader [Boolean] is_cryptocurrency_enabled Whether cryptocurrency trading is enabled
    # @attr_reader [Boolean] is_frozen Whether the account is frozen
    # @attr_reader [Boolean] is_full_equity_margin_required Whether full equity margin is required
    # @attr_reader [Boolean] is_futures_closing_only Whether futures are restricted to closing only
    # @attr_reader [Boolean] is_futures_intra_day_enabled Whether intraday futures trading is enabled
    # @attr_reader [Boolean] is_futures_enabled Whether futures trading is enabled
    # @attr_reader [Boolean] is_in_day_trade_equity_maintenance_call Whether account is in day trade equity
    #   maintenance call
    # @attr_reader [Boolean] is_in_margin_call Whether account is in margin call
    # @attr_reader [Boolean] is_pattern_day_trader Whether account is flagged as pattern day trader
    # @attr_reader [Boolean] is_small_notional_futures_intra_day_enabled Whether small notional futures
    #   intraday is enabled
    # @attr_reader [Boolean] is_roll_the_day_forward_enabled Whether roll the day forward is enabled
    # @attr_reader [Boolean] are_far_otm_net_options_restricted Whether far OTM net options are restricted
    # @attr_reader [String] options_level Options trading permission level
    # @attr_reader [Boolean] short_calls_enabled Whether short calls are enabled
    # @attr_reader [BigDecimal] small_notional_futures_margin_rate_multiplier Margin rate multiplier for
    #   small notional futures
    # @attr_reader [Boolean] is_equity_offering_enabled Whether equity offerings are enabled
    # @attr_reader [Boolean] is_equity_offering_closing_only Whether equity offerings are closing only
    # @attr_reader [Time] updated_at When the trading status was last updated
    # @attr_reader [Boolean, nil] is_portfolio_margin_enabled Whether portfolio margin is enabled (optional)
    # @attr_reader [Boolean, nil] is_risk_reducing_only Whether only risk-reducing trades are allowed (optional)
    # @attr_reader [Integer, nil] day_trade_count Current day trade count (optional)
    # @attr_reader [String, nil] autotrade_account_type Type of autotrade account (optional)
    # @attr_reader [String, nil] clearing_account_number Clearing account number (optional)
    # @attr_reader [String, nil] clearing_aggregation_identifier Clearing aggregation identifier (optional)
    # @attr_reader [Boolean, nil] is_cryptocurrency_closing_only Whether crypto is closing only (optional)
    # @attr_reader [Date, nil] pdt_reset_on Date when PDT flag will reset (optional)
    # @attr_reader [Integer, nil] cmta_override CMTA override value (optional)
    # @attr_reader [Time, nil] enhanced_fraud_safeguards_enabled_at When enhanced fraud safeguards were
    #   enabled (optional)
    class TradingStatus < Base
      attr_reader :account_number, :equities_margin_calculation_type, :fee_schedule_name,
                  :futures_margin_rate_multiplier, :has_intraday_equities_margin, :id,
                  :is_aggregated_at_clearing, :is_closed, :is_closing_only,
                  :is_cryptocurrency_enabled, :is_frozen, :is_full_equity_margin_required,
                  :is_futures_closing_only, :is_futures_intra_day_enabled, :is_futures_enabled,
                  :is_in_day_trade_equity_maintenance_call, :is_in_margin_call,
                  :is_pattern_day_trader, :is_small_notional_futures_intra_day_enabled,
                  :is_roll_the_day_forward_enabled, :are_far_otm_net_options_restricted,
                  :options_level, :short_calls_enabled,
                  :small_notional_futures_margin_rate_multiplier,
                  :is_equity_offering_enabled, :is_equity_offering_closing_only,
                  :updated_at, :is_portfolio_margin_enabled, :is_risk_reducing_only,
                  :day_trade_count, :autotrade_account_type, :clearing_account_number,
                  :clearing_aggregation_identifier, :is_cryptocurrency_closing_only,
                  :pdt_reset_on, :cmta_override, :enhanced_fraud_safeguards_enabled_at

      # Check if account can trade options at any level
      #
      # @return [Boolean] true if options trading is enabled
      def can_trade_options?
        !options_level.nil? && options_level != "No Permissions"
      end

      # Check if account can trade futures
      #
      # @return [Boolean] true if futures trading is enabled and not closing only
      def can_trade_futures?
        is_futures_enabled && !is_futures_closing_only
      end

      # Check if account can trade cryptocurrency
      #
      # @return [Boolean] true if crypto trading is enabled and not closing only
      def can_trade_cryptocurrency?
        is_cryptocurrency_enabled && !is_cryptocurrency_closing_only
      end

      # Check if account has any trading restrictions
      #
      # @return [Boolean] true if account has restrictions
      def restricted?
        is_closed || is_frozen || is_closing_only || is_in_margin_call ||
          is_in_day_trade_equity_maintenance_call || is_risk_reducing_only == true
      end

      # Get a list of active restrictions
      #
      # @return [Array<String>] list of active restrictions
      def active_restrictions
        restrictions = []
        restrictions << "Account Closed" if is_closed
        restrictions << "Account Frozen" if is_frozen
        restrictions << "Closing Only" if is_closing_only
        restrictions << "Margin Call" if is_in_margin_call
        restrictions << "Day Trade Equity Maintenance Call" if is_in_day_trade_equity_maintenance_call
        restrictions << "Risk Reducing Only" if is_risk_reducing_only
        restrictions << "Pattern Day Trader" if is_pattern_day_trader
        restrictions << "Futures Closing Only" if is_futures_closing_only
        restrictions << "Cryptocurrency Closing Only" if is_cryptocurrency_closing_only
        restrictions << "Equity Offering Closing Only" if is_equity_offering_closing_only
        restrictions << "Far OTM Net Options Restricted" if are_far_otm_net_options_restricted
        restrictions
      end

      # Get trading permissions summary
      #
      # @return [Hash] summary of trading permissions
      def permissions_summary
        {
          options: can_trade_options? ? options_level : "Disabled",
          futures: can_trade_futures? ? "Enabled" : (is_futures_enabled ? "Closing Only" : "Disabled"),
          cryptocurrency: crypto_status,
          short_calls: short_calls_enabled ? "Enabled" : "Disabled",
          pattern_day_trader: is_pattern_day_trader ? "Yes" : "No",
          portfolio_margin: is_portfolio_margin_enabled ? "Enabled" : "Disabled"
        }
      end

      def crypto_status
        if can_trade_cryptocurrency?
          "Enabled"
        elsif is_cryptocurrency_enabled
          "Closing Only"
        else
          "Disabled"
        end
      end

      private

      def parse_attributes
        @account_number = @data["account-number"]
        @equities_margin_calculation_type = @data["equities-margin-calculation-type"]
        @fee_schedule_name = @data["fee-schedule-name"]
        @futures_margin_rate_multiplier = parse_decimal(@data["futures-margin-rate-multiplier"])
        @has_intraday_equities_margin = @data["has-intraday-equities-margin"]
        @id = @data["id"]
        @is_aggregated_at_clearing = @data["is-aggregated-at-clearing"]
        @is_closed = @data["is-closed"]
        @is_closing_only = @data["is-closing-only"]
        @is_cryptocurrency_enabled = @data["is-cryptocurrency-enabled"]
        @is_frozen = @data["is-frozen"]
        @is_full_equity_margin_required = @data["is-full-equity-margin-required"]
        @is_futures_closing_only = @data["is-futures-closing-only"]
        @is_futures_intra_day_enabled = @data["is-futures-intra-day-enabled"]
        @is_futures_enabled = @data["is-futures-enabled"]
        @is_in_day_trade_equity_maintenance_call = @data["is-in-day-trade-equity-maintenance-call"]
        @is_in_margin_call = @data["is-in-margin-call"]
        @is_pattern_day_trader = @data["is-pattern-day-trader"]
        @is_small_notional_futures_intra_day_enabled = @data["is-small-notional-futures-intra-day-enabled"]
        @is_roll_the_day_forward_enabled = @data["is-roll-the-day-forward-enabled"]
        @are_far_otm_net_options_restricted = @data["are-far-otm-net-options-restricted"]
        @options_level = @data["options-level"]
        @short_calls_enabled = @data["short-calls-enabled"]
        @small_notional_futures_margin_rate_multiplier =
          parse_decimal(@data["small-notional-futures-margin-rate-multiplier"])
        @is_equity_offering_enabled = @data["is-equity-offering-enabled"]
        @is_equity_offering_closing_only = @data["is-equity-offering-closing-only"]
        @updated_at = parse_time(@data["updated-at"])

        # Optional fields
        @is_portfolio_margin_enabled = @data["is-portfolio-margin-enabled"]
        @is_risk_reducing_only = @data["is-risk-reducing-only"]
        @day_trade_count = @data["day-trade-count"]
        @autotrade_account_type = @data["autotrade-account-type"]
        @clearing_account_number = @data["clearing-account-number"]
        @clearing_aggregation_identifier = @data["clearing-aggregation-identifier"]
        @is_cryptocurrency_closing_only = @data["is-cryptocurrency-closing-only"]
        @pdt_reset_on = parse_date(@data["pdt-reset-on"]) if @data["pdt-reset-on"]
        @cmta_override = @data["cmta-override"]
        @enhanced_fraud_safeguards_enabled_at = parse_time(@data["enhanced-fraud-safeguards-enabled-at"])
      end

      def parse_date(date_string)
        return nil if date_string.nil?

        Date.parse(date_string)
      rescue ArgumentError
        nil
      end

      def parse_decimal(value)
        return nil if value.nil? || value.to_s.empty?

        BigDecimal(value.to_s)
      end
    end
  end
end
