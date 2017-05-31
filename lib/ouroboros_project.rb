require_relative 'project'

module Lita
  module Api
    class OuroborosProject

      include Api::Project

      def self.api_headers
        {
          "Content-Type" => "application/json",
          "Accept" => "application/json"
        }
      end

      def self.projects_search(project_names)
        project_names.map do |name|
          api_host = "https://api.zooniverse.org/projects/#{name}"
          HTTParty.get(api_host, { headers: api_headers })
        end
      end

      def self.find_project_names(search_query)
        all_projects = HTTParty.get(api_host_projects, { headers: api_headers })
        projects = all_projects.select do |project|
          [ project["display_name"], project["name"] ].any? do |name|
            name.match(/(#{search_query.join(",")})/i)
          end
        end
        projects.map{ |p| p["name"] }
      end

      def self.projects(search_query)
        project_names = find_project_names(search_query)
        return project_names if project_names.empty?
        projects_search(project_names).map { |project| self.new(project) }
      end

      def self.api_host_projects
        @api_host_projects ||= "https://api.zooniverse.org/projects/list"
      end

      def to_s
        "(O): #{project["bucket_path"]} -- #{project["zooniverse_id"]} -- #{project["display_name"]} "\
        "(classifications: #{project["classification_count"]}, "\
        "classifiers: #{project["user_count"]}, completed_subjects: #{project["complete_count"]})"
      end
    end
  end
end
