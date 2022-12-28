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
      class AlertCounter
        attr_reader :alerts_count, :critical_alerts_count, :high_alerts_count

        def initialize
          @alerts_count = 0
          @critical_alerts_count = 0
          @high_alerts_count = 0
        end

        def add_to_alerts_count
          @alerts_count += 1
        end

        def add_to_critical_alerts_count
          @critical_alerts_count += 1
        end

        def add_to_high_alerts_count
          @high_alerts_count += 1
        end
      end

      class DependabotAlertCounter < AlertCounter
        attr_reader :reported_packages
        def initialize
          super
          @reported_packages = Set.new
        end

        def add_reported_package(package)
          @reported_packages << package
        end
      end

      def code_scanned_issues(response)
        code_scan_report = {}

        code_scanned_alerts = config.github.code_scanned_issues

        code_scanned_alerts.each do |alert|
          repo_name = alert.repository.name
          severity = alert.rule.severity
          alert_counter = code_scan_report[repo_name] || AlertCounter.new
          alert_counter.add_to_alerts_count
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
        dependabot_issues_report = {}

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
                node_alerts, dependabot_issues_report, repo_name
              )
            else
              categorize_alerts_by_severity(node_alerts, dependabot_issues_report, repo_name)
            end
          end
          repo_count = edges.length
          last_repo_listed = edges[repo_count - 1]['cursor']
          get_issues = false if repo_count < 100
        end

        total_alerts_count = dependabot_issues_report.values.collect(&:alerts_count).sum
        total_high_alerts_count = dependabot_issues_report.values.collect(&:high_alerts_count).sum
        total_critical_alerts_count = dependabot_issues_report.values.collect(&:critical_alerts_count).sum

        summary = "*#{total_alerts_count} Alerts Total (#{total_high_alerts_count} HIGH; #{total_critical_alerts_count} CRITICAL)*"
        response.reply("#{summary}: \n#{format_dependabot_issues_report(dependabot_issues_report)}")
      end

      private

      def format_code_scan_report(code_scan_report)
        code_scan_report.map do |repo, alert_counter|
          "<https://github.com/zooniverse/#{repo}/security/code-scanning|#{repo}> -- #{alert_counter.alerts_count} (#{alert_counter.high_alerts_count} HIGH; #{alert_counter.critical_alerts_count} CRITICAL)"
        end.join("\n")
      end

      def filter_without_whitespace(filter)
        filter.strip
      end

      def categorize_alerts_by_severity_filter_for_this_week(node_alerts, dependabot_issues_report, repo_name)
        alert_counter = dependabot_issues_report[repo_name] || DependabotAlertCounter.new
        node_alerts.each do |alert|
          next if Date.parse(alert['createdAt']) <= (Date.today - 7)

          vulnerability = alert['securityVulnerability']
          alert_counter.add_to_alerts_count

          severity = vulnerability['severity'].downcase
          alert_counter.add_to_high_alerts_count if severity == 'high'
          alert_counter.add_to_critical_alerts_count if severity == 'critical'

          package_name = vulnerability['package']['name'].downcase
          alert_counter.add_reported_package(package_name)

          dependabot_issues_report[repo_name] = alert_counter
        end
      end

      def categorize_alerts_by_severity(node_alerts, dependabot_issues_report, repo_name)
        alert_counter = dependabot_issues_report[repo_name] || DependabotAlertCounter.new
        node_alerts.each do |alert|
          vulnerability = alert['securityVulnerability']
          alert_counter.add_to_alerts_count

          severity = vulnerability['severity'].downcase
          alert_counter.add_to_high_alerts_count if severity == 'high'
          alert_counter.add_to_critical_alerts_count if severity == 'critical'

          package_name = vulnerability['package']['name'].downcase
          alert_counter.add_reported_package(package_name)

          dependabot_issues_report[repo_name] = alert_counter
        end
      end

      def format_dependabot_issues_report(dependabot_issues_report)
        dependabot_issues_report.map do |repo, counter|
          "<https://github.com/zooniverse/#{repo}/security/dependabot|#{repo}> -- #{counter.alerts_count} (#{counter.high_alerts_count} HIGH; #{counter.critical_alerts_count} CRITICAL) #{counter.reported_packages.size} flagged packages"
        end.join("\n")
      end

      Lita.register_handler(self)
    end
  end
end
