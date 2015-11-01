require 'bundler'

module Lita
  def self.env
    ENV["LITA_ENV"] || :development
  end

  def self.env?(env=:development)
    self.env.to_s == env.to_s
  end
end

Bundler.require(:default, Lita::env)

$:.unshift(File.expand_path("lita-zooniverse/lib", File.dirname(__FILE__)))

Lita.configure do |config|
  # The name your robot will use.
  config.robot.name = "Lita"

  # The locale code for the language to use.
  # config.robot.locale = :en

  # The severity of messages to log. Options are:
  # :debug, :info, :warn, :error, :fatal
  # Messages at the selected level and above will be logged.
  config.robot.log_level = :info

  # An array of user IDs that are considered administrators. These users
  # the ability to add and remove other users from authorization groups.
  # What is considered a user ID will change depending on which adapter you use.
  # config.robot.admins = ["1", "2"]

  if Lita::env?(:production)
    # The adapter you want to connect with. Make sure you've added the
    # appropriate gem to the Gemfile.
    config.robot.adapter = :slack

    ## Example: Set options for the chosen adapter.
    config.adapters.slack.token = ENV["SLACK_TOKEN"]
  end

  ## Example: Set options for the Redis connection.
  # config.redis.host = "127.0.0.1"
  # config.redis.port = 1234

  ## Example: Set configuration for any loaded handlers. See the handler's
  ## documentation for options.
  # config.handlers.some_handler.some_config_key = "value"
end

require_relative 'lita-zooniverse/lib/lita-zooniverse'
