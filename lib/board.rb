require 'singleton'
require_relative 'timed_pin'
require_relative 'read_pin'

module Lita
  class Board
    include Singleton

    attr_reader :arduino, :pins

    def initialize
      @pins = {
        panoptes_classification: TimedPin.new(self, 12),
        talk_comment: TimedPin.new(self, 13),
        ouroboros_classification: TimedPin.new(self, 10),
        ouroboros_comment: TimedPin.new(self, 11),
        big_red_button: ReadPin.new(self, 9),
	party1: TimedPin.new(self, 7, true),
	party2: TimedPin.new(self, 6, true),
	party3: TimedPin.new(self, 5, true),
	party4: TimedPin.new(self, 4, true)
      }

      connect
    end

    def connect
      return if @arduino

      puts "Connecting to Arduino"
      @arduino = ArduinoFirmata.connect
      @arduino.pin_mode 9, ArduinoFirmata::INPUT
      @arduino.on :digital_read do |pin, status|
        begin
          if pin == 9
            Board.instance.pins[:big_red_button].publish(status)
          end
        rescue StandardError => ex
          puts "="*100
          puts ex.message
          puts ex.backtrace
        end
      end
  
      digital_write([7,6,5,4], true)

      puts "Connected to Arduino"
    end

    def digital_write(pins, value)
      pins = Array(pins)
      pins.each { |pin| arduino.digital_write(pin, value) }
    end
  end
end
