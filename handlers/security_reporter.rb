# frozen_string_literal: true

require 'httparty'

module Lita
  module Handlers
    class SecurityReporter < Handler
      config :github, default: Zooniverse::Github.new

      route(/^(dependabot)\s*(.*)/, :get_dependabot_issues, command: true,
                                                            help: { 'status dependabot' => 'displays dependabot security alerts' })

      def get_dependabot_issues(response)
        get_issues = true
        last_repo_listed = nil
        alerts = []
        repo_to_alert_count = {}

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
          next unless alert['dismissedAt'].nil?
          next unless alert['fixedAt'].nil?

          vulnerability = alert['securityVulnerability']
          alerts << { repo_name => vulnerability }
          add_alert_count(repo_to_alert_count, repo_name)
        end
      end

      def add_alert_count(repo_to_alert_count, repo_name)
        repo_alert_count = repo_to_alert_count[repo_name] || 0
        repo_to_alert_count[repo_name] = repo_alert_count + 1
      end

      def repos_to_skip
        %w[next-cookie-auth-panoptes Cellect science-gossip-data seven-ten Seven-Ten-Client]
      end

      def format_alerts(repo_to_alert_count)
        formatted_alerts = "\n"
        repo_to_alert_count.each do |repo, count|
          formatted_alerts += "#{repo} -- #{count}\n"
        end
        formatted_alerts
      end

      Lita.register_handler(self)
    end
  end
end
