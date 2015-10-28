require_relative 'project'

module Lita
  module Api
    class OuroborosProject

      include Api::Project

      def projects
        project_names = find_project_names
        return project_names if project_names.empty?
        projects_search(project_names).map do |project|
          "(O): #{project["bucket_path"]} -- #{project["zooniverse_id"]} -- #{project["display_name"]} "\
          "(classifications: #{project["classification_count"]}, "\
          "classifiers: #{project["user_count"]}, completed_subjects: #{project["complete_count"]})"
	      end
      end

      private

      def api_host(project_name)
        @api_host = "https://api.zooniverse.org/projects/#{project_name}"
      end

      def api_host_projects
        @api_host_projects ||= "https://api.zooniverse.org/projects/list"
      end

      def projects_search(project_names)
        project_names.map do |name|
          HTTParty.get(api_host(name), { headers: api_headers })
        end
      end

      def find_project_names
        all_projects = HTTParty.get(api_host_projects, { headers: api_headers })
        projects = all_projects.select do |project|
          [ project["display_name"], project["name"] ].any? do |name|
            name.match(/\A(#{search_query.join(",")}).+/i)
          end
        end
        projects.map{ |p| p["name"] }
      end
    end
  end
end
