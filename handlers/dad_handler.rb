module Lita
	class DadHandler < Handler
		route /^dad\s?joke$/, :tell_joke, command: true

    def tell_joke(response)
      joke = HTTParty.get("https://icanhazdadjoke.com", headers: {"Accept" => "text/plain"}).strip
      response.reply(joke)
    end
	end

	Lita.register_handler(DadHandler)
end
