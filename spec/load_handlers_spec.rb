# frozen_string_literal: true

require "spec_helper"

describe 'load_handlers.rb' do
  it 'does not error loading all handlers' do
    expect { require_relative '../load_handlers'}.not_to raise_error
  end
end
