require "lita"

Lita.load_locales Dir[File.expand_path(
  File.join("..", "..", "locales", "*.yml"), __FILE__
)]

require "lita/handlers/projects"
require "lita/handlers/deployment"
require "lita/handlers/lintott"
require "lita/handlers/aws_handler"
require "lita/handlers/reload"

Lita::Handlers::Projects.template_root File.expand_path(
  File.join("..", "..", "templates"),
 __FILE__
)
