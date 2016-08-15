module Lita
  module Handlers
    # class Party
    #   attr_reader :board

    #   def initialize
    #     @board = Lita::Board.instance
    #     stop
    #   end

    #   def start
    #     board.digital_write([2, 3, 4], false)
    #   end

    #   def stop
    #     board.digital_write([2, 3, 4], true)
    #   end
    # end

    class PartyHandler < Handler
      # Board.instance.pins[:big_red_button].listen do |status|
      #   puts "BUTTON: #{status}"
      # end
    end

    Lita.register_handler(PartyHandler)
  end
end
