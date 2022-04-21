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
        repo_to_alert_count = {}
        repo_to_alert_count.default = 0
        repo_to_high_alert_count = {}
        repo_to_high_alert_count.default = 0
        repo_to_critical_alert_count = {}
        repo_to_critical_alert_count.default = 0
        repo_to_reported_packages = {}

        while get_issues == true
          res = config.github.get_dependabot_issues(last_repo_listed)

          break unless res

          edges = res['data']['organization']['repositories']['edges']
          nodes = res['data']['organization']['repositories']['nodes']
          nodes.each do |node|
            node_alerts = node['vulnerabilityAlerts']['nodes']
            next if node_alerts.empty?

            repo_name = node['name']

            @repos_to_skip ||= %w[next-cookie-auth-panoptes science-gossip-data seven-ten
                                  Seven-Ten-Client Social Sellers Exercise CSA-Home].map(&:downcase)

            next if @repos_to_skip.include? repo_name.downcase

            categorize_alerts_by_severity node_alerts, repo_to_alert_count, repo_name,
                                             repo_to_high_alert_count, repo_to_critical_alert_count, repo_to_reported_packages
          end
          repo_count = edges.length
          last_repo_listed = edges[repo_count - 1]['cursor']
          get_issues = false if repo_count < 100
        end

        summary = "*#{total_alert_count(repo_to_alert_count)} Alerts Total (#{total_alert_count(repo_to_high_alert_count)} HIGH; #{total_alert_count(repo_to_critical_alert_count)} CRITICAL)*"
        response.reply("#{summary}: \n#{format_alerts(repo_to_alert_count, repo_to_high_alert_count,
                                                      repo_to_critical_alert_count, repo_to_reported_packages)}")
      end

      private

      def filter_without_whitespace(filter)
        filter.strip
      end

      def total_alert_count(repo_to_alert_count)
        repo_to_alert_count.reduce(0) { |sum, (_, count)| sum + count }
      end

      def categorize_alerts_by_severity(node_alerts, repo_to_alert_count, repo_name, repo_to_high_alert_count, repo_to_critical_alert_count, repo_to_reported_packages)
        node_alerts.each do |alert|
          vulnerability = alert['securityVulnerability']
          add_alert_count(repo_to_alert_count, repo_name)

          severity = vulnerability['severity'].downcase
          add_alert_count(repo_to_high_alert_count, repo_name) if severity == 'high'
          add_alert_count(repo_to_critical_alert_count, repo_name) if severity == 'critical'

          package_name = vulnerability['package']['name'].downcase
          add_unique_reported_packages(repo_to_reported_packages, repo_name, package_name)
        end
      end

      def add_unique_reported_packages(repo_to_reported_packages, repo_name, package_name)
        packages = repo_to_reported_packages[repo_name] || []
        packages << package_name unless packages.include? package_name
        repo_to_reported_packages[repo_name] = packages
      end

      def add_alert_count(repo_to_alert_count, repo_name)
        repo_alert_count = repo_to_alert_count[repo_name]
        repo_to_alert_count[repo_name] = repo_alert_count + 1
      end

      def format_alerts(repo_to_alert_count, repo_to_high_alert_count, repo_to_critical_alert_count, repo_to_reported_packages)
        repo_to_alert_count.map do |repo, count|
          "<https://github.com/zooniverse/#{repo}/security/dependabot | #{repo}> -- #{count} (#{repo_to_high_alert_count[repo]} HIGH; #{repo_to_critical_alert_count[repo]} CRITICAL) #{repo_to_reported_packages[repo].length} flagged packages"
        end.join("\n")
      end

      Lita.register_handler(self)
    end
  end
end
