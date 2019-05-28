# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2019, Alliance for Sustainable Energy, LLC.
# BuildingSync(R), Copyright (c) 2015-2019, Alliance for Sustainable Energy, LLC.
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
  it 'should have a version' do
    expect(BuildingSync::VERSION).not_to be_nil
  end

  it 'should parse and write building_151.xml (phase zero) with auc namespace for CAT24 and baseline simulation' do
    osm_path = test_baseline_creation('building_151.xml')

    run_baseline_simulation(osm_path, 'CZ01RV2.epw')
  end

  it 'should parse and write building_151.xml (phase zero) with auc namespace for CAT24 and all simulations' do
    osw_paths = test_baseline_and_scenario_creation('building_151.xml')
    run_scenario_simulations(osw_paths)
    # run_simulation(osm_path, "CZ01RV2.epw")
  end

  it 'should parse and write building_151.xml (phase zero) with auc namespace for ASHRAE 90.1' do
    test_baseline_creation('building_151.xml', 'CZ01RV2.epw', ASHRAE90_1)
  end

  it 'should parse and write DC GSA Headquarters.xml (phase zero)' do
    test_baseline_creation('DC GSA Headquarters.xml', 'CZ01RV2.epw', ASHRAE90_1)
  end

  it 'should parse and write BuildingSync Website Valid Schema.xml (phase zero)' do
    test_baseline_creation('BuildingSync Website Valid Schema.xml', 'CZ01RV2.epw')
  end

  it 'should parse and write Golden Test File.xml (phase zero)' do
    test_baseline_creation('Golden Test File.xml')
  end

  it 'should parse and write building_151_n1.xml (phase zero) with n1 namespace' do
    # create_osw_file('building_151_n1.xml')
    xml_path = File.expand_path('../files/building_151_n1.xml', File.dirname(__FILE__))
    expect(File.exist?(xml_path)).to be true

    out_path = File.expand_path('../output/phase0_building_151_n1/', File.dirname(__FILE__))
    if File.exist?(out_path)
      FileUtils.rm_rf(out_path)
    end
    expect(File.exist?(out_path)).not_to be true

    FileUtils.mkdir_p(out_path)
    expect(File.exist?(out_path)).to be true

    translator = BuildingSync::Translator.new(xml_path, out_path)
    translator.write_osws

    osw_files = []
    Dir.glob("#{out_path}/**/*.osw") { |osw| osw_files << osw }

    expect(osw_files.size).to eq 30

    if BuildingSync::DO_SIMULATIONS
      num_sims = 0
      Parallel.each(osw_files, in_threads: [BuildingSync::NUM_PARALLEL, BuildingSync::MAX_DATAPOINTS].min) do |osw|
        break if num_sims > BuildingSync::MAX_DATAPOINTS

        cmd = "\"#{BuildingSync::OPENSTUDIO_EXE}\" run -w \"#{osw}\""
        puts "Running cmd: #{cmd}"
        result = system(cmd)
        expect(result).to be true

        num_sims += 1
      end

      translator.gather_results(out_path)
      translator.save_xml(File.join(out_path, 'results.xml'))

      expect(translator.failed_scenarios.empty?).to be(true), "Scenarios #{translator.failed_scenarios.join(', ')} failed to run"
    end
  end

  def run_baseline_simulation(osm_name, epw_name)
    workflow = OpenStudio::WorkflowJSON.new
    workflow.setSeedFile(osm_name)
    workflow.setWeatherFile(epw_name)
    osw_path = osm_name.gsub('.osm', '.osw')
    workflow.saveAs(File.absolute_path(osw_path.to_s))

    cli_path = OpenStudio.getOpenStudioCLI
    cmd = "\"#{cli_path}\" run -w \"#{osw_path}\""
    # cmd = "\"#{cli_path}\" --verbose run -w \"#{osw_path}\""
    puts cmd

    # Run the sizing run
    OpenstudioStandards.run_command(cmd)

    expect(File.exist?(osm_name.gsub('in.osm', 'run/eplusout.sql'))).to be true
  end

  def run_scenario_simulations(osw_files)
    cli_path = OpenStudio.getOpenStudioCLI

    osw_files.each do |osw_file|
      cmd = "\"#{cli_path}\" run -w \"#{osw_file}\""
      # cmd = "\"#{cli_path}\" --verbose run -w \"#{osw_file}\""
      puts cmd

      # Run the sizing run
      OpenstudioStandards.run_command(cmd)

      expect(File.exist?(osw_file.gsub('in.osw', 'eplusout.sql'))).to be true
    end
  end

  def test_baseline_creation(file_name, epw_file_name = nil, standard_to_be_used = CA_TITLE24)
    xml_path = File.expand_path("../files/#{file_name}", File.dirname(__FILE__))
    expect(File.exist?(xml_path)).to be true

    out_path = File.expand_path("../output/#{File.basename(file_name, File.extname(file_name))}/", File.dirname(__FILE__))

    if File.exist?(out_path)
      FileUtils.rm_rf(out_path)
    end
    expect(File.exist?(out_path)).not_to be true

    FileUtils.mkdir_p(out_path)
    expect(File.exist?(out_path)).to be true

    epw_file_path = nil
    if !epw_file_name.nil?
      epw_file_path = File.expand_path("../weather/#{epw_file_name}", File.dirname(__FILE__))
    end

    translator = BuildingSync::Translator.new(xml_path, out_path, epw_file_path, standard_to_be_used)
    translator.write_osm

    puts "Looking for the following OSM file: #{out_path}/in.osm"
    expect(File.exist?("#{out_path}/in.osm")).to be true
    return "#{out_path}/in.osm"
  end

  def test_baseline_and_scenario_creation(file_name, epw_file_path = nil, standard_to_be_used = CA_TITLE24)
    xml_path = File.expand_path("../files/#{file_name}", File.dirname(__FILE__))
    expect(File.exist?(xml_path)).to be true

    out_path = File.expand_path("../output/#{File.basename(file_name, File.extname(file_name))}/", File.dirname(__FILE__))

    if File.exist?(out_path)
      FileUtils.rm_rf(out_path)
    end
    expect(File.exist?(out_path)).not_to be true

    FileUtils.mkdir_p(out_path)
    expect(File.exist?(out_path)).to be true

    translator = BuildingSync::Translator.new(xml_path, out_path, epw_file_path, standard_to_be_used)
    translator.write_osm

    expect(File.exist?("#{out_path}/in.osm")).to be true

    translator.write_osws

    osw_files = []
    Dir.glob("#{out_path}/**/*.osw") { |osw| osw_files << osw }
    expect(osw_files.size).to eq 30

    return osw_files
  end
end
