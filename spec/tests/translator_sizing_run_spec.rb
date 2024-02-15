# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2022, Alliance for Sustainable Energy, LLC.
# BuildingSync(R), Copyright (c) 2015-2022, Alliance for Sustainable Energy, LLC.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER(S) AND ANY CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER(S), ANY CONTRIBUTORS, THE
# UNITED STATES GOVERNMENT, OR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF
# THEIR EMPLOYEES, BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# *******************************************************************************
require_relative './../spec_helper'

RSpec.describe 'BuildingSync' do
  describe 'Translator Sizing Runs Should Succeed and Create an in.osm' do
    tests_to_run = [
      # file_name, standard, epw_path, schema_version
      # Building 151
      ['building_151.xml', CA_TITLE24, nil, 'v2.4.0'],
      ['building_151.xml', ASHRAE90_1, nil, 'v2.4.0'],
      ['building_151.xml', CA_TITLE24, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.4.0'],
      ['building_151.xml', ASHRAE90_1, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.4.0'],

      # Building 151 n1
      ['building_151_n1.xml', CA_TITLE24, nil, 'v2.4.0'],
      ['building_151_n1.xml', ASHRAE90_1, nil, 'v2.4.0'],
      ['building_151_n1.xml', CA_TITLE24, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.4.0'],
      ['building_151_n1.xml', ASHRAE90_1, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.4.0'],

      ## building_151_level1
      ['building_151_level1.xml', CA_TITLE24, nil, 'v2.4.0'],
      ['building_151_level1.xml', ASHRAE90_1, nil, 'v2.4.0'],
      ['building_151_level1.xml', CA_TITLE24, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.4.0'],
      ['building_151_level1.xml', ASHRAE90_1, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.4.0'],

      # Building 151 multifamily
      ['building_151_multifamily.xml', ASHRAE90_1, nil, 'v2.4.0'],
      ['building_151_multifamily.xml', ASHRAE90_1, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.4.0'],

      # DC GSA Headquarters
      ['DC GSA Headquarters.xml', ASHRAE90_1, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.4.0'],

      # DC GSA Headquarters with Climate Zone
      ['DC GSA HeadquartersWithClimateZone.xml', ASHRAE90_1, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.4.0'],
      ['DC GSA HeadquartersWithClimateZone.xml', ASHRAE90_1, nil, 'v2.4.0'],

      # #####################################
      # ## L100 Audit
      # Trace/BPT trap: 5 gets hit for following 2 lines
      # ['L100_Audit.xml', CA_TITLE24, nil, 'v2.4.0', "Error, cannot find local component for: 1ed4ea50-edc6-0131-1b8b-48e0eb16a403.  Please try a different weather file."],
      # ['L100_Audit.xml', ASHRAE90_1, nil, 'v2.4.0', "Error, cannot find local component for: 1ed4ea50-edc6-0131-1b8b-48e0eb16a403.  Please try a different weather file."],
      ['L100_Audit.xml', CA_TITLE24, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.4.0'],
      ['L100_Audit.xml', ASHRAE90_1, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.4.0'],

      # #####################################
      # ## Golden File
      # Trace/BPT trap: 5 gets hit for following 2 lines
      # ['Golden Test File.xml', CA_TITLE24, nil, 'v2.4.0', "Error, cannot find local component for: fa8c9ff0-edc4-0131-a9f8-48e0eb16a403.  Please try a different weather file."],
      # ['Golden Test File.xml', ASHRAE90_1, nil, 'v2.4.0', "Error, cannot find local component for: fa8c9ff0-edc4-0131-a9f8-48e0eb16a403.  Please try a different weather file."],
      ['Golden Test File.xml', CA_TITLE24, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.4.0'],
      ['Golden Test File.xml', ASHRAE90_1, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.4.0'],

      # L000_OpenStudio_Pre-Simulation-01
      ['L000_OpenStudio_Pre-Simulation_01.xml', ASHRAE90_1, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.4.0'],

      # L000_OpenStudio_Pre-Simulation-02
      ['L000_OpenStudio_Pre-Simulation_02.xml', ASHRAE90_1, nil, 'v2.4.0'],
      ['L000_OpenStudio_Pre-Simulation_02.xml', CA_TITLE24, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.4.0'],
      ['L000_OpenStudio_Pre-Simulation_02.xml', ASHRAE90_1, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.4.0'],

      # L000_OpenStudio_Pre-Simulation-03
      ['L000_OpenStudio_Pre-Simulation_03.xml', ASHRAE90_1, nil, 'v2.4.0'],
      ['L000_OpenStudio_Pre-Simulation_03.xml', CA_TITLE24, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.4.0'],
      ['L000_OpenStudio_Pre-Simulation_03.xml', ASHRAE90_1, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.4.0'],

      # L000_OpenStudio_Pre-Simulation-04
      ['L000_OpenStudio_Pre-Simulation_04.xml', ASHRAE90_1, nil, 'v2.4.0'],
      ['L000_OpenStudio_Pre-Simulation_04.xml', CA_TITLE24, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.4.0'],
      ['L000_OpenStudio_Pre-Simulation_04.xml', ASHRAE90_1, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.4.0'],
      ['example-smalloffice-level1.xml', ASHRAE90_1, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.4.0'],

      # Office_Carolina
      ['Office_Carolina.xml', ASHRAE90_1, nil, 'v2.4.0'],
      ['Office_Carolina.xml', CA_TITLE24, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.4.0'],
      ['Office_Carolina.xml', ASHRAE90_1, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.4.0']
    ]
    tests_to_run.each do |test|
      it "File: #{test[0]}. Standard: #{test[1]}. EPW_Path: #{test[2]}. File Schema Version: #{test[3]}" do
        xml_path, output_path = create_xml_path_and_output_path(test[0], test[1], __FILE__, test[3])
        translator = translator_sizing_run_and_check(xml_path, output_path, test[2], test[1])
      end
    end
  end

  describe 'Translator Sizing Runs Should Fail' do
    tests_to_run = [
      # file_name, standard, epw_path, schema_version, expected_error_message

      #####################################
      ## BuildingSync Website Valid Schema
      ['BuildingSync Website Valid Schema.xml', CA_TITLE24, nil, 'v2.4.0', 'Building ID: Building001. OccupancyClassification must be defined at either the Site or Building level.'],
      ['BuildingSync Website Valid Schema.xml', ASHRAE90_1, nil, 'v2.4.0', 'Building ID: Building001. OccupancyClassification must be defined at either the Site or Building level.'],
      ['BuildingSync Website Valid Schema.xml', CA_TITLE24, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.4.0', 'Building ID: Building001. OccupancyClassification must be defined at either the Site or Building level.'],
      ['BuildingSync Website Valid Schema.xml', ASHRAE90_1, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.4.0', 'Building ID: Building001. OccupancyClassification must be defined at either the Site or Building level.'],

      # #####################################
      # ## DC GSA Headquarters
      # Really this fails because: [BuildingSync.GetBCLWeatherFile.download_weather_file_from_city_name] <1> Error, could not find uid for state DC and city Washington. Initial count of weather files: 10. Please try a different weather file.
      ['DC GSA Headquarters.xml', ASHRAE90_1, nil, 'v2.4.0', 'BuildingSync.Building.set_weather_and_climate_zone: epw_file_path is false: false'],
      ['DC GSA Headquarters.xml', CA_TITLE24, nil, 'v2.4.0', "BuildingSync.Building.determine_open_studio_standard: ERROR: Did not find a class called 'CBES Pre-1978_LargeOffice' to create in CaliforniaTitle24"],
      ['DC GSA Headquarters.xml', CA_TITLE24, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.4.0', "BuildingSync.Building.determine_open_studio_standard: ERROR: Did not find a class called 'CBES Pre-1978_LargeOffice' to create in CaliforniaTitle24"],

      ####################################
      # DC GSA HeadquartersWithClimateZone
      ['DC GSA HeadquartersWithClimateZone.xml', CA_TITLE24, nil, 'v2.4.0', "BuildingSync.Building.determine_open_studio_standard: ERROR: Did not find a class called 'CBES Pre-1978_LargeOffice' to create in CaliforniaTitle24"],
      ['DC GSA HeadquartersWithClimateZone.xml', CA_TITLE24, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.4.0', "BuildingSync.Building.determine_open_studio_standard: ERROR: Did not find a class called 'CBES Pre-1978_LargeOffice' to create in CaliforniaTitle24"],

      # #####################################
      # L000_OpenStudio_Pre-Simulation-01
      # TODO: Fix download BCL function or figure out workaround
      # Trace/BPT trap: 5 gets hit for following 2 lines
      # ['L000_OpenStudio_Pre-Simulation_01.xml', CA_TITLE24, nil, 'v2.4.0', "Error, cannot find local component for: 1fd3d630-edc5-0131-b802-48e0eb16a403.  Please try a different weather file."],
      # ['L000_OpenStudio_Pre-Simulation_01.xml', ASHRAE90_1, nil, 'v2.4.0', "Error, cannot find local component for: 1fd3d630-edc5-0131-b802-48e0eb16a403.  Please try a different weather file."],

      # We have issues with old CBES files
      ['L000_OpenStudio_Pre-Simulation_01.xml', CA_TITLE24, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.4.0', "BuildingSync.Building.determine_open_studio_standard: ERROR: Did not find a class called 'CBES Pre-1978_LargeOffice' to create in CaliforniaTitle24"],

      # #####################################
      # L000_OpenStudio_Pre-Simulation-02
      # Really this fails because: Could not determine the weather file for climate zone: CEC T24-CEC6A.
      ['L000_OpenStudio_Pre-Simulation_02.xml', CA_TITLE24, nil, 'v2.4.0', "Could not set weather file because climate zone 'CEC T24-CEC6A' is not in default weather map."],

      # #####################################
      # L000_OpenStudio_Pre-Simulation-03
      # Really this fails because: Could not determine the weather file for climate zone: CEC T24-CEC1A.
      ['L000_OpenStudio_Pre-Simulation_03.xml', CA_TITLE24, nil, 'v2.4.0', "Could not set weather file because climate zone 'CEC T24-CEC1A' is not in default weather map."],

      # #####################################
      # L000_OpenStudio_Pre-Simulation-04
      # Really this fails because: Could not determine the weather file for climate zone: CEC T24-CEC6A.
      ['L000_OpenStudio_Pre-Simulation_04.xml', CA_TITLE24, nil, 'v2.4.0', "Could not set weather file because climate zone 'CEC T24-CEC6A' is not in default weather map."],

      #####################################
      ## AT_example_property_report_25
      ['AT_example_property_report_25.xml', CA_TITLE24, nil, nil, 'Building ID: BuildingType-69900869908540. OccupancyClassification must be defined at either the Site or Building level.'],
      ['AT_example_property_report_25.xml', ASHRAE90_1, nil, nil, 'Building ID: BuildingType-69900869908540. OccupancyClassification must be defined at either the Site or Building level.'],
      ['AT_example_property_report_25.xml', CA_TITLE24, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), nil, 'Building ID: BuildingType-69900869908540. OccupancyClassification must be defined at either the Site or Building level.'],
      ['AT_example_property_report_25.xml', ASHRAE90_1, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), nil, 'Building ID: BuildingType-69900869908540. OccupancyClassification must be defined at either the Site or Building level.'],

      #####################################
      ## AT_example_report_332
      ['AT_example_report_332.xml', CA_TITLE24, nil, nil, 'Building ID: BuildingType-55083280. OccupancyClassification must be defined at either the Site or Building level.'],
      ['AT_example_report_332.xml', ASHRAE90_1, nil, nil, 'Building ID: BuildingType-55083280. OccupancyClassification must be defined at either the Site or Building level.'],
      ['AT_example_report_332.xml', CA_TITLE24, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), nil, 'Building ID: BuildingType-55083280. OccupancyClassification must be defined at either the Site or Building level.'],
      ['AT_example_report_332.xml', ASHRAE90_1, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), nil, 'Building ID: BuildingType-55083280. OccupancyClassification must be defined at either the Site or Building level.'],

      #####################################
      ## Office Carolina
      # Really this fails because: Could not determine the weather file for climate zone: CEC T24-CEC6A.
      ['Office_Carolina.xml', CA_TITLE24, nil, 'v2.4.0', "Could not set weather file because climate zone 'CEC T24-CEC6A' is not in default weather map."]
    ]
    tests_to_run.each do |file_name, standard, epw_path, schema_version, expected_error_message|
      it "Should fail with message: #{expected_error_message}" do
        puts "File: #{file_name}. Standard: #{standard}. EPW_Path: #{epw_path}. File Schema Version: #{schema_version}"
        xml_path, output_path = create_xml_path_and_output_path(file_name, standard, __FILE__, schema_version)

        expect {
          translator_sizing_run_and_check(xml_path, output_path, epw_path, standard)
        }. to raise_error(StandardError, expected_error_message)
      end
    end
  end
end
