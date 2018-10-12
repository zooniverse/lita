require 'httparty'
require 'octokit'
require 'jenkins_api_client'
require 'uri'

module Lita
  module Handlers
    class Deployment < Handler
      JOBS = {
        "lita" => {
          deploy: "Deploy lita"
        },
        "panoptes" => {
          build: "Build Panoptes Production AMI",
          migrate: "Migrate Production Panoptes Database",
          deploy: "Deploy latest Panoptes Production build",
          deploy_api_only: "Deploy latest Panoptes Production API only build",
          update_tag: "Update panoptes production tag"
        },
        "caesar" => {
          deploy: "Update Caesar Production"
        },
        "stats" => {
          deploy: "Update Zoo Event Stats production"
        },
        "aggregation" => {
          deploy: "Update Panoptes production aggregation"
        },
        "talk" => {
          build: "Build Talk Production",
          migrate: "Migrate Production Talk-Api Database",
          deploy: "Deploy Talk Production",
          update_tag: "Update talk production tag"
        }
      }

      config :jenkins_url, default: 'https://jenkins.zooniverse.org'
      config :jenkins_username, required: true
      config :jenkins_password, required: true

      route(/^(status|build|migrate|deploy|lock|unlock)/, :reversed, command: true)

      route(/^panoptes (status|version)/, :status, command: true, help: {"panoptes status" => "Returns the number of commits not deployed to production."})
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

      route(/^(caesar) deploy/, :deploy, command: true, help: {"caesar deploy" => "Deploys https://github.com/zooniverse/caesar"})

      route(/^(stats) deploy/, :deploy, command: true, help: {"stats deploy" => "Deploys https://github.com/zooniverse/zoo-event-stats"})

      route(/^(lita) deploy/, :deploy, command: true, help: {"lita deploy" => "Deploys myself, aka https://github.com/zooniverse/lita"})

      route(/^(aggregation) deploy/, :deploy, command: true, help: {"aggregation deploy" => "Deploys https://github.com/zooniverse/aggregation"})

      route(/^clear static cache/, :clear_static_cache, command: true, help: {"clear static cache" => "Clears the static cache (duh)"})

      def status(response)
        deployed_version = HTTParty.get("https://panoptes.zooniverse.org/commit_id.txt").strip

        git_responses = {}
        %w(HEAD production-release).each do |tag|
          comparison = Octokit.compare("zooniverse/panoptes", deployed_version, tag)
          if comparison.commits.empty?
            git_responses[tag] = "is the currently deployed version."
          else
            word = comparison.commits.size > 1 ? "commits" : "commit"
            git_responses[tag] = "#{comparison.commits.size} undeployed #{word}. #{comparison.permalink_url}"
            git_responses[tag] << " :shipit:" if tag == "production-release"
          end
        end

        formatted_response = git_responses.map do |tag, comment|
          "#{tag.upcase} : #{comment}"
        end.join("\n")

        response.reply(formatted_response)
      end

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

      def build_jenkins_job(response, job_name)
        response.reply("#{job_name} starting... hang on while I get you a build number (might take up to 60 seconds).")

        build_number = jenkins.job.build(job_name, {}, {'build_start_timeout' => 60, 'cancel_on_build_start_timeout' => true})
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

      Lita.register_handler(self)
    end
  end
end
