module Lita
  class BoardHandler < Handler
    on :connected, :reset_arduino

    def initialize(*args)
      super

      @initial_event_ignored = false

      Board.instance.pins[:big_red_button].listen do |status|
        if status == true && @initial_event_ignored
          source = Source.new(user: nil, room: 'C06D83QTD')
          # robot.send_messages source, pick_message
        end

        @initial_event_ignored = true
      end
    end

    def reset_arduino(payload)
      Board.instance.connect
    end

    def pick_message
      [
        "Somebody pressed the big red button, if you know what I mean and I think you do!",
        "Hey, stop pressing my buttons or I'll get physical with you.",
        "Ouch",
        "LAUNCHING NUKES IN 3... 2... 1..."
      ].sample
    end

    Lita.register_handler(BoardHandler)
  end
end
