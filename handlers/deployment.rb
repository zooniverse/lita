# frozen_string_literal: true

require 'httparty'
require 'octokit'
require 'jenkins_api_client'
require 'uri'

module Lita
  module Handlers
    class Deployment < Handler
      JOBS = {
        "panoptes" => {
          build: "Build Panoptes Production AMI",
          migrate: "Migrate Production Panoptes Database",
          deploy: "Deploy latest Panoptes Production build",
          deploy_api_only: "Deploy latest Panoptes Production API only build",
          update_tag: "Update panoptes production tag"
        },
        "talk" => {
          build: "Build Talk Production",
          migrate: "Migrate Production Talk-Api Database",
          deploy: "Deploy Talk Production",
          update_tag: "Update talk production tag"
        },
        "deploy" => "Update production-release tag"
      }

      ORG_URL_AND_TYPES = {
        'zooniverse/talk-api' => [ 'file', 'https://talk.zooniverse.org/commit_id.txt' ],
        'zooniverse/zoo-stats-api-graphql' => [ 'json', 'https://graphql-stats.zooniverse.org' ]
          # TODO: enumerate the JSON style apps like
          # https://education-api.zooniverse.org/
          # https://seven-ten.zooniverse.org/
          # https://stats.zooniverse.org/
          # https://graphql-stats.zooniverse.org/
          # etc
      }.freeze

      JSON_COMMIT_ID_KEYS = %w[revision commit_id].freeze
      DEPLOYED_BRANCH_REPOS = {
        'zooniverse/talk-api' => 'production',
        'zooniverse/zoo-stats-api-graphql' => 'master'
      }.freeze

      config :jenkins_url, default: 'https://jenkins.zooniverse.org'
      config :jenkins_username, required: Lita.required_config?
      config :jenkins_password, required: Lita.required_config?

      route(/^(build|migrate|lock|unlock)/, :reversed, command: true)

      route(/^clear static cache/, :clear_static_cache, command: true, help: {"clear static cache" => "Clears the static cache (duh)"})

      # specific repo deployment targets for building and deploying AMIs
      # relies heavily on the old operations repo deployment scripts
      #
      # state: still in use for Panoptes and Talk but will change once they are migrated to K8s
      route(/^panoptes (status|version)/, :panoptes_status, command: true, help: {'panoptes status' => 'Returns the number of commits not deployed to production.'})
      route(/^(panoptes) update tag(\sand build)?$/, :update_tag, command: true, help: {"panoptes update tag" => "Triggers a GitHub production tag update via Jenkins, in turn dockerhub & Jenkins will build a new production AMI."})
      route(/^(panoptes) build/, :build, command: true, help: {"panoptes build" => "Triggers a build of a new AMI of *PRODUCTION* in Jenkins."})
      route(/^(panoptes) migrate/, :migrate, command: true, help: {"panoptes migrate" => "Runs database migrations for Panoptes *PRODUCTION* in Jenkins."})
      route(/^(panoptes) deploy$/, :deploy, command: true, help: {"panoptes deploy" => "Triggers a deployment of *PRODUCTION* in Jenkins."})
      route(/^(panoptes) deploy api only$/, :deploy_api_only, command: true, help: {"panoptes deploy api only" => "Triggers a deployment of *PRODUCTION* api nodes only (no backgroud dump workers) in Jenkins."})
      route(/^(panoptes) lock\s*(.*)/, :lock, command: true, help: {"panoptes lock REASON" => "Stops builds and deployments"})
      route(/^(panoptes) unlock/, :unlock, command: true, help: {"panoptes unlock" => "Lifts deployment restrictions"})
      route(/^(talk) update tag(\sand build)?$/, :update_tag, command: true, help: {"talk update tag" => "Triggers a GitHub production tag update via Jenkins and in turn dockerhub."})
      route(/^(talk) build/, :build, command: true, help: {"talk build" => "Triggers a build of a new AMI of *PRODUCTION* in Jenkins."})
      route(/^(talk) migrate/, :migrate, command: true, help: {"talk migrate" => "Runs database migrations for Talk *PRODUCTION* in Jenkins."})
      route(/^(talk) deploy$/, :deploy, command: true, help: {"talk deploy" => "Triggers a deployment of *PRODUCTION* in Jenkins."})

      # New K8s deployment template
      # updates the production release tag on the supplied repo (\s*.(*))
      # which in turn triggers a jenkinsfile job to build / deploy the service
      #
      # state: the default deploy "chat ops" deploy system
      #        and in use for all K8s deployed services
      route(/^(deploy)\s*(.*)/, :tag_deploy, command: true, help: {"deploy REPO" => "Updates the production-release tag on zooniverse/REPO"})
      route(/^(status|version)\s*(.*)/, :status, command: true, help: {'status REPO_NAME' => 'Returns the state of commits not deployed for the $REPO_NAME.'})

      def run_deployment_task(response, job)
        app, jobs = get_jobs(response)
        ensure_no_lock(app, response) or return
        jenkins_job_name = jobs[job]
        build_jenkins_job(response, jenkins_job_name)
      end

      def update_tag(response)
        run_deployment_task(response, :update_tag)
      end

      def build(response)
        run_deployment_task(response, :build)
      end

      def migrate(response)
        run_deployment_task(response, :migrate)
      end

      def deploy(response)
        run_deployment_task(response, :deploy)
      end

      def deploy_api_only(response)
        run_deployment_task(response, :deploy_api_only)
      end

      def lock(response)
        app, jobs = get_jobs(response)
        reason = response.matches[0][1]
        reason = reason.empty? ? "No reason given" : reason
        redis.set("lock:#{app}:reason", reason)
        redis.set("lock:#{app}:user", response.user.name)
        response.reply("None shall pass.")
      end

      def unlock(response)
        app, jobs = get_jobs(response)
        if locked?(app)
          redis.del("lock:#{app}:reason")
          redis.del("lock:#{app}:user")
          response.reply("Unlocked.")
        else
          response.reply("Wasn't locked to begin with.")
        end
      end

      def clear_static_cache(response)
        build_jenkins_job(response, "Clear static cache")
      end

      def reversed(response)
        response.reply("Reverse those please.")
      end

      def tag_deploy(response)
        jenkins_job_name = JOBS.fetch('deploy')
        build_jenkins_job(response, jenkins_job_name, params={"REPO" => response.matches[0][1]})
      end

      # backwards compat for existing chat ops cmd
      def panoptes_status(response)
        repo_name = 'zooniverse/panoptes'
        response.reply(
          get_repo_status(repo_name)
        )
      end

      def status(response)
        repo_name = response.matches[0][1]
        unless repo_name.match(/\Azooniverse\/.*/)
          repo_name = "zooniverse/#{repo_name}"
        end
        response.reply(
          get_repo_status(repo_name)
        )
      end

      private

      def get_jobs(response)
        app = response.matches[0][0]
        jobs = JOBS.fetch(app)
        [app, jobs]
      end

      def ensure_no_lock(app, response)
        if lock = locked?(app)
          response.reply("#{app} is version-locked by #{lock.user}: #{lock.reason}")
          false
        else
          true
        end
      end

      def build_jenkins_job(response, job_name, params={})
        response.reply("#{job_name} starting... hang on while I get you a build number (might take up to 60 seconds).")

        build_number = jenkins.job.build(job_name, params, {'build_start_timeout' => 60, 'cancel_on_build_start_timeout' => true})
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

      def locked?(app)
        reason = redis.get("lock:#{app}:reason")
        user = redis.get("lock:#{app}:user")

        if reason || user
          OpenStruct.new(reason: reason, user: redis.get("lock:#{app}:user"))
        end
      end

      def jenkins
        raise unless config.jenkins_password
        @jenkins ||= JenkinsApi::Client.new(server_url: config.jenkins_url,
                                            username: config.jenkins_username,
                                            password: config.jenkins_password,
                                            ssl: true)
      end

      def get_repo_status(repo_name)
        deployed_version = get_deployed_commit(repo_name)
        production_tag = production_release_tag(repo_name)
        get_app_status(repo_name, deployed_version, production_tag)
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
            git_responses[tag] << ' :shipit:' if tag == 'production-release'
          end
        end

        formatted_response = git_responses.map do |tag, comment|
          "#{tag.upcase} : #{comment}"
        end

        formatted_response.join("\n")
      end

      def get_deployed_commit(repo_name)
        type, repo_url = repo_type_and_url(repo_name)
        repo_url_data = HTTParty.get(repo_url)
        case type
        when 'json'
          commit_key = (JSON_COMMIT_ID_KEYS & repo_url_data.keys).first
          repo_url_data.fetch(commit_key)
        else
          repo_url_data
        end
      end

      def repo_type_and_url(repo_name)
        type, url = ORG_URL_AND_TYPES[repo_name]
        if type && url
          [type, url]
        else
          app_name = repo_name.split('/')[1]
          ['file', "https://#{app_name}.zooniverse.org/commit_id.txt"]
        end
      end

      def production_release_tag(repo_name)
        if branch_or_tag = DEPLOYED_BRANCH_REPOS[repo_name]
          branch_or_tag
        else
          'production-release'
        end
      end

      Lita.register_handler(self)
    end
  end
end
