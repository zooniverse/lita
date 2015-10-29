require_relative '../api/panoptes_project'
require_relative '../api/ouroboros_project'

module Lita
  module Handlers
    class ZooniverseProjects < Handler
      # insert handler code here
      route(/^project\s+(.+)/, :project)

      def project(response)
        search = response.matches[0]
        projects = Api::OuroborosProject.new(search).projects
        projects << Api::PanoptesProject.new(search).projects
        projects.flatten!

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
