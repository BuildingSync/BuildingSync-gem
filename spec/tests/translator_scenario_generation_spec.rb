# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************
require_relative './../spec_helper'

require 'fileutils'
require 'parallel'
require 'rspec/expectations'

RSpec.describe 'BuildingSync' do
  describe 'Generate All Scenarios' do
    tests = get_tests
    tests.each do |test|
      xit "File: #{test[0]}. Standard: #{test[1]}. EPW_Path: #{test[2]}. File Schema Version: #{test[3]}. Expected Scenarios: #{test[4]}" do
        xml_path, output_path = create_xml_path_and_output_path(test[0], test[1], __FILE__, test[3])
        translator = translator_sizing_run_and_check(xml_path, output_path, test[2], test[1])
        translator.write_osws

        osw_files = []
        baseline_osw_files = []
        Dir.glob("#{output_path}/**/in.osw") { |osw| osw_files << osw }
        Dir.glob("#{output_path}/baseline/in.osw") { |osw| baseline_osw_files << osw }

        # Filter out nested OSW files created by measure sub-runners (e.g., create_typical_building_from_model)
        # These should not be counted as scenario OSWs
        osw_files_filtered = osw_files.reject do |osw|
          osw.include?('003_create_typical_building_from_model') || 
          osw.include?('create_typical_building_from_model_SR')
        end

        # We always expect there to only be one baseline osw file
        expect(baseline_osw_files.size).to eq 1

        # Here we test the actual number of additional scenarios that got created
        non_baseline_osws = osw_files_filtered - baseline_osw_files
        expect(non_baseline_osws.size).to eq test[4]
      end
    end
  end

  describe 'Generate Only CB Modeled Scenario' do
    tests = get_tests
    tests.each do |test|
      it "File: #{test[0]}. Standard: #{test[1]}. EPW_Path: #{test[2]}. File Schema Version: #{test[3]}. Expected Scenarios: 1" do
        xml_path, output_path = create_xml_path_and_output_path(test[0], test[1], __FILE__, test[3])
        translator = translator_sizing_run_and_check(xml_path, output_path, test[2], test[1])
        translator.write_osws(only_cb_modeled = true)

        osw_files = []
        baseline_osw_files = []
        Dir.glob("#{output_path}/**/in.osw") { |osw| osw_files << osw }
        Dir.glob("#{output_path}/baseline/in.osw") { |osw| baseline_osw_files << osw }

        # Filter out nested OSW files created by measure sub-runners (e.g., create_typical_building_from_model)
        # These should not be counted as scenario OSWs
        osw_files_filtered = osw_files.reject do |osw|
          osw.include?('003_create_typical_building_from_model') || 
          osw.include?('create_typical_building_from_model_SR')
        end

        # We always expect there to only be one baseline osw file
        expect(baseline_osw_files.size).to eq 1

        # Here we test the actual number of additional scenarios that got created
        non_baseline_osws = osw_files_filtered - baseline_osw_files
        expect(non_baseline_osws.size).to eq 1
      end
    end
  end
end
