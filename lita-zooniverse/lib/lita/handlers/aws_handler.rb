require 'aws-sdk'

module Lita
  module Handlers
    class AWSHandler < Handler
      # insert handler code here
      route(/^aws ip (.*)$/, :ip, command: true, help: {"aws instances SEARCH_TERM" => "Looks for matching instances on AWS, and prints their IPs"})

      def ip(response)
        terms = response.matches[0][0].downcase.split(" ")
        response.reply("Searching for instances matching: #{terms.join(' AND ')}")

        resp = ec2.describe_instances
        reservations = resp.reservations
        instances = reservations.flat_map(&:instances)
        matches = instances.select do |instance|
          instance.tags.any? do |tag|
            terms.all? do |term|
              tag.value.downcase.include?(term)
            end
          end
        end

        matches.sort_by {|instance| instance.state.name }.each do |instance|
          tags = instance.tags.map {|tag| [tag.key, tag.value] }.sort_by(&:first).to_h.inspect
          response.reply("> #{instance.public_dns_name} (#{instance.state.name}, #{instance.instance_type}, #{tags})")
        end
      end

      private

      def ec2
        @ec2 ||= Aws::EC2::Client.new(region: "us-east-1")
      end

      Lita.register_handler(self)
    end
  end
end
