require "spec_helper"

describe Lita::Handlers::Inventory, lita_handler: true do
  let(:carl) { Lita::User.create(123, name: "Carl") }

  before do
    srand 123
  end

  describe 'inventory' do
    it 'is proper english when empty' do
      send_command("inventory?")
      expect(replies.last).to eq("I'm empty!")
    end

    it 'is proper english when it has one item' do
      send_command("take a hammer")
      send_command("inventory?")
      expect(replies.last).to eq("contains a hammer.")
    end

    it 'is proper english when it has two items' do
      send_command("take a hammer")
      send_command("take a nail")
      send_command("inventory?")
      expect(replies.last).to eq("contains a nail and a hammer.")
    end

    it 'is proper english when it has many items' do
      send_command("take a hammer")
      send_command("take someone's bad joke")
      send_command("take some json data")
      send_command("inventory?")
      expect(replies.last).to eq("contains some json data, someone's bad joke, and a hammer.")
    end
  end

  describe 'taking items' do
    it 'takes items' do
      send_command("take a hammer")
      expect(replies.last).to eq("takes a hammer.")
    end

    it 'rejects duplicates' do
      send_command("take a hammer")
      send_command("take a hammer")
      expect(replies.last).to eq("But I've already got a hammer!")
    end

    it 'drops items when full' do
      send_command("take one")
      send_command("take two")
      send_command("take three")
      send_command("take four")
      send_command("take five")
      send_command("take six")

      expect(replies.last).to match("drops (one|two|three|four|five) and takes six.")
    end
  end

  describe 'giving items' do
    it 'cannot give an item when empty' do
      send_command("give me something", as: carl)
      expect(replies.last).to match("I'm empty!")
    end

    it 'gives a random item' do
      send_command("take one")
      send_command("take two")
      send_command("take three")

      send_command("give me something", as: carl)
      expect(replies.last).to match("gives <@123> (one|two|three|four|five).")
    end
  end

  describe 'inventions' do
    it 'makes things' do
      send_command("take one")
      send_command("take two")
      send_command("take three")
      send_command("invent something")
      expect(replies.last).to match("I fire (one|two|three) out of a giant cannon into (one|two|three) and it actually worked! After a puff of smoke, (one|two|three) appears!")
    end
  end
end
