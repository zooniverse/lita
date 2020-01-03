require 'a_vs_an'

module Lita
  module Handlers
    class Lintott < Handler
      config :api_key, required: Lita.required_config?

      route(/^locate lintott/, :lintott, command: true, help: {"locate lintott" => "Finds lintott"})

      def lintott(response)
        json    = HTTParty.get(url)
        checkin = json["response"]["checkins"]["items"][0]
        place   = checkin["venue"]["name"]
        time    = Time.at(checkin["createdAt"])
        type    = checkin["venue"]["categories"][0]["name"]
        an_type = "#{AVsAn.query(type)} #{type}"
        text    = ".@chrislintott last spotted on #{time} at #{place}, which is #{an_type}"
        response.reply(text)
      rescue StandardError => e
        response.reply("Not sure. Try shouting really loudly. (#{e.message})")
      end

      def url
        "https://api.foursquare.com/v2/users/self/checkins?oauth_token=#{config.api_key}&v=20141210"

      end

      Lita.register_handler(self)
    end
  end
end
