
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
          response.reply("Here are some ideas: \n#{10.times.map { GENERATOR.generate_word(10, 100) }.join("\n") }")
      end

      Lita.register_handler(self)
    end
  end
end