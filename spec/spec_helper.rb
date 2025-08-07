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

VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!

  # Filter out sensitive data
  config.filter_sensitive_data("<AUTH_TOKEN>") do |interaction|
    if interaction.request.headers["Authorization"]
      interaction.request.headers["Authorization"].first
    end
  end

  config.filter_sensitive_data("<SESSION_TOKEN>") do |interaction|
    if interaction.response.headers["Content-Type"] &&
       interaction.response.headers["Content-Type"].first.include?("application/json")
      begin
        body = JSON.parse(interaction.response.body)
        body.dig("data", "session-token") || body.dig("data", "session_token")
      rescue JSON::ParserError
        nil
      end
    end
  end

  config.filter_sensitive_data("<ACCOUNT_NUMBER>") do |interaction|
    # Filter account numbers from URLs
    interaction.request.uri.match(%r{/accounts/([^/]+)})&.captures&.first
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
  config.filter_sensitive_data("<EMAIL>") do |interaction|
    if interaction.response.body
      begin
        body = JSON.parse(interaction.response.body)
        body.dig("data", "email")
      rescue JSON::ParserError
        nil
      end
    end
  end

  # Default cassette options
  config.default_cassette_options = {
    record: :new_episodes,
    match_requests_on: [:method, :uri, :body],
    allow_playback_repeats: true
  }
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

end
