# frozen_string_literal: true

require 'httparty'

module Lita
  module Handlers
    # some comment
    class Security < Handler
      config :github, default: Zooniverse::Github.new

      route(/^(dependabot)\s*(.*)/, :get_dependabot_issues, command: true,
                                                            help: { 'status dependabot' => 'displays dependabot security alerts' })

      def get_dependabot_issues(response)
        get_issues = true
        last_repo_listed = nil
        alerts = []

        while get_issues == true
          res = config.github.get_dependabot_issues(last_repo_listed)
          if res.nil?
            get_issues = false
            break
          end
          edges = res['data']['organization']['repositories']['edges']
          nodes = res['data']['organization']['repositories']['nodes']
          nodes.each do |node|
            node_alerts = node['vulnerabilityAlerts']['nodes']
            repo_name = node['name']
            next if repos_to_skip.include? repo_name
            next if node_alerts.empty?

            node_alerts.each do |alert|
              next unless alert['dismissedAt'].nil?

              vulnerability = alert['securityVulnerability']
              alerts << { repo_name => vulnerability }
            end
          end
          repo_count = edges.length
          last_repo_listed = edges[repo_count - 1]['cursor']
          get_issues = false if repo_count < 100
        end

        response.reply("#{alerts.length} Alerts : \n #{format_alerts(alerts)} #{alerts.length}")
      end

      private

      def repos_to_skip
        %w[next-cookie-auth-panoptes Cellect science-gossip-data seven-ten Seven-Ten-Client]
      end

      def format_alerts(alerts)
        formatted_alerts = "\n"
        alerts.each do |alert|
          formatted_alerts += "#{alert}\n"
        end
        formatted_alerts
      end

      Lita.register_handler(self)
    end
  end
end
