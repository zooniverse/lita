require 'httparty'
require 'octokit'

module Lita
  module Handlers
    class Deployment < Handler
      # insert handler code here
      route(/^panoptes version/, :status, command: true)

      def status(response)
        deployed_version = HTTParty.get("https://panoptes.zooniverse.org/commit_id.txt").strip
        comparison = Octokit.compare("zooniverse/panoptes", deployed_version, "HEAD")

        if comparison.commits.empty?
          response.reply("HEAD is the currently deployed version.")
        else
          word = comparison.commits.size > 1 ? "commits" : "commit"
          response.reply("#{comparison.commits.size} undeployed #{word}. #{comparison.permalink_url} :shipit:")
        end
      end

      Lita.register_handler(self)
    end
  end
end
