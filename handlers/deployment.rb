# frozen_string_literal: true

require 'httparty'
require 'octokit'
require 'uri'
require_relative '../lib/zooniverse_github'

module Lita
  module Handlers
    class Deployment < Handler

      DEPLOY_REPOS_SET_NAME = 'deploy-repos'

      config :github, default: Zooniverse::Github.new

      route(
        /^rebuild subject[\s-]set[\s-]search API/i,
        :rebuild_subject_set_search_api,
        command: true,
        help: { 'rebuild subject-set-search API' => 'Rebuild subject-set-search API with new data' }
      )
      route(/^apply ingresses/, :apply_ingresses, command: true, help: {"apply ingresses" => "Applies the ingress templates in the static repo"})

      # New K8s deployment template
      # updates the production release tag on the supplied repo (\s*.(*))
      # which in turn triggers a github action job to build / deploy the service
      #
      # state: the default deploy "chat ops" deploy system
      #        and in use for all K8s deployed services
      route(/^(deploy)\s*(.*)/, :tag_deploy, command: true, help: {"deploy REPO" => "Updates the production-release tag on zooniverse/REPO"})
      # custom feature branch deploys for FE Project app - https://github.com/zooniverse/front-end-monorepo/pull/3432
      route(/^(fem branch deploy)\s*(.*)/, :fem_branch_deploy, command: true, help: {'fem branch deploy BRANCH' => 'Deploys the specified FEM $BRANCH'})
      route(/^(migrate)\s*(.*)/, :tag_migrate, command: true, help: {"migrate REPO" => "Updates the production-migrate tag on zooniverse/REPO"})
      route(/^(status\s*all)/, :status_all, command: true, help: {'status all' => 'Returns the deployment status for all previously deployed $REPO_NAMES.'})
      route(/^(status|version)\s+(?!all)(.+)/, :status, command: true, help: {'status REPO_NAME' => 'Returns the state of commits not deployed for the $REPO_NAME.'})
      route(/^(history)\s(.+)/, :commit_history, command: true, help: {'history REPO_NAME' => 'Returns the last deployed commit history (max 10) .'})


      def rebuild_subject_set_search_api(response)
        repo_name = config.github.orgify_repo_name('subject-set-search-api')
        config.github.run_workflow(repo_name, 'deploy.yml', 'main')
        # pause for a period of seconds while the GH API syncs
        # to ensure we pickup the most recently submited job run
        gh_api_wait_time = rand(2..4)
        sleep(gh_api_wait_time)
        workflow_run = config.github.get_latest_workflow_run(repo_name, 'deploy_production.yml', 'main')
        response.reply('Subject-Set-Search-API Rebuild initiated:')
        response.reply("Details at #{workflow_run[:html_url]}")
      end

      def tag_deploy(response)
        repo_name = repo_name_without_whitespace(response.matches[0][1])
        begin
          tag = config.github.update_production_tag(repo_name)
          response.reply("Deployment tag '#{tag}' was successfully updated for #{repo_name}.")
        rescue Lita::Zooniverse::Github::RefAlreadyDeployed => e
          response.reply("Deploy cancelled: #{e.message}")
        rescue Lita::Zooniverse::Github::UnknownRepoCommit => e
          response.reply("Failed to deploy: #{e.message}")
        rescue Octokit::Error => e
          response.reply("Failed to update tag: #{e.message}")
        else
          # Track the deploy if no exception is thrown
          track_deploy_data_in_redis(repo_name)
        end
      end

      def tag_migrate(response)
        repo_name = repo_name_without_whitespace(response.matches[0][1])
        tag = config.github.update_production_migrate_tag(repo_name)
        response.reply("Deployment tag '#{tag}' was successfully updated for #{repo_name}.")
      end

      def apply_ingresses(response)
        config.github.update_production_ingresses_tag
        response.reply("Ingress tag was successfully updated for static.")
      end

      def status(response)
        repo_name = repo_name_without_whitespace(response.matches[0][1])
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
        repo_name = repo_name_without_whitespace(response.matches[0][1])
        last_deployed_commits = redis.lrange(repo_name_commit_history_list(repo_name), 0, -1)
        repo_name = config.github.orgify_repo_name(repo_name)
        last_deployed_commits.map { |commit_id| commit_url_format(repo_name, commit_id) }
        output = "Last Deployed Commits (most recent is higher):\n#{last_deployed_commits.join("\n")}"
        response.reply(output)
      end

      def fem_branch_deploy(response)
        branch_name = repo_name_without_whitespace(response.matches[0][1])
        repo_name = config.github.orgify_repo_name('front-end-monorepo')
        config.github.run_workflow(repo_name, 'deploy_branch.yml', branch_name)
        # pause for a period of seconds while the GH API syncs
        # to ensure we pickup the most recently submited job run
        gh_api_wait_time = rand(2..4)
        sleep(gh_api_wait_time)
        workflow_run = config.github.get_latest_workflow_run(repo_name, 'deploy_branch.yml', branch_name)
        response.reply("FE Project app branch (#{branch_name}) deploy initiated:")
        response.reply("Details at #{workflow_run[:html_url]}")
      end

      private

      # ensure no leading/trailing whitespaces etc in the name
      def repo_name_without_whitespace(repo_name)
        repo_name.strip
      end

      def status_response(repo_name)
        gh_status_response = config.github.get_repo_status(repo_name)
        if gh_status_response.status == :error
          # remove the repo from our tracking set for status all reports
          redis.zrem(DEPLOY_REPOS_SET_NAME, repo_name)
        end
        gh_status_response.body
      end

      def track_deploy_data_in_redis(repo_name)
        # Track in redis sorted set which systems we are deploying
        # and track their last 10 commit histories using a capped list
        commit_id = config.github.get_latest_commit(repo_name)
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
