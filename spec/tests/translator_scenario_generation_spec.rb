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

require 'fileutils'
require 'parallel'

RSpec.describe 'BuildingSync' do
  before(:all) do
    @tests = [
        # file_name, standard, epw_path, schema_version, expected_scenarios
        ['building_151.xml', ASHRAE90_1, nil, 'v2.2.0', 30],
        ['building_151_n1.xml', ASHRAE90_1, nil, 'v2.2.0', 30],
        ['DC GSA Headquarters.xml', ASHRAE90_1, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), nil, 1],
        ['DC GSA HeadquartersWithClimateZone.xml', ASHRAE90_1, nil, nil, 1],
        ['L000_OpenStudio_Pre-Simulation_01.xml', ASHRAE90_1, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.2.0'],
        ['L000_OpenStudio_Pre-Simulation_02.xml', ASHRAE90_1, nil, 'v2.2.0', 1],
        ['L000_OpenStudio_Pre-Simulation_03.xml', ASHRAE90_1, nil, 'v2.2.0', 1],
        ['L000_OpenStudio_Pre-Simulation_04.xml', ASHRAE90_1, nil, 'v2.2.0', 1],

        # Test once issues get fixed
        # See translator_sizing_run_spec errors
        #
        # ['building_151_level1.xml', ASHRAE90_1, nil, 'v2.2.0', 30],
        # ['L100_Audit.xml', CA_TITLE24, nil, 'v2.2.0', 2],
        # ['Golden Test File.xml', CA_TITLE24, nil, 'v2.2.0', 2],

        # These have inherent flaws in their file structure and will not pass
        # They are kept here for reference.
        # See translator_sizing_run_spec errors
        #
        # - BuildingSync Website Valid Schema.xml (OccupancyClassification not defined)
        # - AT_example_property_report_25 (OccupancyClassification not defined)

    ]
  end
  describe "Generate All Scenarios" do
    @tests.each do |test|
      it "File: #{test[0]}. Standard: #{test[1]}. EPW_Path: #{test[2]}. File Schema Version: #{test[3]}. Expected Scenarios: #{test[4]}" do
        xml_path, output_path = create_xml_path_and_output_path(test[0], test[1], __FILE__, test[3])
        translator = translator_sizing_run_and_check(xml_path, output_path, test[2], test[1])
        translator.write_osws

        osw_files = []
        osw_sr_files = []
        Dir.glob("#{output_path}/**/in.osw") { |osw| osw_files << osw }
        Dir.glob("#{output_path}/SR/in.osw") { |osw| osw_sr_files << osw }

        # We always expect there to only be one
        # sizing run file
        expect(osw_sr_files.size).to eq 1

        # Here we test the actual number of additional scenarios that got created
        non_sr_osws = osw_files - osw_sr_files
        expect(non_sr_osws.size).to eq test[4]
      end
    end
  end

  describe "Generate Only CB Modeled Scenario" do
    @tests.each do |test|
      it "File: #{test[0]}. Standard: #{test[1]}. EPW_Path: #{test[2]}. File Schema Version: #{test[3]}. Expected Scenarios: #{test[4]}" do
        xml_path, output_path = create_xml_path_and_output_path(test[0], test[1], __FILE__, test[3])
        translator = translator_sizing_run_and_check(xml_path, output_path, test[2], test[1])
        translator.write_osws(only_cb_modeled = true)

        osw_files = []
        osw_sr_files = []
        Dir.glob("#{output_path}/**/in.osw") { |osw| osw_files << osw }
        Dir.glob("#{output_path}/SR/in.osw") { |osw| osw_sr_files << osw }

        # We always expect there to only be one
        # sizing run file
        expect(osw_sr_files.size).to eq 1

        # Here we test the actual number of additional scenarios that got created
        non_sr_osws = osw_files - osw_sr_files
        expect(non_sr_osws.size).to eq test[4]
      end
    end
  end
end
