# frozen_string_literal: true

require "faraday"
require "faraday/retry"
require "json"

module Tastytrade
  # HTTP client wrapper for Tastytrade API communication
  class Client
    attr_reader :base_url

    DEFAULT_TIMEOUT = 30

    def initialize(base_url:, timeout: DEFAULT_TIMEOUT)
      @base_url = base_url
      @timeout = timeout
    end

    def get(path, params = {}, headers = {})
      response = connection.get(path, params, default_headers.merge(headers))
      handle_response(response)
    rescue Faraday::ConnectionFailed => e
      raise Tastytrade::NetworkTimeoutError, "Request timed out: #{e.message}"
    end

    def post(path, body = {}, headers = {})
      response = connection.post(path, body.to_json, default_headers.merge(headers))
      handle_response(response)
    rescue Faraday::ConnectionFailed => e
      raise Tastytrade::NetworkTimeoutError, "Request timed out: #{e.message}"
    end

    def put(path, body = {}, headers = {})
      response = connection.put(path, body.to_json, default_headers.merge(headers))
      handle_response(response)
    rescue Faraday::ConnectionFailed => e
      raise Tastytrade::NetworkTimeoutError, "Request timed out: #{e.message}"
    end

    def delete(path, headers = {})
      response = connection.delete(path, nil, default_headers.merge(headers))
      handle_response(response)
    rescue Faraday::ConnectionFailed => e
      raise Tastytrade::NetworkTimeoutError, "Request timed out: #{e.message}"
    end

    private

    def connection
      @connection ||= Faraday.new(url: base_url) do |faraday|
        faraday.request :retry, max: 2, interval: 0.5,
                                retry_statuses: [429, 503, 504],
                                methods: %i[get put delete]
        faraday.options.timeout = @timeout
        faraday.options.open_timeout = @timeout
        faraday.adapter Faraday.default_adapter
      end
    end

    def default_headers
      {
        "Accept" => "application/json",
        "Content-Type" => "application/json"
      }
    end

    def handle_response(response)
      return handle_success(response) if (200..299).cover?(response.status)

      handle_error(response)
    end

    def handle_success(response)
      return nil if response.body.nil? || response.body.empty?

      # API returns data in a 'data' field for most endpoints
      parse_json(response.body)
    end

    def handle_error(response)
      error_details = parse_error_message(response)

      case response.status
      when 401
        raise Tastytrade::InvalidCredentialsError, "Authentication failed: #{error_details}"
      when 403
        raise Tastytrade::SessionExpiredError, "Session expired or invalid: #{error_details}"
      when 404
        raise Tastytrade::Error, "Resource not found: #{error_details}"
      when 429
        raise Tastytrade::Error, "Rate limit exceeded: #{error_details}"
      when 400..499
        raise Tastytrade::Error, "Client error: #{error_details}"
      when 500..599
        raise Tastytrade::Error, "Server error: #{error_details}"
      else
        raise Tastytrade::Error, "Unexpected response: #{error_details}"
      end
    end

    def parse_json(body)
      JSON.parse(body)
    rescue JSON::ParserError => e
      raise Tastytrade::Error, "Invalid JSON response: #{e.message}"
    end

    def parse_error_message(response)
      return response.status.to_s if response.body.nil? || response.body.empty?

      data = parse_json(response.body)

      # Handle preflight check failures with detailed errors
      if data["code"] == "preflight_check_failure" && data["errors"]
        error_details = data["errors"].map { |e| e["message"] }.join(", ")
        return "#{data["message"]}: #{error_details}"
      end

      # Handle both old and new API error formats
      data["error"] || data["message"] || data["reason"] || response.status.to_s
    rescue StandardError
      response.status.to_s
    end
  end
end
