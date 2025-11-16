#!/usr/bin/env ruby

# Simple .env file loader
# Loads environment variables from .env file if it exists
# Usage: require_relative 'dotenv'

def load_dotenv(file_path = '.env')
  return unless File.exist?(file_path)

  File.readlines(file_path).each do |line|
    # Remove leading/trailing whitespace and newlines
    line = line.strip

    # Skip comments and empty lines
    next if line.start_with?('#') || line.empty?

    # Parse KEY=VALUE format
    if line =~ /\A([A-Z_][A-Z0-9_]*)=(.*)\z/
      key = Regexp.last_match(1)
      value = Regexp.last_match(2)

      # Remove quotes if present
      value = value.strip.gsub(/\A['"]|['"]\z/, '')

      # Set environment variable only if not already set
      ENV[key] ||= value
    end
  end
end

# Auto-load .env file from current directory
load_dotenv(File.join(File.dirname(__FILE__), '.env'))
