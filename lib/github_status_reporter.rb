# frozen_string_literal: true

require 'ostruct'

module Lita
  module Github
    class StatusReporter

      class UnknownStatusResponseKey < StandardError; end
      class MissingStatusResponse < StandardError; end
      class MissingStatusResponseData < StandardError; end
      class UnknownServiceUrl < StandardError; end
      class UnknonwnRepoCommit < StandardError; end

      IRREGULAR_ORG_URLS = {
        'zooniverse/front-end-monorepo' => 'https://fe-project.zooniverse.org/commit_id.txt',
        'zooniverse/pfe-lab' => 'https://lab.zooniverse.org/commit_id.txt',
        'zooniverse/Panoptes-Front-End' => 'https://www.zooniverse.org/commit_id.txt',
        'zooniverse/pandora' => 'https://translations.zooniverse.org/commit_id.txt',
        'zooniverse/talk-api' => 'https://talk.zooniverse.org/commit_id.txt',
        'zooniverse/zoo-stats-api-graphql' => 'https://graphql-stats.zooniverse.org',
        'zooniverse/zoo-event-stats' => 'https://stats.zooniverse.org/'
      }.freeze

      JSON_COMMIT_ID_KEYS = %w[revision commit_id].freeze
      DEPLOYED_BRANCH_REPOS = {
        'zooniverse/talk-api' => 'production',
        'zooniverse/zoo-stats-api-graphql' => 'master',
        'zooniverse/redsea' => 'main'
      }.freeze
      GH_PREVIEW_API_HEADERS = {
        'Accept': 'application/vnd.github.groot-preview+json',
        'User-Agent' => 'Httparty'
      }.freeze
      ORGIFY_REGEX = /\Azooniverse\/.*/.freeze

      def orgify_repo_name(repo_name)
        if repo_name.match(ORGIFY_REGEX)
          repo_name
        else
          "zooniverse/#{repo_name}"
        end
      end

      def get_latest_commit(repo_name)
        repo_name = orgify_repo_name(repo_name)
        # https://docs.github.com/en/free-pro-team@latest/rest/reference/repos#list-branches-for-head-commit
        # use the HEAD as that should be our default remote branch
        repo_url = "https://api.github.com/repos/#{repo_name}/commits/HEAD/branches-where-head"
        head_commit_response = HTTParty.get(repo_url, headers: GH_PREVIEW_API_HEADERS)
        if [404, 422].include?(head_commit_response.code)
          raise UnknonwnRepoCommit, "Can not get the currently deployed commit id of #{repo_name}"
        end

        # assumption - there should only be 1 default remote branch on GH
        head_commit_response[0].dig('commit', 'sha')
      end

      def get_repo_status(repo_name)
        repo_name = orgify_repo_name(repo_name)
        repo_url = repo_type_and_url(repo_name)
        deployed_version = get_deployed_commit(repo_url)
        production_tag = production_release_tag(repo_name)
        OpenStruct.new(
          status: :ok,
          body: get_app_status(repo_name, deployed_version, production_tag)
        )
      rescue UnknownServiceUrl
        OpenStruct.new(
          status: :error,
          body: status_error_response('No service is running on the url', repo_url)
        )
      rescue MissingStatusResponse
        OpenStruct.new(
          status: :error,
          body: status_error_response('Missing deployed status data on the service url', repo_url)
        )
      rescue MissingStatusResponseData
        OpenStruct.new(
          status: :error,
          body: status_error_response('Deployed status found on the service url but it has no data', repo_url)
        )
      rescue UnknownStatusResponseKey
        OpenStruct.new(
          status: :error,
          body: status_error_response('Unknown commit identifier in the status response body', repo_url)
        )
      rescue Octokit::NotFound
        OpenStruct.new(
          status: :error,
          body: status_error_response('Unknown deploy branch / tag target on the repo', repo_url)
        )
      end

      private

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
        # 404's are obs bad and we can't really use html page responses, rather we prefer text / json
        missing_status_response = repo_url_data.code == 404 || repo_url_data.content_type == 'text/html'
        raise MissingStatusResponse if missing_status_response

        repo_url_data
      rescue SocketError
        raise UnknownServiceUrl
      end
    end
  end
end
