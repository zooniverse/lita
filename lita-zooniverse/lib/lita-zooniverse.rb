require "lita"

Lita.load_locales Dir[File.expand_path(
  File.join("..", "..", "locales", "*.yml"), __FILE__
)]

module Lita
  def self.env
    ENV["LITA_ENV"] || :development
  end

  def self.env?(env=:development)
    self.env.to_s == env.to_s
  end
end

require "lita/handlers/projects"
require "lita/handlers/deployment"
require "lita/handlers/reload"

Lita::Handlers::Projects.template_root File.expand_path(
  File.join("..", "..", "templates"),
 __FILE__
)
