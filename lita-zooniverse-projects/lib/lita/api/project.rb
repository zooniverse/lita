require 'httparty'

module Lita
  module Api
    module Project

      attr_reader :search_query

      def initialize(search_query)
        @search_query = search_query
      end

      private

      def api_headers
        {"Content-Type" => "application/json", "Accept" => "application/json"}
      end
    end
  end
end
