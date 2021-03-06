# frozen_string_literal: true

require 'httparty'
require 'octokit'
require 'jenkins_api_client'
require 'uri'
require_relative '../lib/github_status_reporter'

module Lita
  module Handlers
    class Deployment < Handler

      JOBS = {
        "deploy" => "Update production-release tag",
        "migrate" => "Update production-migrate tag"
      }

      DEPLOY_REPOS_SET_NAME = 'deploy-repos'

      config :jenkins_url, default: 'https://jenkins.zooniverse.org'
      config :jenkins_username, required: Lita.required_config?
      config :jenkins_password, required: Lita.required_config?
      config :github_status_reporter, default: Github::StatusReporter.new

      route(/^clear static cache/, :clear_static_cache, command: true, help: {"clear static cache" => "Clears the static cache (duh)"})

      # New K8s deployment template
      # updates the production release tag on the supplied repo (\s*.(*))
      # which in turn triggers a jenkinsfile job to build / deploy the service
      #
      # state: the default deploy "chat ops" deploy system
      #        and in use for all K8s deployed services
      route(/^(deploy)\s*(.*)/, :tag_deploy, command: true, help: {"deploy REPO" => "Updates the production-release tag on zooniverse/REPO"})
      route(/^(migrate)\s*(.*)/, :tag_migrate, command: true, help: {"migrate REPO" => "Updates the production-migrate tag on zooniverse/REPO"})
      route(/^(status\s*all)/, :status_all, command: true, help: {'staus all' => 'Returns the deployment status for all previously deployed $REPO_NAMES.'})
      route(/^(status|version)\s+(?!all)(.+)/, :status, command: true, help: {'status REPO_NAME' => 'Returns the state of commits not deployed for the $REPO_NAME.'})
      route(/^(history)\s(.+)/, :commit_history, command: true, help: {'history REPO_NAME' => 'Returns the last deployed commit history (max 10) .'})

      def clear_static_cache(response)
        build_jenkins_job(response, "Clear static cache")
      end

      def tag_deploy(response)
        jenkins_job_name = JOBS.fetch('deploy')
        # ensure no leading/trailing whitespaces etc in the name
        raw_repo_name = response.matches[0][1]
        repo_name = raw_repo_name.strip
        track_deploy_data_in_redis(repo_name)
        build_jenkins_job(response, jenkins_job_name, { 'REPO' => repo_name })
      rescue Lita::Github::StatusReporter::UnknonwnRepoCommit => e
        response.reply("Failed to deploy: #{e.message}")
      end

      def tag_migrate(response)
        jenkins_job_name = JOBS.fetch('migrate')
        build_jenkins_job(response, jenkins_job_name, { 'REPO' => response.matches[0][1] })
      end

      def status(response)
        repo_name = response.matches[0][1]
        response.reply(status_response(repo_name))
      end

      def status_all(response)
        output = []
        repos_sorted_to_deploy_frequency = redis.zrevrange(DEPLOY_REPOS_SET_NAME, 0, -1)
        repos_sorted_to_deploy_frequency.each do |repo_name|
          output << "#{repo_name}\n#{status_response(repo_name)}\n"
        end
        response.reply(output.join("\n"))
      end

      def commit_history(response)
        repo_name = response.matches[0][1]
        last_deployed_commits = redis.lrange(repo_name_commit_history_list(repo_name), 0, -1)
        repo_name = config.github_status_reporter.orgify_repo_name(repo_name)
        last_deployed_commits.map { |commit_id| commit_url_format(repo_name, commit_id) }
        output = "Last Deployed Commits (most recent is higher):\n#{last_deployed_commits.join("\n")}"
        response.reply(output)
      end

      private

      def build_jenkins_job(response, job_name, params={})
        response.reply("#{job_name} starting... hang on while I get you a build number (might take up to 60 seconds).")

        build_number = jenkins.job.build(job_name, params, {'build_start_timeout' => ENV.fetch('JENKINS_JOB_TIMEOUT', 90).to_i, 'cancel_on_build_start_timeout' => true})
        response.reply("#{job_name} #{build_number} started. Console output: #{config.jenkins_url}/job/#{URI.escape(job_name)}/#{build_number}/console")

        every(10) do |timer|
          details = jenkins.job.get_build_details(job_name, build_number)
          if !details["building"]
            response.reply("#{job_name} #{build_number} finished: #{details["result"]}")
            timer.stop
          end
        end
      rescue Timeout::Error
        response.reply("#{job_name} couldn't be started.")
      end

      def jenkins
        raise unless config.jenkins_password
        @jenkins ||= JenkinsApi::Client.new(server_url: config.jenkins_url,
                                            username: config.jenkins_username,
                                            password: config.jenkins_password,
                                            ssl: true)
      end

      def status_response(repo_name)
        gh_status_response = config.github_status_reporter.get_repo_status(repo_name)
        if gh_status_response.status == :error
          # remove the repo from our tracking set for status all reports
          redis.zrem(DEPLOY_REPOS_SET_NAME, repo_name)
        end
        gh_status_response.body
      end

      def track_deploy_data_in_redis(repo_name)
        # Track in redis sorted set which systems we are deploying
        # and track their last 10 commit histories using a capped list
        commit_id = config.github_status_reporter.get_latest_commit(repo_name)
        commit_history_list = repo_name_commit_history_list(repo_name)

        redis.multi do
          # note: this might track some false positives
          #       these will be removed in error handling via status_response
          redis.zadd(DEPLOY_REPOS_SET_NAME, 1, repo_name, incr: true)
          # left push the commit_id to the list
          redis.lpush(commit_history_list, commit_id)
          # keep the most recent 10 list items, i.e. cap the list size
          redis.ltrim(commit_history_list, 0, 9)
        end
      end

      def repo_name_commit_history_list(repo_name)
        "#{repo_name}_commit_history"
      end

      def commit_url_format(repo_name, commit_id)
        "https://github.com/#{repo_name}/commit/#{commit_id}"
      end

      Lita.register_handler(self)
    end
  end
end
