require 'httparty'
require 'octokit'
require 'jenkins_api_client'

module Lita
  module Handlers
    class Deployment < Handler
      BUILD_JOB  = "Build Panoptes Production AMI"
      DEPLOY_JOB = "Deploy latest Panoptes Production build"
      RAKE_JOB   = "Run rake task"

      config :jenkins_url, default: 'https://jenkins.zooniverse.org'
      config :jenkins_username, required: true
      config :jenkins_password, required: true

      route(/^panoptes (status|version)/, :status, command: true, help: {"panoptes status" => "Returns the number of commits not deployed to production."})
      route(/^panoptes build/, :build, command: true, help: {"panoptes build" => "Triggers a build of a new AMI of *PRODUCTION* in Jenkins."})
      route(/^panoptes deploy/, :deploy, command: true, help: {"panoptes deploy" => "Triggers a deployment of *PRODUCTION* in Jenkins."})
      route(/^panoptes lock\s*(.*)/, :lock, command: true, help: {"panoptes lock REASON" => "Stops builds and deployments"})
      route(/^panoptes unlock/, :unlock, command: true, help: {"panoptes unlock" => "Lifts deployment restrictions"})

      def status(response)
        ensure_no_lock(response)

        deployed_version = HTTParty.get("https://panoptes.zooniverse.org/commit_id.txt").strip
        comparison = Octokit.compare("zooniverse/panoptes", deployed_version, "HEAD")

        if comparison.commits.empty?
          response.reply("HEAD is the currently deployed version.")
        else
          word = comparison.commits.size > 1 ? "commits" : "commit"
          response.reply("#{comparison.commits.size} undeployed #{word}. #{comparison.permalink_url} :shipit:")
        end
      end

      def build(response)
        ensure_no_lock(response) or return
        build_jenkins_job(response, BUILD_JOB)
      end

      def deploy(response)
        ensure_no_lock(response) or return
        build_jenkins_job(response, DEPLOY_JOB)
      end

      def lock(response)
        reason = response.matches[0][0]
        reason = reason.empty? ? "No reason given" : reason
        redis.set("lock:reason", reason)
        redis.set("lock:user", response.user.name)
        response.reply("None shall pass.")
      end

      def unlock(response)
        if locked?
          redis.del("lock:reason")
          redis.del("lock:user")
          response.reply("Unlocked.")
        else
          response.reply("Wasn't locked to begin with.")
        end
      end


      private

      def ensure_no_lock(response)
        if lock = locked?
          response.reply("Panoptes is version-locked by #{lock.user}: #{lock.reason}")
          false
        else
          true
        end
      end

      def build_jenkins_job(response, job_name)
        response.reply("#{job_name} starting... hang on while I get you a build number (might take up to 60 seconds).")

        build_number = jenkins.job.build(job_name, {}, {'build_start_timeout' => 60, 'cancel_on_build_start_timeout' => true})
        response.reply("#{job_name} #{build_number} started.")

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

      def locked?
        reason = redis.get("lock:reason")
        user = redis.get("lock:user")

        if reason || user
          OpenStruct.new(reason: reason, user: redis.get("lock:user"))
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
