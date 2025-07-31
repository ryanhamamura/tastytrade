# frozen_string_literal: true

require "yaml"
require "fileutils"

module Tastytrade
  # Configuration management for Tastytrade CLI
  class CLIConfig
    CONFIG_DIR = File.expand_path("~/.config/tastytrade")
    CONFIG_FILE = File.join(CONFIG_DIR, "config.yml")

    DEFAULT_CONFIG = {
      "default_account" => nil,
      "environment" => "production",
      "auto_refresh" => true
    }.freeze

    attr_reader :data

    def initialize
      @data = load_config
    end

    # Get a configuration value
    def get(key)
      @data[key.to_s]
    end

    # Set a configuration value
    def set(key, value)
      @data[key.to_s] = value
      save_config
    end

    # Delete a configuration value
    def delete(key)
      @data.delete(key.to_s)
      save_config
    end

    # Check if config exists
    def exists?
      File.exist?(CONFIG_FILE)
    end

    # Reset to defaults
    def reset!
      @data = DEFAULT_CONFIG.dup
      save_config
    end

    private

    def load_config
      ensure_config_dir_exists
      return DEFAULT_CONFIG.dup unless File.exist?(CONFIG_FILE)

      begin
        config = YAML.load_file(CONFIG_FILE)
        # Ensure we have a hash and merge with defaults
        DEFAULT_CONFIG.merge(config.is_a?(Hash) ? config : {})
      rescue StandardError => e
        warn "Warning: Failed to load config file: #{e.message}"
        DEFAULT_CONFIG.dup
      end
    end

    def save_config
      ensure_config_dir_exists
      File.write(CONFIG_FILE, @data.to_yaml)
    rescue StandardError => e
      warn "Warning: Failed to save config file: #{e.message}"
    end

    def ensure_config_dir_exists
      FileUtils.mkdir_p(CONFIG_DIR)
    end
  end
end
