# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************
require_relative './../spec_helper'

require 'fileutils'
require 'parallel'

RSpec.describe 'SelectionTool' do
  it 'building_151.xml should be valid for version: 2.4.0' do
    # -- Setup
    file_name = 'building_151.xml'
    std = ASHRAE90_1
    version = '2.4.0'
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, "v#{version}")

    selection_tool = BuildingSync::SelectionTool.new(xml_path, version)
    expect(selection_tool.validate_schema).to be true
  end

  it 'building_151.xml should not be valid for version: 2.1.0' do
    # -- Setup
    file_name = 'building_151.xml'
    std = ASHRAE90_1
    version = '2.1.0'
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.4.0')

    selection_tool = BuildingSync::SelectionTool.new(xml_path, version)
    expect(selection_tool.validate_schema).to be false
  end

  it 'Example - Invalid Schema.xml should not be valid for version 2.1.0' do
    # -- Setup
    file_name = 'Example - Invalid Schema.xml'
    std = ASHRAE90_1
    version = '2.1.0'
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, "v#{version}")

    selection_tool = BuildingSync::SelectionTool.new(xml_path, version)

    expect(selection_tool.validate_schema).to be false
  end

  it 'Returns false when looking for validation results of an invalid use case' do
    # -- Setup
    file_name = 'building_151.xml'
    std = ASHRAE90_1
    version = '2.4.0'
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.4.0')

    selection_tool = BuildingSync::SelectionTool.new(xml_path, version)
    expect(selection_tool.validate_use_case('This use case does not exist')).to be false
  end

  describe 'Use Case Validation' do
    files_to_check = [
      'L000_OpenStudio_Pre-Simulation_01.xml',
      'L000_OpenStudio_Pre-Simulation_02.xml',

      # TODO: This should validate.  CZ should be able to be specified at the site level.
      'L000_OpenStudio_Pre-Simulation_03.xml',
      'L000_OpenStudio_Pre-Simulation_04.xml'
    ]
    files_to_check.each do |file|
      describe "#{file} Use Case Validation" do
        before(:all) do
          # -- Setup
          file_name = file
          std = ASHRAE90_1
          version = '2.4.0'
          xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, "v#{version}")

          @selection_tool = BuildingSync::SelectionTool.new(xml_path, version)
          expect(@selection_tool.validate_schema).to be true
        end
        expectations = [
          # use case name, should be valid?
          ['BRICR SEED', false],
          ['SEED', false],
          ['New York City Audit Use Case', false],
          ['L000 OpenStudio Pre-Simulation', true],
          ['L100 OpenStudio Pre-Simulation', false],
          ['L000 Preliminary Analysis', false],
          ['L100 Audit', false],
          ['L200 Audit', false]
        ]
        expectations.each do |e|
          it "Use Case #{e[0]} should be valid? #{e[1]}" do
            expect(@selection_tool.validate_use_case(e[0])).to be e[1]
          end
        end
      end
    end
  end

  describe 'Example – Valid Schema Invalid UseCase.xml' do
    before(:all) do
      # -- Setup
      file_name = 'Example – Valid Schema Invalid UseCase.xml'
      std = ASHRAE90_1
      version = '2.1.0'
      xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, "v#{version}")

      @selection_tool = BuildingSync::SelectionTool.new(xml_path, version)
      expect(@selection_tool.validate_schema).to be true
    end
    expectations = [
      ['BRICR SEED', false],
      # ['SEED', false],
      # ['New York City Audit Use Case', false],
      # ['L000 OpenStudio Simulation', false]
    ]
    expectations.each do |e|
      it "Use Case #{e[0]} should be valid? #{e[1]}" do
        expect(@selection_tool.validate_use_case(e[0])).to be e[1]
      end
    end
  end
end
