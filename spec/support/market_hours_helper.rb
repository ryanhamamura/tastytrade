# frozen_string_literal: true

# Helper module for handling market hours constraints in VCR tests
module MarketHoursHelper
  # US stock market hours in Eastern Time
  MARKET_OPEN_HOUR = 9
  MARKET_OPEN_MINUTE = 30
  MARKET_CLOSE_HOUR = 16
  MARKET_CLOSE_MINUTE = 0

  # Check if the market is currently open
  # @param time [Time] the time to check (defaults to current time)
  # @return [Boolean] true if market is open, false otherwise
  def market_open?(time = Time.now)
    # Convert to Eastern Time
    require "time"
    et_offset = time.dst? ? -4 : -5 # EDT or EST
    et_time = time.getlocal(et_offset * 3600)

    # Market is closed on weekends
    return false if et_time.saturday? || et_time.sunday?

    # Check if within market hours
    market_open = Time.new(et_time.year, et_time.month, et_time.day,
                           MARKET_OPEN_HOUR, MARKET_OPEN_MINUTE, 0, et_offset * 3600)
    market_close = Time.new(et_time.year, et_time.month, et_time.day,
                            MARKET_CLOSE_HOUR, MARKET_CLOSE_MINUTE, 0, et_offset * 3600)

    et_time >= market_open && et_time < market_close
  end

  # Wrapper for tests that require market hours
  # @param cassette_name [String] name of the VCR cassette
  # @param options [Hash] additional VCR options
  # @yield the test code to execute
  def with_market_hours_check(cassette_name = nil, **options)
    # If we're using an existing cassette, just run the test
    if VCR.current_cassette || File.exist?(cassette_path_for(cassette_name))
      yield
      return
    end

    # If recording mode is enabled and market is open, record new cassette
    if ENV["VCR_MODE"] =~ /rec/i && market_open?
      if cassette_name
        VCR.use_cassette(cassette_name, { record: :new_episodes }.merge(options)) do
          yield
        end
      else
        yield
      end
      return
    end

    # Otherwise, skip the test with informative message
    if market_open?
      skip "No existing cassette found. Set VCR_MODE=record to record new cassettes."
    else
      skip "Market is closed. Tests requiring live API calls can only run during market hours (9:30 AM - 4:00 PM ET, Mon-Fri)."
    end
  end

  # Get next market open time
  # @param from_time [Time] calculate from this time (defaults to now)
  # @return [Time] the next market open time
  def next_market_open(from_time = Time.now)
    et_offset = from_time.dst? ? -4 : -5
    et_time = from_time.getlocal(et_offset * 3600)

    # Start with today's market open
    next_open = Time.new(et_time.year, et_time.month, et_time.day,
                         MARKET_OPEN_HOUR, MARKET_OPEN_MINUTE, 0, et_offset * 3600)

    # If it's already past today's open, move to tomorrow
    if et_time >= next_open
      next_open += 86400 # Add one day
    end

    # Skip weekends
    while next_open.saturday? || next_open.sunday?
      next_open += 86400
    end

    next_open
  end

  # Time until market opens
  # @return [String] human-readable time until market opens
  def time_until_market_open
    if market_open?
      "Market is currently open"
    else
      seconds = next_market_open - Time.now
      hours = (seconds / 3600).to_i
      minutes = ((seconds % 3600) / 60).to_i

      if hours > 24
        days = hours / 24
        "#{days} day#{"s" if days > 1} #{hours % 24} hour#{"s" if (hours % 24) != 1}"
      elsif hours > 0
        "#{hours} hour#{"s" if hours > 1} #{minutes} minute#{"s" if minutes != 1}"
      else
        "#{minutes} minute#{"s" if minutes != 1}"
      end
    end
  end

  private

  # Get the expected path for a cassette
  def cassette_path_for(cassette_name)
    return nil unless cassette_name

    cassette_dir = VCR.configuration.cassette_library_dir
    "#{cassette_dir}/#{cassette_name}.yml"
  end
end
