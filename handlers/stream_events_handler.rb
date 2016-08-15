require 'pusher-client'

module Lita
  module Handlers
    class StreamEventsHandler < Handler
      on :connected, :connect_stream

      def connect_stream(payload)
        puts "Connecting to Pusher"

        @pusher.disconnect if @pusher

        @pusher = PusherClient::Socket.new('79e8e05ea522377ba6db', secure: true)
        @pusher.subscribe('panoptes')
        @pusher.subscribe('talk')
        @pusher.subscribe('ouroboros')

        @pusher['panoptes'].bind("classification")  { |data| Board.instance.pins[:panoptes_classification].trigger }
        @pusher['talk'].bind("comment")             { |data| Board.instance.pins[:talk_comment].trigger }
        @pusher['ouroboros'].bind("classification") { |data| Board.instance.pins[:ouroboros_classification].trigger }
        @pusher['ouroboros'].bind("comment")        { |data| Board.instance.pins[:ouroboros_comment].trigger }

        @pusher.connect(true)
      end
    end

    Lita.register_handler(StreamEventsHandler)
  end
end
