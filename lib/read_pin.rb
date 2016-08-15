module Lita
  class ReadPin
    MIN_INTERVAL = 5

    attr_reader :board, :pin, :state, :on_until

    def initialize(board, pin)
      @board = board
      @pin = pin
      @listeners = []
      @timeout = Time.now + MIN_INTERVAL
    end

    def listen(&block)
      @listeners << block
    end

    def publish(status)
      return if Time.now < @timeout

      puts "Pin #{pin} status #{status}"

      @timeout = Time.now + MIN_INTERVAL
      @listeners.each do |listener|
        listener.call(status)
      end
    end
  end
end
