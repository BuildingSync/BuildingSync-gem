# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2020, Alliance for Sustainable Energy, LLC.
# BuildingSync(R), Copyright (c) 2015-2020, Alliance for Sustainable Energy, LLC.
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
  describe "Translator Sizing Runs Should Succeed and Create an in.osm" do
    tests_to_run = [
        # file_name, standard, epw_path, schema_version
        # Building 151
        ['building_151.xml', CA_TITLE24, nil, 'v2.2.0'],
        ['building_151.xml', ASHRAE90_1, nil, 'v2.2.0'],
        ['building_151.xml', CA_TITLE24, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.2.0'],
        ['building_151.xml', ASHRAE90_1, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.2.0'],

        # Building 151 n1
        ['building_151_n1.xml', CA_TITLE24, nil, 'v2.2.0'],
        ['building_151_n1.xml', ASHRAE90_1, nil, 'v2.2.0'],
        ['building_151_n1.xml', CA_TITLE24, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.2.0'],
        ['building_151_n1.xml', ASHRAE90_1, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.2.0'],

        # L100 Audit
        ['L100_Audit.xml', CA_TITLE24, nil, 'v2.2.0'],
        ['L100_Audit.xml', ASHRAE90_1, nil, 'v2.2.0'],
        ['L100_Audit.xml', CA_TITLE24, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.2.0'],
        ['L100_Audit.xml', ASHRAE90_1, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.2.0'],

        # DC GSA Headquarters
        # The CA_TITLE24 version of this fails and is included in the next section
        ['DC GSA Headquarters.xml', ASHRAE90_1, nil, nil],
        ['DC GSA Headquarters.xml', ASHRAE90_1, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), nil],

        # DC GSA Headquarters with Climate Zone
        ['DC GSA HeadquartersWithClimateZone.xml', CA_TITLE24, nil, nil],
        ['DC GSA HeadquartersWithClimateZone.xml', ASHRAE90_1, nil, nil],
        ['DC GSA HeadquartersWithClimateZone.xml', CA_TITLE24, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), nil],
        ['DC GSA HeadquartersWithClimateZone.xml', ASHRAE90_1, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), nil],

        # BuildingSync Website Valid Schema
        ['BuildingSync Website Valid Schema.xml', CA_TITLE24, nil, nil],
        ['BuildingSync Website Valid Schema.xml', ASHRAE90_1, nil, nil],
        ['BuildingSync Website Valid Schema.xml', CA_TITLE24, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), nil],
        ['BuildingSync Website Valid Schema.xml', ASHRAE90_1, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), nil],

        # L000_OpenStudio_Pre-Simulaiton-01
        ['L000_OpenStudio_Pre-Simulation_01.xml', CA_TITLE24, nil, 'v2.2.0'],
        ['L000_OpenStudio_Pre-Simulation_01.xml', ASHRAE90_1, nil, 'v2.2.0'],
        ['L000_OpenStudio_Pre-Simulation_01.xml', CA_TITLE24, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.2.0'],
        ['L000_OpenStudio_Pre-Simulation_01.xml', ASHRAE90_1, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.2.0'],

        # L000_OpenStudio_Pre-Simulaiton-02
        ['L000_OpenStudio_Pre-Simulation_02.xml', CA_TITLE24, nil, 'v2.2.0'],
        ['L000_OpenStudio_Pre-Simulation_02.xml', ASHRAE90_1, nil, 'v2.2.0'],
        ['L000_OpenStudio_Pre-Simulation_02.xml', CA_TITLE24, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.2.0'],
        ['L000_OpenStudio_Pre-Simulation_02.xml', ASHRAE90_1, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.2.0'],

        # L000_OpenStudio_Pre-Simulaiton-03
        ['L000_OpenStudio_Pre-Simulation_03.xml', CA_TITLE24, nil, 'v2.2.0'],
        ['L000_OpenStudio_Pre-Simulation_03.xml', ASHRAE90_1, nil, 'v2.2.0'],
        ['L000_OpenStudio_Pre-Simulation_03.xml', CA_TITLE24, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.2.0'],
        ['L000_OpenStudio_Pre-Simulation_03.xml', ASHRAE90_1, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.2.0'],

        # L000_OpenStudio_Pre-Simulaiton-04
        ['L000_OpenStudio_Pre-Simulation_04.xml', CA_TITLE24, nil, 'v2.2.0'],
        ['L000_OpenStudio_Pre-Simulation_04.xml', ASHRAE90_1, nil, 'v2.2.0'],
        ['L000_OpenStudio_Pre-Simulation_04.xml', CA_TITLE24, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.2.0'],
        ['L000_OpenStudio_Pre-Simulation_04.xml', ASHRAE90_1, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.2.0'],
    ]
    tests_to_run.each do |test|
      it "File: #{test[0]}. Standard: #{test[1]}. EPW_Path: #{test[2]}. File Schema Version: #{test[3]}" do
        xml_path, output_path = create_xml_path_and_output_path(test[0], test[1], __FILE__, test[3])
        translator = translator_sizing_run_and_check(xml_path, output_path, test[2], test[1])
      end
    end
  end

  describe "Translator Sizing Runs Should Fail" do
    tests_to_run = [
        # file_name, standard, epw_path, schema_version, expected_error_message

        # DC GSA Headquarters
        ['DC GSA Headquarters.xml', CA_TITLE24, nil, nil, "Did not find a class called 'CBES Pre-1978_LargeOffice' to create in"],
        ['DC GSA Headquarters.xml', CA_TITLE24, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), nil, "Did not find a class called 'CBES Pre-1978_LargeOffice' to create in"],

        # Golden File
        ['Golden Test File.xml', ASHRAE90_1, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.2.0', 'Error: There is more than one (2) building attached to this site in your BuildingSync file.'],

        # AT_example_property_report_25
        ['AT_example_property_report_25.xml', ASHRAE90_1, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), nil, 'Error: There is more than one (3) building attached to this site in your BuildingSync file.'],

        # AT_example_report_332
        ['AT_example_report_332.xml', ASHRAE90_1, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), nil, 'Occupancy type Food service is not available in the building_and_system_types.json dictionary']
    ]
    tests_to_run.each do |test|
      it "Should fail with message: #{test[4]}" do
        puts "File: #{test[0]}. Standard: #{test[1]}. EPW_Path: #{test[2]}. File Schema Version: #{test[3]}"
        xml_path, output_path = create_xml_path_and_output_path(test[0], test[1], __FILE__, test[3])
        begin
          translator_sizing_run_and_check(xml_path, output_path, test[2], test[1])

          # should not get here
          expect(false).to be true
        rescue StandardError => e
          expect(e.message.to_s).to eql test[4]
        end
      end
    end

  end
end
