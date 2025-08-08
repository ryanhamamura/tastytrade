# frozen_string_literal: true

module Tastytrade
  module RubyVersionCheck
    MINIMUM_RUBY_VERSION = "3.0.0"
    RECOMMENDED_RUBY_VERSION = "3.2.0"

    def self.check!
      current = RUBY_VERSION
      minimum = Gem::Version.new(MINIMUM_RUBY_VERSION)
      recommended = Gem::Version.new(RECOMMENDED_RUBY_VERSION)
      current_version = Gem::Version.new(current)

      if current_version < minimum
        raise RuntimeError, <<~ERROR
          Tastytrade requires Ruby #{MINIMUM_RUBY_VERSION} or higher.
          You're running Ruby #{current}.
          Please upgrade Ruby to continue.
        ERROR
      elsif current_version < recommended
        warn <<~WARNING
          ⚠️  You're running Ruby #{current}.
          While Tastytrade supports Ruby #{MINIMUM_RUBY_VERSION}+, we recommend Ruby #{RECOMMENDED_RUBY_VERSION}+ for best performance.
        WARNING
      end
    end

    def self.version_info
      {
        current: RUBY_VERSION,
        minimum: MINIMUM_RUBY_VERSION,
        recommended: RECOMMENDED_RUBY_VERSION,
        compatible: Gem::Version.new(RUBY_VERSION) >= Gem::Version.new(MINIMUM_RUBY_VERSION)
      }
    end
  end
end
