require 'httparty'
require 'octokit'

module Lita
  module Handlers
    class Reload < Handler
      # insert handler code here
      route(/^reload$/, :status, command: true)

      def status(response)
        response.reply(`git checkout Gemfile.lock`)
        response.reply(`git pull`)
        response.reply(`bundle install`)
        response.reply(`bundle update lita-bucket`)
        response.reply("Stopping myself now, hope upstart brings me back up!")
        Kernel.exit
      end

      Lita.register_handler(self)
    end
  end
end
