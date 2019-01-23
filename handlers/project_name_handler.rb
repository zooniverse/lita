
require_relative '../lib/foswig'
require_relative '../lib/project_names'

GENERATOR = Foswig.new(3)
GENERATOR.add_words(PROJECT_NAMES)

module Lita
  module Handlers
    class Projects < Handler
      # insert handler code here
      route(/^generate project name/, :generate, command: true)

      def generate(response)
          response.reply(GENERATOR.generate_word(5, 40))
      end

      Lita.register_handler(self)
    end
  end
end