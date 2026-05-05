# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************
require_relative './../spec_helper'

require 'fileutils'
require 'parallel'
require 'openstudio-extension'

RSpec.describe 'BuildingSync' do
  it 'should have a version' do
    expect(BuildingSync::VERSION).not_to be_nil
  end

  it 'has a measures directory' do
    instance = BuildingSync::Extension.new
    measure_path = File.expand_path('../../lib/measures', File.dirname(__FILE__))
    expect(instance.measures_dir).to eq measure_path
    expect(Dir.exist?(instance.measures_dir)).to eq true
  end
end
