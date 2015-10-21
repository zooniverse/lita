require 'httparty'

module Lita
  module Handlers
    class ZooniverseProjects < Handler
      # insert handler code here
      route(/^project\s+(.+)/, :project)

      def project(response)
        results = JSON.parse(HTTParty.get("https://www.zooniverse.org/api/projects", 
       		      headers: {"Content-Type" => "application/json", 
		      "Accept" => "application/vnd.api+json; version=1"},
		      query: {search: response.matches[0]}))
	projects = results["projects"].map do |project|
          url = "https://www.zooniverse.org/projects/#{project["slug"]}"
	  "#{url} -- #{project["id"]} -- #{project["display_name"]} (classifications: #{project["classifications_count"]}, classifiers: #{project["classifiers_count"]}, live: #{project["live"]})"
	end

	if projects.size > 0
          response.reply(projects.join("\n"))
        else
  	  response.reply("I just canna DO IT! I just dinna have the poower!")
        end
      end

      Lita.register_handler(self)
    end
  end
end
