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
  it 'should print out all available measure paths' do
    workflow_maker = BuildingSync::WorkflowMaker.new(nil, nil)
    list_of_measures = workflow_maker.get_list_of_available_measures
    count = 0
    list_of_measures.each do |path, list|
      puts "measure path: #{path} with #{list.length} measures"
      count += list.length
      list.each do |measure_path_name|
        puts "     measure name : #{measure_path_name}"
      end
    end
    puts "found #{count} measures"
  end

  it 'should check if all measures are available' do
    workflow_maker = BuildingSync::WorkflowMaker.new(nil, nil)
    expect(workflow_maker.check_if_measures_exist).to be true
  end

  it 'should add a new EnergyPlus measure' do
    xml_path = File.expand_path('./../files/building_151_one_scenario.xml', File.dirname(__FILE__))
    expect(File.exist?(xml_path)).to be true

    out_path = File.expand_path('./../output/building_151_one_scenario/', File.dirname(__FILE__))

    if File.exist?(out_path)
      FileUtils.rm_rf(out_path)
    end
    # expect(File.exist?(out_path)).not_to be true

    FileUtils.mkdir_p(out_path)
    expect(File.exist?(out_path)).to be true

    epw_file_path = nil

    translator = BuildingSync::Translator.new(xml_path, out_path, epw_file_path, CA_TITLE24)
    translator.insert_energyplus_measure('scale_geometry', 1)
    translator.write_osm
    translator.write_osws
    translator.run_osws
    osw_files = []
    Dir.glob("#{out_path}/Baseline/in.osw") { |osw| osw_files << osw }
    osw_files.each do |osw|
      sql_file = osw.gsub('in.osw', 'eplusout.sql')
      puts "Simulation not completed successfully for file: #{osw}" if !File.exist?(sql_file)
      expect(File.exist?(sql_file)).to be true
    end
  end

  it 'remove all measures and the add a new EnergyPlus measure' do
    xml_path = File.expand_path('./../files/building_151_no_measures.xml', File.dirname(__FILE__))
    expect(File.exist?(xml_path)).to be true

    out_path = File.expand_path('./../output/building_151_no_measures/', File.dirname(__FILE__))

    if File.exist?(out_path)
      FileUtils.rm_rf(out_path)
    end
    # expect(File.exist?(out_path)).not_to be true

    FileUtils.mkdir_p(out_path)
    expect(File.exist?(out_path)).to be true

    epw_file_path = nil

    translator = BuildingSync::Translator.new(xml_path, out_path, epw_file_path, CA_TITLE24)
    translator.clear_all_measures
    translator.insert_energyplus_measure('scale_geometry', 1)
    translator.write_osm
    translator.write_osws
    translator.run_osws
    osw_files = []
    Dir.glob("#{out_path}/Baseline/in.osw") { |osw| osw_files << osw }
    osw_files.each do |osw|
      sql_file = osw.gsub('in.osw', 'eplusout.sql')
      puts "Simulation not completed successfully for file: #{osw}" if !File.exist?(sql_file)
      expect(File.exist?(sql_file)).to be true
    end
  end

  it 'should add a new Reporting measure' do
    xml_path = File.expand_path('./../files/building_151_one_scenario.xml', File.dirname(__FILE__))
    expect(File.exist?(xml_path)).to be true

    out_path = File.expand_path('./../output/building_151/', File.dirname(__FILE__))

    if File.exist?(out_path)
      FileUtils.rm_rf(out_path)
    end
    # expect(File.exist?(out_path)).not_to be true

    FileUtils.mkdir_p(out_path)
    expect(File.exist?(out_path)).to be true

    epw_file_path = nil

    translator = BuildingSync::Translator.new(xml_path, out_path, epw_file_path, CA_TITLE24)
    translator.insert_reporting_measure('openstudio_results', 0)
    translator.write_osm
    translator.write_osws
    translator.run_osws
    osw_files = []
    Dir.glob("#{out_path}/Baseline/in.osw") { |osw| osw_files << osw }
    osw_files.each do |osw|
      sql_file = osw.gsub('in.osw', 'eplusout.sql')
      puts "Simulation not completed successfully for file: #{osw}" if !File.exist?(sql_file)
      expect(File.exist?(sql_file)).to be true
    end
  end

  it 'should write parameter value into XML' do
    xml_path = File.expand_path('./../files/building_151_one_scenario.xml', File.dirname(__FILE__))
    expect(File.exist?(xml_path)).to be true

    out_path = File.expand_path('./../output/building_151/', File.dirname(__FILE__))

    if File.exist?(out_path)
      FileUtils.rm_rf(out_path)
    end

    FileUtils.mkdir_p(out_path)
    expect(File.exist?(out_path)).to be true

    epw_file_path = nil

    translator = BuildingSync::Translator.new(xml_path, out_path, epw_file_path, CA_TITLE24)
    translator.write_osm
    translator.write_osws

    results_xml = File.join(out_path, 'results.xml')
    translator.write_parameters_to_xml(results_xml)
    expect(File.exist?(results_xml)).to be true
  end
end
