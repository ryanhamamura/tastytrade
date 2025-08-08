# frozen_string_literal: true

# Helper methods for testing order placement with automatic cleanup
module OrderTestHelper
  # Creates a test order and ensures cleanup after the block executes
  # This ensures tests remain idempotent and don't pollute the sandbox
  #
  # @param session [Tastytrade::Session] Active session
  # @param account [Tastytrade::Models::Account] Account to place order on
  # @param order_params [Tastytrade::Order] Order to place (or use default)
  # @yield [Tastytrade::Models::OrderResponse] The placed order for testing
  def with_test_order(session, account, order_params = nil)
    order_params ||= default_test_order
    order_response = nil

    begin
      # Place the order
      order_response = account.place_order(session, order_params, skip_validation: true)

      # Yield to the test block
      yield order_response if block_given?
    ensure
      # Always attempt cleanup if we have an order
      if order_response && order_response.order_id
        begin
          # Check if order is still cancellable
          live_order = account.get_order(session, order_response.order_id)

          # Only cancel if order is in a cancellable state
          if cancellable_status?(live_order.status)
            account.cancel_order(session, order_response.order_id)
          end
        rescue Tastytrade::Error => e
          # Log but don't fail the test if cleanup fails
          # Order might already be filled or expired
          puts "Order cleanup warning: #{e.message}" if ENV["DEBUG"]
        end
      end
    end
  end

  # Creates multiple test orders for testing batch operations
  def with_test_orders(session, account, count = 2)
    orders = []

    begin
      count.times do |i|
        order = default_test_order(index: i)
        order_response = account.place_order(session, order, skip_validation: true)
        orders << order_response
      end

      yield orders if block_given?
    ensure
      # Cleanup all orders
      orders.each do |order_response|
        begin
          if order_response && order_response.order_id
            live_order = account.get_order(session, order_response.order_id)
            if cancellable_status?(live_order.status)
              account.cancel_order(session, order_response.order_id)
            end
          end
        rescue Tastytrade::Error => e
          puts "Order cleanup warning: #{e.message}" if ENV["DEBUG"]
        end
      end
    end
  end

  private

  # Default test order - a far OTM SPY option that's unlikely to fill
  def default_test_order(index: 0)
    # Use a far OTM SPY option for testing
    # This ensures the order won't accidentally fill during tests
    symbol = test_option_symbol(index: index)

    leg = Tastytrade::OrderLeg.new(
      action: Tastytrade::OrderAction::BUY_TO_OPEN,
      symbol: symbol,
      quantity: 1
    )

    Tastytrade::Order.new(
      type: Tastytrade::OrderType::LIMIT,
      legs: leg,
      price: 0.01,  # Very low price to avoid fills
      time_in_force: Tastytrade::OrderTimeInForce::DAY
    )
  end

  # Generate a test option symbol
  # Uses SPY options expiring 30+ days out
  def test_option_symbol(index: 0)
    # Calculate expiration date (30+ days from now)
    expiry = (Date.today + 35).strftime("%y%m%d")

    # Use different strikes for different test orders
    strike = 300 + (index * 5)  # Far OTM for SPY

    "SPY   #{expiry}P00#{strike}000"
  end

  # Check if an order status is cancellable
  def cancellable_status?(status)
    %w[
      RECEIVED
      ROUTED
      WORKING
      PARTIALLY_FILLED
      CONTINGENT
    ].include?(status.to_s.upcase)
  end

  # Helper to create a market order for testing immediate fills
  def market_test_order
    leg = Tastytrade::OrderLeg.new(
      action: Tastytrade::OrderAction::BUY_TO_OPEN,
      symbol: "SPY",
      quantity: 1
    )

    Tastytrade::Order.new(
      type: Tastytrade::OrderType::MARKET,
      legs: leg,
      time_in_force: Tastytrade::OrderTimeInForce::DAY
    )
  end

  # Helper to create a limit order with specific price
  def limit_test_order(symbol: "SPY", quantity: 1, price: 400.00)
    leg = Tastytrade::OrderLeg.new(
      action: Tastytrade::OrderAction::BUY_TO_OPEN,
      symbol: symbol,
      quantity: quantity
    )

    Tastytrade::Order.new(
      type: Tastytrade::OrderType::LIMIT,
      legs: leg,
      price: price,
      time_in_force: Tastytrade::OrderTimeInForce::DAY
    )
  end
end

# Include in RSpec configuration
RSpec.configure do |config|
  config.include OrderTestHelper
end
