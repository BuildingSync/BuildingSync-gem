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
  describe "Translator Should Perform a Sizing Run, then write and run ONLY the cb_modeled Scenario" do
    tests_to_run = [
        # file_name, standard, epw_path, schema_version
        ['building_151.xml', ASHRAE90_1, nil, 'v2.2.0'],
        ['building_151.xml', CA_TITLE24, nil, 'v2.2.0'],
        ['building_151.xml', ASHRAE90_1, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.2.0'],
        ['building_151.xml', CA_TITLE24, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.2.0'],
    ]
    tests_to_run.each do |test|
      it "File: #{test[0]}. Standard: #{test[1]}. EPW_Path: #{test[2]}. File Schema Version: #{test[3]}" do
        xml_path, output_path = create_xml_path_and_output_path(test[0], test[1], __FILE__, test[3])
        translator = translator_sizing_run_and_check(xml_path, output_path, test[2], test[1])
        translator.write_osws(only_cb_modeled = true)

        failures = translator.run_osws()
      end
    end
  end


  it 'building_151_level1.xml ASHRAE90_1 - SR, Baseline' do
    # -- Setup
    file_name = 'building_151_level1.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
    epw_file_path = File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw')

    # -- Assert
    translator = translator_sizing_run_and_check(xml_path, output_path, epw_file_path, std)
    translator.run_baseline_osm(epw_file_path)
    translator_run_baseline_osm_checks(output_path)
  end

  it 'DC GSA Headquarters.xml ASHRAE90_1 - SR, Baseline' do
    # -- Setup
    file_name = 'DC GSA Headquarters.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__)
    epw_file_path = File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw')

    # -- Assert
    translator = translator_sizing_run_and_check(xml_path, output_path, epw_file_path, std)
    translator.run_baseline_osm(epw_file_path)
    translator_run_baseline_osm_checks(output_path)
  end

  it 'BuildingSync Website Valid Schema.xml CA_TITLE24 - SR, Baseline' do
    # -- Setup
    file_name = 'BuildingSync Website Valid Schema.xml'
    std = CA_TITLE24
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__)
    epw_file_path = File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw')

    # -- Assert
    translator = translator_sizing_run_and_check(xml_path, output_path, epw_file_path, std)
    translator.run_baseline_osm(epw_file_path)
    translator_run_baseline_osm_checks(output_path)
  end

  it 'BuildingSync Website Valid Schema.xml ASHRAE90_1 - SR, Baseline' do
    # -- Setup
    file_name = 'BuildingSync Website Valid Schema.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__)
    epw_file_path = File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw')

    # -- Assert
    translator = translator_sizing_run_and_check(xml_path, output_path, epw_file_path, std)
    translator.run_baseline_osm(epw_file_path)
    translator_run_baseline_osm_checks(output_path)
  end

  it 'should parse report_478.xml and issue an exception that it contains 2 basement stories' do
    # -- Setup
    file_name = 'report_478.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__)
    epw_file_path = File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw')
    begin
      translator = translator_sizing_run_and_check(xml_path, output_path, epw_file_path, std)
    rescue StandardError => e
      puts "e.message #{e.message}"
      expect(e.message.include?('Number of stories below grade is larger than 1: 2.0, currently only one basement story is supported.')).to be true
    end
  end
end
