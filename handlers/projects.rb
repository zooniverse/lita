require_relative '../lib/panoptes_project'
require_relative '../lib/ouroboros_project'

module Lita
  module Handlers
    class Projects < Handler
      # insert handler code here
      route(/^project\s+(.+)/, :project, command: true)

      def project(response)
        search = response.matches[0]
        projects = Api::OuroborosProject.projects(search).map(&:to_s)
        projects << Api::PanoptesProject.projects(search).map(&:to_s)

        if projects.size > 0
          response.reply(projects.join("\n"))
        else
          response.reply(empty_response)
        end
      end

      def empty_response
        [
          "I just canna DO IT! I just dinna have the poower!",
          "I can't see the project, I have failed you."
        ].sample
      end

      Lita.register_handler(self)
    end
  end
end
