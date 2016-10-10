module Lita
	class PartyHandler < Handler
		route /^party$/, :party, command: true
    route /^party pooper$/, :pooper, command: true

    def party(response)
			Board.instance.pins[:party1].trigger(120)
      Board.instance.pins[:party2].trigger(120)

			response.reply("A PARTY HAS BEGUN!")
    end

    def pooper(response)
      Board.instance.pins[:party1].cancel
      Board.instance.pins[:party2].cancel

      response.reply(":sadpanda:")
    end

	end

	Lita.register_handler(PartyHandler)
end
