# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************

RSpec.describe 'BuildingSync' do
  # TODO: Add assertion
  it 'should support an absolute path of EPW' do
    standard_template = '90.1-2004'
    bldg_type = 'SmallOffice'
    climate_zone_standard_string = 'ASHRAE 169-2006-4'
    open_studio_standards = Standard.build("#{standard_template}_#{bldg_type}")
    model = OpenStudio::Model::Model.new
    epw_file_name = 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'
    epw_file_path = File.expand_path("./weather/#{epw_file_name}", File.dirname(__FILE__))

    begin
      open_studio_standards.model_add_design_days_and_weather_file(model, climate_zone_standard_string, epw_file_path)
    rescue StandardError => e
      OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.epw_test_spec', e.message)
    end
  end
end
