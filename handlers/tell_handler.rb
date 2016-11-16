module Lita
	class TellHandler < Handler
		route /^tell (.*) to (.*)$/, :tell, command: true
		route /^tell (.*) (.*)$/, :tell, command: true

    def tell(response)
      user = response.matches[0]
      what = response.matches[1]
      response.reply("#{user}: #{what}")
    end
	end

	Lita.register_handler(TellHandler)
end
