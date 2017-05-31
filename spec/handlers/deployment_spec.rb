require "spec_helper"
require 'deployment'

describe Lita::Handlers::Deployment, lita_handler: true do
  describe 'locking' do
    it 'can be locked with reason' do
      send_command 'panoptes lock Will break other app'
      expect(replies.last).to eq("None shall pass.")
      send_command 'panoptes deploy'
      expect(replies.last).to eq("panoptes is version-locked by Test User: Will break other app")
    end

    it 'can be locked without reason' do
      send_command 'panoptes lock'
      expect(replies.last).to eq("None shall pass.")
      send_command 'panoptes deploy'
      expect(replies.last).to eq("panoptes is version-locked by Test User: No reason given")
    end
  end
end
