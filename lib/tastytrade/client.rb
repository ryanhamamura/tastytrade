# frozen_string_literal: true

require "faraday"
require "faraday/retry"
require "json"

module Tastytrade
  # HTTP client wrapper for Tastytrade API communication
  class Client
    attr_reader :base_url

    def initialize(base_url:)
      @base_url = base_url
    end

    def get(path, params = {}, headers = {})
      response = connection.get(path, params, default_headers.merge(headers))
      handle_response(response)
    end

    def post(path, body = {}, headers = {})
      response = connection.post(path, body.to_json, default_headers.merge(headers))
      handle_response(response)
    end

    def put(path, body = {}, headers = {})
      response = connection.put(path, body.to_json, default_headers.merge(headers))
      handle_response(response)
    end

    def delete(path, headers = {})
      response = connection.delete(path, nil, default_headers.merge(headers))
      handle_response(response)
    end

    private

    def connection
      @connection ||= Faraday.new(url: base_url) do |faraday|
        faraday.request :retry, max: 2, interval: 0.5,
                                retry_statuses: [429, 503, 504],
                                methods: %i[get put delete]
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
      error_message = case response.status
                      when 401 then "Authentication failed"
                      when 404 then "Resource not found"
                      when 400..499 then "Client error"
                      when 500..599 then "Server error"
                      else "Unexpected response"
                      end

      raise Tastytrade::Error, "#{error_message}: #{parse_error_message(response)}"
    end

    def parse_json(body)
      JSON.parse(body)
    rescue JSON::ParserError => e
      raise Tastytrade::Error, "Invalid JSON response: #{e.message}"
    end

    def parse_error_message(response)
      return response.status.to_s if response.body.nil? || response.body.empty?

      data = parse_json(response.body)
      # Handle both old and new API error formats
      data["error"] || data["message"] || data["reason"] || response.status.to_s
    rescue StandardError
      response.status.to_s
    end
  end
end
