require_relative 'project'

module Lita
  module Api
    class PanoptesProject

      include Api::Project

      def projects
        results = JSON.parse(projects_search)
        results["projects"].map do |project|
          next if project["migrated"]
          "(P): #{project_url(project)} -- #{project["id"]} -- #{project["display_name"]} (classifications: #{project["classifications_count"]}, classifiers: #{project["classifiers_count"]}, live: #{project["live"]})"
	      end.compact
      end

      private

      def api_host
        @api_host ||= "https://www.zooniverse.org/api/projects"
      end

      def projects_search
        HTTParty.get(api_host, { headers: api_headers, query: { search: search_query } })
      end

      def project_url(project)
        "https://www.zooniverse.org/projects/#{project["slug"]}"
      end

      def api_headers
        super.merge("Accept" => "application/vnd.api+json; version=1")
      end
    end
  end
end
