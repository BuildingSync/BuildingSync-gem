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

  it 'should add a new EnergyPlus measure' do
    # -- Setup
    file_name = 'building_151_one_scenario.xml'
    std = CA_TITLE24
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
    epw_path = nil

    if File.exist?(output_path)
      FileUtils.rm_rf(output_path)
    end

    # -- Assert
    expect(File.exist?(xml_path)).to be true
    expect(File.exist?(output_path)).to be false

    # -- Setup
    FileUtils.mkdir_p(output_path)
    expect(File.exist?(output_path)).to be true

    translator = BuildingSync::Translator.new(xml_path, output_path, epw_path, std)
    translator.insert_energyplus_measure('scale_geometry', 1)
    translator.sizing_run_and_write_osm
    translator.write_osws
    translator.run_osws
    osw_files = []
    Dir.glob("#{output_path}/Baseline/in.osw") { |osw| osw_files << osw }
    osw_files.each do |osw|
      sql_file = osw.gsub('in.osw', 'eplusout.sql')
      puts "Simulation not completed successfully for file: #{osw}" if !File.exist?(sql_file)
      expect(File.exist?(sql_file)).to be true
    end
  end

  it 'remove all measures and then add a new EnergyPlus measure' do
    # -- Setup
    file_name = 'building_151_no_measures.xml'
    std = CA_TITLE24
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__,'v2.2.0')
    epw_path = nil

    if File.exist?(output_path)
      FileUtils.rm_rf(output_path)
    end

    # -- Assert
    expect(File.exist?(xml_path)).to be true
    expect(File.exist?(output_path)).to be false

    # -- Setup
    FileUtils.mkdir_p(output_path)
    expect(File.exist?(output_path)).to be true

    translator = BuildingSync::Translator.new(xml_path, output_path, epw_path, std)
    translator.clear_all_measures
    translator.insert_energyplus_measure('scale_geometry', 1)
    translator.sizing_run_and_write_osm
    translator.write_osws
    translator.run_osws
    osw_files = []
    Dir.glob("#{output_path}/Baseline/in.osw") { |osw| osw_files << osw }
    osw_files.each do |osw|
      sql_file = osw.gsub('in.osw', 'eplusout.sql')
      puts "Simulation not completed successfully for file: #{osw}" if !File.exist?(sql_file)
      expect(File.exist?(sql_file)).to be true
    end
  end

  it 'should add a new Reporting measure' do
    # -- Setup
    file_name = 'building_151_one_scenario.xml'
    std = CA_TITLE24
    xml_path, output_path = create_xml_path_and_output_path(file_name, std,__FILE__, 'v2.2.0')
    epw_path = nil

    if File.exist?(output_path)
      FileUtils.rm_rf(output_path)
    end

    # -- Assert
    expect(File.exist?(xml_path)).to be true
    expect(File.exist?(output_path)).to be false

    # -- Setup
    FileUtils.mkdir_p(output_path)
    expect(File.exist?(output_path)).to be true

    translator = BuildingSync::Translator.new(xml_path, output_path, epw_path, std)
    translator.insert_reporting_measure('openstudio_results', 0)
    translator.sizing_run_and_write_osm
    translator.write_osws
    translator.run_osws
    osw_files = []
    Dir.glob("#{output_path}/Baseline/in.osw") { |osw| osw_files << osw }
    osw_files.each do |osw|
      sql_file = osw.gsub('in.osw', 'eplusout.sql')
      puts "Simulation not completed successfully for file: #{osw}" if !File.exist?(sql_file)
      expect(File.exist?(sql_file)).to be true
    end
  end

  it 'should write parameter value into XML' do
    # -- Setup
    file_name = 'building_151_one_scenario.xml'
    std = CA_TITLE24
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
    epw_path = nil

    if File.exist?(output_path)
      FileUtils.rm_rf(output_path)
    end

    # -- Assert
    expect(File.exist?(xml_path)).to be true
    expect(File.exist?(output_path)).to be false

    # -- Setup
    FileUtils.mkdir_p(output_path)
    expect(File.exist?(output_path)).to be true

    translator = BuildingSync::Translator.new(xml_path, output_path, epw_path, std)
    translator.sizing_run_and_write_osm
    translator.write_osws

    results_xml = File.join(output_path, 'results.xml')
    translator.prepare_final_xml(results_xml)
    expect(File.exist?(results_xml)).to be true
  end

end
