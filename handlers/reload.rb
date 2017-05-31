require 'httparty'
require 'octokit'

module Lita
  module Handlers
    class Reload < Handler
      # insert handler code here
      route(/^reload$/, :deploy, command: true, help: {"reload" => "Fetches the latest code, installs gems and restarts Lita."})
      route(/^lita deploy$/, :deploy, command: true)

      def deploy(response)
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
