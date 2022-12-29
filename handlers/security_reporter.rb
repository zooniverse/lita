# frozen_string_literal: true

require 'httparty'

module Lita
  module Handlers
    class SecurityReporter < Handler
      config :github, default: Zooniverse::Github.new

      route(/^(security report)\s*(.*)/, :dependabot_issues, command: true,
                                                             help: { 'security report(s) (this week)' => 'displays dependabot security alerts' })
      route(/^(code scan report)\s*(.*)/, :code_scanned_issues, command: true,
                                                                help: { 'code scan report(s)' => 'displays dependabot code scanning alerts' })
      class CodeScanAlertCounter
        attr_reader :alerts_count, :critical_alerts_count, :high_alerts_count

        def initialize
          @alerts_count = 0
          @critical_alerts_count = 0
          @high_alerts_count = 0
        end

        def add_to_alert_count
          @alerts_count += 1
        end

        def add_to_critical_alerts_count
          @critical_alerts_count += 1
        end

        def add_to_high_alerts_count
          @high_alerts_count += 1
        end
      end

      def code_scanned_issues(response)
        code_scan_report = {}

        code_scanned_alerts = config.github.code_scanned_issues

        code_scanned_alerts.each do |alert|
          repo_name = alert.repository.name
          severity = alert.rule.severity
          alert_counter = code_scan_report[repo_name] || CodeScanAlertCounter.new
          alert_counter.add_to_alert_count
          alert_counter.add_to_high_alerts_count if %w[warning high].include?(severity)
          alert_counter.add_to_critical_alerts_count if severity == 'critical'

          code_scan_report[repo_name] = alert_counter
        end

        total_alerts_count = code_scan_report.values.collect(&:alerts_count).sum
        total_high_alerts_count = code_scan_report.values.collect(&:high_alerts_count).sum
        total_critical_alerts_count = code_scan_report.values.collect(&:critical_alerts_count).sum

        summary = "*#{total_alerts_count} Code Scanning Alerts Total(#{total_high_alerts_count} HIGH;#{total_critical_alerts_count} CRITICAL)*"

        response.reply("#{summary}: \n #{format_code_scan_report(code_scan_report)}")
      end

      def dependabot_issues(response)
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
                repo_to_high_alert_count, repo_to_critical_alert_count, repo_to_reported_packages
              )
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

      def format_code_scan_report(code_scan_report)
        code_scan_report.map do |repo, alert_counter|
          "<https://github.com/zooniverse/#{repo}/security/code-scanning|#{repo}> -- #{repo} (#{alert_counter.high_alerts_count} HIGH; #{alert_counter.critical_alerts_count} CRITICAL) #{alert_counter.alerts_count} flagged scans"
        end.join("\n")
      end

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
