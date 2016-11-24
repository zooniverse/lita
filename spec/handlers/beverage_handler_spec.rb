require "spec_helper"
require 'beverage_handler'

describe Lita::BeverageHandler, lita_handler: true do
  it 'records a coffee' do
    send_command 'coffee'
    expect(replies.last).to eq("That's your 1st coffee today.")

    send_command 'coffee'
    expect(replies.last).to eq("That's your 2nd coffee today.")

    send_command 'coffee'
    expect(replies.last).to eq("That's your 3rd coffee today.")

    send_command 'coffee'
    expect(replies.last).to eq("That's your 4th coffee today.")
  end

  it 'records a tea' do
    send_command 'tea'
    expect(replies.last).to eq("That's your 1st tea today.")

    send_command 'tea'
    expect(replies.last).to eq("That's your 2nd tea today.")

    send_command 'tea'
    expect(replies.last).to eq("That's your 3rd tea today.")

    send_command 'tea'
    expect(replies.last).to eq("That's your 4th tea today.")
  end
end
