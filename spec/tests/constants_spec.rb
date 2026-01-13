# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************
require_relative '../spec_helper'
require 'buildingsync/constants'

RSpec.describe 'BuildingSync constants' do
  it 'should have a SCHEMA_2_0_URL' do
    expect(SCHEMA_2_0_URL).to eq('https://raw.githubusercontent.com/BuildingSync/schema/v2.0/BuildingSync.xsd')
  end
  it 'should have a SCHEMA_2_2_0_URL' do
    expect(SCHEMA_2_2_0_URL).to eq('https://raw.githubusercontent.com/BuildingSync/schema/v2.2.0/BuildingSync.xsd')
  end
  it 'should have a SCHEMA_2_4_0_URL' do
    expect(SCHEMA_2_4_0_URL).to eq('https://raw.githubusercontent.com/BuildingSync/schema/v2.4.0/BuildingSync.xsd')
  end
  it 'should have a WORKFLOW_MAKER_JSON_FILE_PATH and the file should exist' do
    expect(File.exist?(WORKFLOW_MAKER_JSON_FILE_PATH)).to be true
  end
  it 'should have standards strings' do
    expect(ASHRAE90_1).to eql 'ASHRAE90.1'
    expect(CA_TITLE24).to eql 'CaliforniaTitle24'
  end
end
