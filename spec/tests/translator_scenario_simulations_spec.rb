# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************
require_relative './../spec_helper'

require 'fileutils'
require 'parallel'

RSpec.describe 'BuildingSync' do
  describe 'Translator Simulate Full Workflow' do
    tests = get_tests
    tests.each do |test|
      it "File: #{test[0]}. Standard: #{test[1]}. EPW_Path: #{test[2]}. File Schema Version: #{test[3]}. Expected Scenarios: #{test[4]}" do
        xml_path, output_path = create_xml_path_and_output_path(test[0], test[1], __FILE__, test[3])
        translator = translator_sizing_run_and_check(xml_path, output_path, test[2], test[1])
        results_file_path = File.join(output_path, 'results.xml')

        # Write OSWs and check
        translator_write_osws_and_check(translator, output_path, test[4])

        translator.run_osws

        # Checks all osws have been simulated
        # TODO: Fix the measures causing Building 151 to fail
        if !test[0].include?('building_151')
          check_osws_simulated(output_path, test[4])
        end

        # -- Asserts ResourceUses are created with 12 months of timeseries data
        expected_resource_uses = ['Electricity', 'Natural gas']
        # TODO: Fix the measures causing Building 151 to fail
        if !test[0].include?('building_151')
          translator_gather_results_checks(translator, expected_resource_uses)
        end

        translator.prepare_final_xml

        # -- Assert final_xml_prepared set to true
        expect(translator.final_xml_prepared).to be true

        # -- Assert - Save XML and check
        translator_save_xml_checks(translator, results_file_path)
      end
    end
  end
end
