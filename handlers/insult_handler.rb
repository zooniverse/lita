module Lita
  class InsultHandler < Handler
    route /^insult (.*)$/, :insult, command: true

    def insult(response)
      user = response.matches[0][0]

      insult = HTTParty.get("http://www.randominsults.net", headers: {"User-Agent" => "Insultbot for Lita"}).strip
      insult = insult.gsub("\n", "").gsub(/.*<i>(.*)<\/i>.*/x, '\1').strip

      response.reply("#{user}: #{insult}")
    end
  end

  Lita.register_handler(InsultHandler)
end
