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
    it 'building_151.xml ASHRAE90_1 - SR, Baseline, gather_results and save_xml' do
      # -- Setup
      file_name = 'building_151.xml'
      std = ASHRAE90_1
      xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
      epw_file_path = File.join('../weather', 'CZ01RV2.epw')
      expect(File.exist?(epw_file_path)).to be true

      # -- Assert
      translator_write_run_baseline_gather_save_perform_all_checks(xml_path, output_path, epw_file_path, std)
    end

  it 'L100_Audit.xml ASHRAE90_1 - SR, Baseline, gather_results and save_xml' do
    # -- Setup
    file_name = 'L100_Audit.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
    epw_file_path = File.join('../weather', 'CZ01RV2.epw')
    expect(File.exist?(epw_file_path)).to be true

    # -- Assert
    translator_write_run_baseline_gather_save_perform_all_checks(xml_path, output_path, epw_file_path, std)
  end

  it 'L000_OpenStudio_Pre-Simulation_01.xml ASHRAE90_1 - SR, Baseline, gather_results and save_xml' do
    # -- Setup
    file_name = 'L000_OpenStudio_Pre-Simulation_01.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
    epw_file_path = File.join('../weather', 'CZ01RV2.epw')

    # -- Assert
    translator_write_run_baseline_gather_save_perform_all_checks(xml_path, output_path, epw_file_path, std)
  end

  it 'L000_OpenStudio_Pre-Simulation_02.xml ASHRAE90_1 - SR, Baseline, gather_results and save_xml' do
    # -- Setup
    file_name = 'L000_OpenStudio_Pre-Simulation_02.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__,'v2.2.0')
    epw_path = nil

    translator_write_run_baseline_gather_save_perform_all_checks(xml_path, output_path, epw_path, std)
  end

  it 'L000_OpenStudio_Pre-Simulation_03.xml ASHRAE90_1 - SR, Baseline, gather_results and save_xml' do
    # -- Setup
    file_name = 'L000_OpenStudio_Pre-Simulation_03.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__,'v2.2.0')
    epw_path = nil

    translator_write_run_baseline_gather_save_perform_all_checks(xml_path, output_path, epw_path, std)
  end

  it 'L000_OpenStudio_Pre-Simulation_04.xml ASHRAE90_1 - SR, Baseline, gather_results and save_xml' do
    # -- Setup
    file_name = 'L000_OpenStudio_Pre-Simulation_04.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
    epw_file_path = File.join('../weather', 'CZ01RV2.epw')

    # -- Assert
    translator_write_run_baseline_gather_save_perform_all_checks(xml_path, output_path, epw_file_path, std)
  end

  it 'Office_Carolina.xml ASHRAE90_1 - SR, Baseline, gather_results and save_xml' do
    # -- Setup
    file_name = 'Office_Carolina.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
    epw_file_path = File.join('../weather', 'CZ01RV2.epw')

    # -- Assert
    translator_write_run_baseline_gather_save_perform_all_checks(xml_path, output_path, epw_file_path, std)
  end
end