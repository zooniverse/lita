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

        response_strings = matches.sort_by {|instance| instance.state.name }.map do |instance|
          name_tag = instance.tags.find {|tag| tag.key.downcase == "name" }
          name = name_tag ? name_tag.value : ""

          str = ""
          str += "> `#{instance.instance_id}`"
          str += " at `#{instance.public_ip_address.to_s.ljust(15)}`" if instance.public_ip_address
          str += " (#{instance.state.name}, #{instance.instance_type}, #{name})"
        end

        if response_strings.empty?
          response.reply("Nothing found")
        else
          response.reply(response_strings.join("\n"))
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
