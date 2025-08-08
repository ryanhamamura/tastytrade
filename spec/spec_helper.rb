# frozen_string_literal: true

unless ENV["DISABLE_SIMPLECOV"]
  require "simplecov"
  SimpleCov.start do
    add_filter "/spec/"
    add_filter "/bin/"
  end
end

require "bundler/setup"
require "tastytrade"
require "webmock/rspec"
require "vcr"
require "dotenv"

# Load test environment variables
Dotenv.load(".env.test") if File.exist?(".env.test")

VCR.configure do |config|
  config.cassette_library_dir = ENV.fetch("VCR_CASSETTE_DIR", "spec/fixtures/vcr_cassettes")
  config.hook_into :webmock
  config.configure_rspec_metadata!

  # Determine recording mode based on environment
  vcr_mode = if ENV["VCR_MODE"] =~ /rec/i
    :all # Re-record all requests
  elsif ENV["CI"]
    :none # Never record in CI, only use existing cassettes
  else
    :once # Record once, then use cassette
  end

  # Enhanced sensitive data filtering
  # Filter sandbox credentials from environment variables
  config.filter_sensitive_data("<SANDBOX_USERNAME>") { ENV["TASTYTRADE_SANDBOX_USERNAME"] }
  config.filter_sensitive_data("<SANDBOX_PASSWORD>") { ENV["TASTYTRADE_SANDBOX_PASSWORD"] }
  config.filter_sensitive_data("<SANDBOX_ACCOUNT>") { ENV["TASTYTRADE_SANDBOX_ACCOUNT"] }

  # Filter out sensitive data from requests/responses
  config.filter_sensitive_data("<AUTH_TOKEN>") do |interaction|
    auth_header = interaction.request.headers["Authorization"]
    auth_header&.first if auth_header
  end

  config.filter_sensitive_data("<SESSION_TOKEN>") do |interaction|
    content_type = interaction.response.headers["Content-Type"]
    if content_type&.first&.include?("application/json")
      begin
        body = JSON.parse(interaction.response.body)
        body.dig("data", "session-token") ||
        body.dig("data", "session_token") ||
        body.dig("data", "attributes", "session-token")
      rescue JSON::ParserError
        nil
      end
    end
  end

  # Filter remember tokens
  config.filter_sensitive_data("<REMEMBER_TOKEN>") do |interaction|
    content_type = interaction.response.headers["Content-Type"]
    if content_type&.first&.include?("application/json")
      begin
        body = JSON.parse(interaction.response.body)
        body.dig("data", "remember-token") ||
        body.dig("data", "remember_token")
      rescue JSON::ParserError
        nil
      end
    end
  end

  # Use before_record hook to sanitize URIs instead of filter_sensitive_data
  config.before_record do |interaction|
    # Replace account numbers in URIs with a placeholder that forms a valid URI
    if match = interaction.request.uri.match(%r{(/accounts/)([^/]+)(/?.*)}i)
      prefix, account_number, suffix = match.captures
      interaction.request.uri = interaction.request.uri.gsub(
        %r{/accounts/[^/]+},
        "/accounts/ACCOUNT_NUMBER_PLACEHOLDER"
      )
    end

    # Also filter from response bodies
    if interaction.response.body
      account_number = interaction.request.uri.match(%r{/accounts/([^/]+)})&.captures&.first
      if account_number
        interaction.response.body = interaction.response.body.gsub(account_number, "ACCOUNT_NUMBER_PLACEHOLDER")
      end
    end
  end

  # Mirror the transformation for playback
  config.before_playback do |interaction|
    # During playback, replace placeholder with actual account number if available
    account_number = ENV["TASTYTRADE_SANDBOX_ACCOUNT"]
    if account_number && interaction.request.uri.include?("ACCOUNT_NUMBER_PLACEHOLDER")
      interaction.request.uri = interaction.request.uri.gsub(
        "ACCOUNT_NUMBER_PLACEHOLDER",
        account_number
      )
    end

    # Also replace in response bodies
    if account_number && interaction.response.body&.include?("ACCOUNT_NUMBER_PLACEHOLDER")
      interaction.response.body = interaction.response.body.gsub(
        "ACCOUNT_NUMBER_PLACEHOLDER",
        account_number
      )
    end
  end

  config.filter_sensitive_data("<USERNAME>") do |interaction|
    if interaction.request.body && interaction.request.body.include?("username")
      begin
        body = JSON.parse(interaction.request.body)
        body["username"]
      rescue JSON::ParserError
        nil
      end
    end
  end

  config.filter_sensitive_data("<PASSWORD>") do |interaction|
    if interaction.request.body && interaction.request.body.include?("password")
      begin
        body = JSON.parse(interaction.request.body)
        body["password"]
      rescue JSON::ParserError
        nil
      end
    end
  end

  # Filter personal information from response bodies
  config.filter_sensitive_data("<SANDBOX_USERNAME>") do |interaction|
    if interaction.response.body
      begin
        body = JSON.parse(interaction.response.body)
        body.dig("data", "email")
      rescue JSON::ParserError
        nil
      end
    end
  end

  # Custom request matching for dynamic content
  config.register_request_matcher :uri_without_timestamp do |request_1, request_2|
    uri_1 = URI(request_1.uri)
    uri_2 = URI(request_2.uri)

    # Remove timestamp parameters for matching
    params_1 = CGI.parse(uri_1.query || "")
    params_2 = CGI.parse(uri_2.query || "")

    params_1.delete("timestamp")
    params_2.delete("timestamp")
    params_1.delete("_")
    params_2.delete("_")

    uri_1.query = URI.encode_www_form(params_1)
    uri_2.query = URI.encode_www_form(params_2)

    uri_1.to_s == uri_2.to_s
  end

  # Custom request matcher for account number normalization
  config.register_request_matcher :uri_with_normalized_accounts do |request_1, request_2|
    # Helper to normalize account URIs for comparison
    normalize_uri = lambda do |uri_string|
      uri_string.gsub(%r{/accounts/[^/]+}, "/accounts/ACCOUNT_NUMBER_PLACEHOLDER")
    end

    uri_1 = normalize_uri.call(request_1.uri)
    uri_2 = normalize_uri.call(request_2.uri)
    uri_1 == uri_2
  end

  # Default cassette options
  config.default_cassette_options = {
    record: vcr_mode,
    match_requests_on: [:method, :uri_with_normalized_accounts, :uri_without_timestamp, :body],
    allow_playback_repeats: true,
    serialize_with: :yaml,
    preserve_exact_body_bytes: true,
    decode_compressed_response: true
  }
end

# Load support files
Dir[File.join(__dir__, "support", "**", "*.rb")].sort.each { |f| require f }

RSpec.configure do |config|
  # Include helper modules
  config.include MarketHoursHelper if defined?(MarketHoursHelper)
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

end
