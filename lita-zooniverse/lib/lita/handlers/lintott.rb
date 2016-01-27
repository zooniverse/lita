require_relative '../api/panoptes_project'
require_relative '../api/ouroboros_project'

require 'a_vs_an'

module Lita
  module Handlers
    class Lintott < Handler
      URL = "https://api.foursquare.com/v2/users/self/checkins?oauth_token=MBED45EKO3PRI550U4BYVURBUEFRQTVVYQJMVVKSHRPKQ13W&v=20141210"

      route(/^locate lintott/, :lintott, command: true, help: {"locate lintott" => "Finds lintott"})

      def lintott(response)
        response.reply("Checking...")
        json    = HTTParty.get(URL)
        checkin = json["response"]["checkins"]["items"][0]
        place   = checkin["venue"]["name"]
        time    = Time.at(checkin["createdAt"])
        type    = checkin["venue"]["categories"][0]["name"]
        an_type = "#{AVsAn.query(type)} #{type}"
        text    = ".@chrislintott last spotted on #{time} at #{place}, which is #{an_type}"
        response.reply(text)
      rescue StandardError => e
        response.reply("Not sure. Try shouting really hard. (#{e.message})")
      end

      Lita.register_handler(self)
    end
  end
end
