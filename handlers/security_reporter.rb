# frozen_string_literal: true

require 'httparty'

module Lita
  module Handlers
    class SecurityReporter < Handler
      HIGHEST_PRIORITY_REPOS = %w[front-end-monorepo Panoptes-Front-End panoptes caesar designator talk-api zoo-event-stats zoo-stats-api-graphql].map(&:downcase)

      config :github, default: Zooniverse::Github.new

      route(/^(security report)\s*(.*)/, :get_dependabot_issues, command: true, help: { 'security report(s) (this week)' => 'displays dependabot security alerts' })
      route(/^(code scan report)\s*(.*)/, :get_code_scanned_issues_of_high_priority_repos, command: true, help: {'code scan report(s)' => 'displays dependabot code scanning alerts for highest priority repos' })

      def get_code_scanned_issues_of_high_priority_repos(response)
        repo_to_alert_count = {}
        repo_to_alert_count.default = 0
        repo_to_high_alert_count = {}
        repo_to_high_alert_count.default = 0
        repo_to_critical_alert_count = {}
        repo_to_critical_alert_count.default = 0
        HIGHEST_PRIORITY_REPOS.each do |repo_name|
          code_scanned_alerts = config.github.code_scanned_issues_per_repo(repo_name)
          repo_to_alert_count[repo_name] = code_scanned_alerts.length
          code_scanned_alerts.each do |alert|
            severity = alert['rule']['security_severity_level'].downcase
            add_alert_count(repo_to_high_alert_count, repo_name) if severity == 'high'
            add_alert_count(repo_to_critical_alert_count, repo_name) if severity == 'critical'
          end
        rescue Octokit::Error
          next
        end
        summary = "*#{total_alert_count(repo_to_alert_count)} Code Scanning Alerts Total(#{total_alert_count(repo_to_high_alert_count)} HIGH;#{total_alert_count(repo_to_critical_alert_count)} CRITICAL)*"
        summary += "\n"

        HIGHEST_PRIORITY_REPOS.each do |repo|
          next if repo_to_alert_count[repo].zero?

          summary += "<https://github.com/zooniverse/#{repo}/security/code-scanning|#{repo}> -- #{repo_to_alert_count[repo]} (#{repo_to_high_alert_count[repo]} HIGH; #{repo_to_critical_alert_count[repo]} CRITICAL)"
          summary += "\n"
        end
        response.reply(summary)
      end

      def get_dependabot_issues(response)
        filter = filter_without_whitespace(response.matches[0][1])
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

            @repos_to_skip ||= %w[science-gossip-data Sellers Exercise CSA-Home].map(&:downcase)

            next if @repos_to_skip.include? repo_name.downcase

            if filter.downcase.include? 'this week'
              categorize_alerts_by_severity_filter_for_this_week(
                node_alerts, repo_to_alert_count, repo_name,
                repo_to_high_alert_count, repo_to_critical_alert_count, repo_to_reported_packages)
            else
              categorize_alerts_by_severity(node_alerts, repo_to_alert_count, repo_name,
                                            repo_to_high_alert_count, repo_to_critical_alert_count,
                                            repo_to_reported_packages)
            end
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

      def categorize_alerts_by_severity_filter_for_this_week(node_alerts, repo_to_alert_count, repo_name, repo_to_high_alert_count, repo_to_critical_alert_count, repo_to_reported_packages)
        node_alerts.each do |alert|
          next if Date.parse(alert['createdAt']) <= (Date.today - 7)

          vulnerability = alert['securityVulnerability']
          add_alert_count(repo_to_alert_count, repo_name)

          severity = vulnerability['severity'].downcase
          add_alert_count(repo_to_high_alert_count, repo_name) if severity == 'high'
          add_alert_count(repo_to_critical_alert_count, repo_name) if severity == 'critical'

          package_name = vulnerability['package']['name'].downcase
          add_unique_reported_packages(repo_to_reported_packages, repo_name, package_name)
        end
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
          "<https://github.com/zooniverse/#{repo}/security/dependabot|#{repo}> -- #{count} (#{repo_to_high_alert_count[repo]} HIGH; #{repo_to_critical_alert_count[repo]} CRITICAL) #{repo_to_reported_packages[repo].length} flagged packages"
        end.join("\n")
      end

      Lita.register_handler(self)
    end
  end
end
