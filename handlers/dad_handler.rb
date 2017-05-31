module Lita
	class DadHandler < Handler
		route /dad\s?joke/, :tell_joke, command: true

    def tell_joke(response)
      joke = HTTParty.get("https://icanhazdadjoke.com", headers: {"Accept" => "text/plain"}).strip

      if joke && joke != ""
        response.reply(joke)
      else
        response.reply("Hmm, let me think. Ask me again later.")
      end
    end
	end

	Lita.register_handler(DadHandler)
end
