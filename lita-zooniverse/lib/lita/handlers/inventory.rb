module Lita
  module Handlers
    class Inventory < Handler
      config :size, default: 5

      # insert handler code here
      route(/^take\s+(?<item>.+)/, :take, command: true)
      route(/^give me something/, :give, command: true)
      route(/^inventory\?/, :inventory, command: true)

      def take(response)
        item = response.match_data[:item]

        if has_item?(item)
          response.reply([
            "No thanks, I've already got one.",
            "I already have #{item}",
            "But I've already got #{item}!"
          ].sample)
        elsif dropped_item = add_item(item.strip)
          response.reply("drops #{dropped_item} and takes #{item}.")
        else
          response.reply("takes #{item}.")
        end
      end

      def give(response)
        item = drop_item

        if item
          response.reply("gives <@#{response.user.id}> #{item}.")
        else
          response.reply("I'm empty!")
        end
      end

      def inventory(response)
        items = redis.smembers("inventory")

        if items.empty?
          response.reply("I'm empty!")
        else
          response.reply("contains #{sentence(items)}.")
        end
      end

      private

      def add_item(item)
        if redis.scard("inventory") >= config.size
          dropped_item = drop_item
        end

        redis.sadd("inventory", item.strip)
        dropped_item
      end

      def has_item?(item)
        redis.sismember("inventory", item)
      end

      def drop_item
        redis.srandmember("inventory").tap do |item|
          redis.srem("inventory", item)
        end
      end

      def sentence(array)
        case array.size
        when 0
          "nothing at all"
        when 1
          array[0]
        when 2
          array[0] + " and " + array[1]
        else
          array[0..-2].join(", ") + ", and " + array[-1]
        end
      end

      Lita.register_handler(self)
    end
  end
end
