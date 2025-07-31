# frozen_string_literal: true

# Unofficial Ruby SDK for Tastytrade API
#
# IMPORTANT DISCLAIMER:
# This is an unofficial SDK and is not affiliated with, endorsed by, or
# sponsored by Tastytrade, Tastyworks, or any of their affiliates.
#
# Trading financial instruments involves substantial risk and may result in
# loss of capital. This software is provided for educational purposes only.
# Always consult with a qualified financial advisor before making investment decisions.

require_relative "tastytrade/version"
require_relative "tastytrade/client"
require_relative "tastytrade/models"
require_relative "tastytrade/session"

module Tastytrade
  class Error < StandardError; end

  # Authentication errors
  class AuthenticationError < Error; end
  class SessionExpiredError < AuthenticationError; end
  class TokenRefreshError < AuthenticationError; end
  class InvalidCredentialsError < AuthenticationError; end
  class NetworkTimeoutError < Error; end

  # API URLs
  API_URL = "https://api.tastyworks.com"
  CERT_URL = "https://api.cert.tastyworks.com"
end
