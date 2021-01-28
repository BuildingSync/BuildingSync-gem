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

RSpec.describe 'SelectionTool' do
  it 'building_151.xml should be valid for version: 2.2.0' do
    # -- Setup
    file_name = 'building_151.xml'
    std = ASHRAE90_1
    version = '2.2.0'
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, "v#{version}")

    selection_tool = BuildingSync::SelectionTool.new(xml_path, version)
    expect(selection_tool.validate_schema).to be true
  end

  it 'building_151.xml should not be valid for version: 2.1.0' do
    # -- Setup
    file_name = 'building_151.xml'
    std = ASHRAE90_1
    version = '2.1.0'
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')

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
    version = '2.2.0'
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')

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
          version = '2.2.0'
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
