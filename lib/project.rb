require 'httparty'

module Lita
  module Api
    module Project

      attr_reader :project

      def initialize(project)
        @project = project
      end

      def to_s
        raise NotImplementedError.new
      end
    end
  end
end
