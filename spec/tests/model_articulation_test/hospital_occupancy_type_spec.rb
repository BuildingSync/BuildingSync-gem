# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************
require 'builder'
require 'buildingsync/generator'

require_relative './../../spec_helper'

RSpec.describe 'OccupancyTypeSpec' do
  it 'Should generate osm and simulate baseline for OccupancyType: Hospital' do
    run_minimum_facility('Health care-Inpatient hospital', '2002', 'Gross', '50000', ASHRAE90_1, 'occupancy_types_spec')
  end
end
