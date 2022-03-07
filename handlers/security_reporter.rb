# frozen_string_literal: true

require 'httparty'

module Lita
  module Handlers
    class SecurityReporter < Handler
      config :github, default: Zooniverse::Github.new

      route(/^(security report)\s*(.*)/, :get_dependabot_issues, command: true,
                                                                 help: { 'status dependabot' => 'displays dependabot security alerts' })

      def get_dependabot_issues(response)
        get_issues = true
        last_repo_listed = nil
        alerts = []
        repo_to_alert_count = {}

        while get_issues == true
          res = config.github.get_dependabot_issues(last_repo_listed)

          break unless res

          edges = res['data']['organization']['repositories']['edges']
          nodes = res['data']['organization']['repositories']['nodes']
          nodes.each do |node|
            node_alerts = node['vulnerabilityAlerts']['nodes']
            next if node_alerts.empty?

            repo_name = node['name']

            @repos_to_skip ||= %w[next-cookie-auth-panoptes Cellect science-gossip-data seven-ten
                                  Seven-Ten-Client].map(&:downcase)

            next if @repos_to_skip.include? repo_name.downcase

            filter_fixed_or_dismissed_alerts node_alerts, alerts, repo_to_alert_count, repo_name
          end
          repo_count = edges.length
          last_repo_listed = edges[repo_count - 1]['cursor']
          get_issues = false if repo_count < 100
        end

        response.reply("#{alerts.length} Alerts Total: \n #{format_alerts(repo_to_alert_count)}")
      end

      private

      def filter_fixed_or_dismissed_alerts(node_alerts, alerts, repo_to_alert_count, repo_name)
        node_alerts.each do |alert|
          next if alert['dismissedAt']
          next if alert['fixedAt']

          vulnerability = alert['securityVulnerability']
          alerts << { repo_name => vulnerability }
          add_alert_count(repo_to_alert_count, repo_name)
        end
      end

      def add_alert_count(repo_to_alert_count, repo_name)
        repo_alert_count = repo_to_alert_count[repo_name] || 0
        repo_to_alert_count[repo_name] = repo_alert_count + 1
      end

      def format_alerts(repo_to_alert_count)
        repo_to_alert_count.map { |repo, count| "#{repo} -- #{count}" }.join("\n")
      end

      Lita.register_handler(self)
    end
  end
end
