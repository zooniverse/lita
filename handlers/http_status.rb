# frozen_string_literal: true

module Lita
  module Handlers
    class HttpStatus < Handler
      http.get '/' do |request, response|
        response.body << 'Hello, Lita is alive!'
      end

      Lita.register_handler(self)
    end
  end
end
