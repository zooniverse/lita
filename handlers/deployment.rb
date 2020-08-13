# frozen_string_literal: true

require 'httparty'
require 'octokit'
require 'jenkins_api_client'
require 'uri'

module Lita
  module Handlers
    class Deployment < Handler
      class UnknownStatusResponseKey < StandardError; end
      class MissingStatusResponse < StandardError; end
      class MissingStatusResponseData < StandardError; end
      class UnknownServiceUrl < StandardError; end

      JOBS = {
        "deploy" => "Update production-release tag",
        "migrate" => "Update production-migrate tag"
      }

      IRREGULAR_ORG_URLS = {
        'zooniverse/talk-api' => 'https://talk.zooniverse.org/commit_id.txt',
        'zooniverse/zoo-stats-api-graphql' => 'https://graphql-stats.zooniverse.org',
        'zooniverse/zoo-event-stats' => 'https://stats.zooniverse.org/'
      }.freeze

      JSON_COMMIT_ID_KEYS = %w[revision commit_id].freeze
      DEPLOYED_BRANCH_REPOS = {
        'zooniverse/talk-api' => 'production',
        'zooniverse/zoo-stats-api-graphql' => 'master'
      }.freeze

      DEPLOY_REPOS_SET_NAME = 'deploy-repos'

      config :jenkins_url, default: 'https://jenkins.zooniverse.org'
      config :jenkins_username, required: Lita.required_config?
      config :jenkins_password, required: Lita.required_config?

      # THIS CAN GO
      route(/^(build)/, :reversed, command: true)

      route(/^clear static cache/, :clear_static_cache, command: true, help: {"clear static cache" => "Clears the static cache (duh)"})

      # New K8s deployment template
      # updates the production release tag on the supplied repo (\s*.(*))
      # which in turn triggers a jenkinsfile job to build / deploy the service
      #
      # state: the default deploy "chat ops" deploy system
      #        and in use for all K8s deployed services
      route(/^(deploy)\s*(.*)/, :tag_deploy, command: true, help: {"deploy REPO" => "Updates the production-release tag on zooniverse/REPO"})
      route(/^(migrate)\s*(.*)/, :tag_migrate, command: true, help: {"migrate REPO" => "Updates the production-migrate tag on zooniverse/REPO"})
      route(/^(status\s*all)/, :status_all, command: true, help: {'deployment status' => 'Returns the state deployments for all known $REPO_NAMES.'})
      route(/^(status|version)\s+(?!all)(.+)/, :status, command: true, help: {'status REPO_NAME' => 'Returns the state of commits not deployed for the $REPO_NAME.'})

      # THIS CAN GO
      def run_deployment_task(response, job)
        app, jobs = get_jobs(response)
        jenkins_job_name = jobs[job]
        build_jenkins_job(response, jenkins_job_name)
      end

      # THIS CAN GO
      def update_tag(response)
        run_deployment_task(response, :update_tag)
      end

      # THIS CAN GO
      def build(response)
        run_deployment_task(response, :build)
      end

      # THIS CAN GO
      def migrate(response)
        run_deployment_task(response, :migrate)
      end

      # THIS CAN GO
      def deploy(response)
        run_deployment_task(response, :deploy)
      end

      def clear_static_cache(response)
        build_jenkins_job(response, "Clear static cache")
      end

      def reversed(response)
        response.reply("Reverse those please.")
      end

      def tag_deploy(response)
        jenkins_job_name = JOBS.fetch('deploy')
        repo_name = response.matches[0][1]

        # Track in redis sorted set which systems we are deploying
        # note: this might track some false positives
        #       these will be removed in the `get_repo_status` method on lookup failure
        redis.zadd(DEPLOY_REPOS_SET_NAME, 1, repo_name, incr: true)

        build_jenkins_job(response, jenkins_job_name, { 'REPO' => repo_name })
      end

      def tag_migrate(response)
        jenkins_job_name = JOBS.fetch('migrate')
        build_jenkins_job(response, jenkins_job_name, { 'REPO' => response.matches[0][1] })
      end

      def status(response)
        repo_name = response.matches[0][1]
        response.reply(get_repo_status(repo_name))
      end

      def status_all(response)
        output = []
        repos_sorted_to_deploy_frequency = redis.zrevrange(DEPLOY_REPOS_SET_NAME, 0, -1)
        repos_sorted_to_deploy_frequency.each do |repo_name|
          output << "#{repo_name}\n#{get_repo_status(repo_name)}\n"
        end
        response.reply(output.join("\n"))
      end

      private

      # THIS CAN GO
      def get_jobs(response)
        app = response.matches[0][0]
        jobs = JOBS.fetch(app)
        [app, jobs]
      end

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

      def get_repo_status(repo_name)
        unless repo_name.match(/\Azooniverse\/.*/)
          repo_name = "zooniverse/#{repo_name}"
        end
        repo_url = repo_type_and_url(repo_name)
        deployed_version = get_deployed_commit(repo_url)
        production_tag = production_release_tag(repo_name)
        good_response = get_app_status(repo_name, deployed_version, production_tag)
      rescue UnknownServiceUrl
        error_response = status_error_response('No service is running on the url', repo_url)
      rescue MissingStatusResponse
        error_response = status_error_response('Missing deployed status data on the service url', repo_url)
      rescue MissingStatusResponseData
        error_response = status_error_response('Deployed status found on the service url but it has no data', repo_url)
      rescue UnknownStatusResponseKey
        error_response = status_error_response('Unknown commit identifier in the status response body', repo_url)
      rescue Octokit::NotFound
        error_response = status_error_response('Unknown deploy branch / tag target on the repo', repo_url)
      ensure
        if error_response
          # remove the repo from our tracking set for status all reports
          redis.zrem(DEPLOY_REPOS_SET_NAME, repo_name)
          error_response
        else
          good_response
        end
      end

      def status_error_response(msg, repo_url, error_prefix='Failed to fetch the deployed commit for this repo.')
        "#{error_prefix}\n#{msg} - #{repo_url}"
      end

      def get_app_status(repo_name, deployed_version, prod_tag)
        git_responses = {}
        ['HEAD', prod_tag].each do |tag|
          comparison = Octokit.compare(repo_name, deployed_version.strip, tag)
          if comparison.commits.empty?
            git_responses[tag] = 'is the currently deployed version.'
          else
            word = comparison.commits.size > 1 ? 'commits' : 'commit'
            git_responses[tag] = "#{comparison.commits.size} undeployed #{word}. #{comparison.permalink_url}"
            git_responses[tag] + ' :shipit:' if tag == 'production-release'
          end
        end

        formatted_response = git_responses.map do |tag, comment|
          "#{tag.upcase} : #{comment}"
        end

        formatted_response.join("\n")
      end

      def get_deployed_commit(repo_url)
        deployed_status_data = fetch_deployed_status_data(repo_url)

        # if the response object looks like a json object
        if deployed_status_data.respond_to?(:keys)
          commit_key = (JSON_COMMIT_ID_KEYS & deployed_status_data.keys).first
          status_data = deployed_status_data.fetch(commit_key)
          raise MissingStatusResponseData unless status_data

          status_data
        else
          deployed_status_data
        end
      rescue KeyError
        raise UnknownStatusResponseKey
      end

      def repo_type_and_url(repo_name)
        url = IRREGULAR_ORG_URLS[repo_name]
        if url
          url
        else
          app_name = repo_name.split('/')[1]
          "https://#{app_name}.zooniverse.org"
        end
      end

      def production_release_tag(repo_name)
        if branch_or_tag = DEPLOYED_BRANCH_REPOS[repo_name]
          branch_or_tag
        else
          'production-release'
        end
      end

      def fetch_deployed_status_data(repo_url)
        # try the commit_id file first
        repo_commit_id_url = "#{repo_url}/commit_id.txt"
        repo_url_data = HTTParty.get(repo_commit_id_url)
        if repo_url_data.code == 404
          # let's try the root service url for some json data
          repo_url_data = HTTParty.get(repo_url)
        end
        raise MissingStatusResponse if repo_url_data.code == 404

        repo_url_data
      rescue SocketError
        raise UnknownServiceUrl
      end

      Lita.register_handler(self)
    end
  end
end
