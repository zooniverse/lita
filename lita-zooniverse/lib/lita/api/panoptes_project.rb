require_relative 'project'

module Lita
  module Api
    class PanoptesProject

      include Api::Project

      def self.api_headers
        {
          "Content-Type" => "application/json",
          "Accept" => "application/vnd.api+json; version=1"
        }
      end

      def self.api_host
        @api_host ||= "https://www.zooniverse.org/api/projects"
      end

      def self.projects(search_query)
        projects = HTTParty.get(api_host, { headers: api_headers, query: { search: search_query } })
        results = JSON.parse(projects)
        results["projects"].map { |project| self.new(project) }.compact
      end

      def to_s
        "(P): #{project_url(project)} -- #{project["id"]} -- #{project["display_name"]} "\
        "(classifications: #{project["classifications_count"]}, "\
        "classifiers: #{project["classifiers_count"]}, live: #{project["live"]}"\
        "#{migrated? ? ", zoo_project_id: #{legacy_zoo_project_id}" : ""})"
      end

      private

      def migrated?
        project["migrated"]
      end

      def project_url(project)
        "https://www.zooniverse.org/projects/#{project["slug"]}"
      end

      def legacy_zoo_project_id
        project["configuration"]["zoo_home_project_id"]
      end
    end
  end
end
