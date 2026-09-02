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
        filter = filter_without_whitespace(response.matches[0][1]) || 'all'          

        dependabot_issues_report = config.github.get_dependabot_issues(filter)

        total_high_alerts_count = dependabot_issues_report.sum { |_, counts| counts[:high_severity_count] }
        total_critical_alerts_count = dependabot_issues_report.sum { |_, counts| counts[:critical_severity_count] }
        total_alerts_count = dependabot_issues_report.sum { |_, counts| counts[:total_alerts_count] }

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

      def format_dependabot_issues_report(dependabot_issues_report)
        dependabot_issues_report.map do |repo, counts|
          "<https://github.com/zooniverse/#{repo}/security/dependabot|#{repo}> -- #{counts[:total_alerts_count]} (#{counts[:high_severity_count]} HIGH; #{counts[:critical_severity_count]} CRITICAL) #{counts[:packages_count]} flagged packages"
        end.join("\n")
      end

      Lita.register_handler(self)
    end
  end
end
