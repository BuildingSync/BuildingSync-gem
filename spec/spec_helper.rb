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

# try to load configuration, use defaults if doesn't exist
begin
  require_relative '../config'
rescue LoadError, StandardError
  module BuildingSync
    # location of openstudio CLI
    OPENSTUDIO_EXE = 'openstudio'.freeze

    # one or more measure paths
    OPENSTUDIO_MEASURES = [].freeze

    # one or more file paths
    OPENSTUDIO_FILES = [].freeze

    # max number of datapoints to run
    MAX_DATAPOINTS = Float::INFINITY
    # MAX_DATAPOINTS = 2

    # number of parallel jobs
    NUM_PARALLEL = 7

    # do simulations
    DO_SIMULATIONS = false
  end
end

# for all testing
$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'bundler/setup'
require 'buildingsync/translator'
require 'buildingsync/extension'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
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
    num_parallel = 4

    cli_path = OpenStudio.getOpenStudioCLI

    counter = 1
    Parallel.each(osw_files, in_threads: num_parallel) do |osw_file|
      cmd = "\"#{cli_path}\" run -w \"#{osw_file}\""
      # cmd = "\"#{cli_path}\" --verbose run -w \"#{osw_file}\""
      puts "#{counter}) #{cmd}"
      counter += 1
      # Run the sizing run
      OpenstudioStandards.run_command(cmd)

      expect(File.exist?(osw_file.gsub('in.osw', 'eplusout.sql'))).to be true
    end
  end

  def test_baseline_creation(file_name, standard_to_be_used = CA_TITLE24, epw_file_name = nil)
    xml_path = File.expand_path("./files/#{file_name}", File.dirname(__FILE__))
    expect(File.exist?(xml_path)).to be true

    out_path = File.expand_path("./output/#{File.basename(file_name, File.extname(file_name))}/", File.dirname(__FILE__))

    if File.exist?(out_path)
      FileUtils.rm_rf(out_path)
    end
    # expect(File.exist?(out_path)).not_to be true

    FileUtils.mkdir_p(out_path)
    expect(File.exist?(out_path)).to be true

    epw_file_path = nil
    if !epw_file_name.nil?
      epw_file_path = File.expand_path("./weather/#{epw_file_name}", File.dirname(__FILE__))
    end

    translator = BuildingSync::Translator.new(xml_path, out_path, epw_file_path, standard_to_be_used)
    translator.write_osm

    puts "Looking for the following OSM file: #{out_path}/in.osm"
    expect(File.exist?("#{out_path}/in.osm")).to be true
    return "#{out_path}/in.osm"
  end

  def test_baseline_and_scenario_creation(file_name, expected_number_of_measures, standard_to_be_used = CA_TITLE24, epw_file_name = nil)
    xml_path = File.expand_path("./files/#{file_name}", File.dirname(__FILE__))
    expect(File.exist?(xml_path)).to be true

    out_path = File.expand_path("./output/#{File.basename(file_name, File.extname(file_name))}/", File.dirname(__FILE__))

    if File.exist?(out_path)
      FileUtils.rm_rf(out_path)
    end
    expect(File.exist?(out_path)).not_to be true

    FileUtils.mkdir_p(out_path)
    expect(File.exist?(out_path)).to be true

    epw_file_path = nil
    if !epw_file_name.nil?
      epw_file_path = File.expand_path("./weather/#{epw_file_name}", File.dirname(__FILE__))
    end

    translator = BuildingSync::Translator.new(xml_path, out_path, epw_file_path, standard_to_be_used)
    translator.write_osm

    expect(File.exist?("#{out_path}/in.osm")).to be true

    translator.write_osws

    osw_files = []
    osw_sr_files = []
    Dir.glob("#{out_path}/**/*.osw") { |osw| osw_files << osw }
    Dir.glob("#{out_path}/SR/*.osw") { |osw| osw_sr_files << osw }

    # we compare the counts, by also considering the two potential osw files in the SR directory
    expect(osw_files.size).to eq expected_number_of_measures + osw_sr_files.size

    return osw_files
  end

  def create_minimum_site(occupancy_classification, year_of_const, floor_area_type, floor_area_value)
    xml_snippet = create_minimum_snippet(occupancy_classification, year_of_const, floor_area_type, floor_area_value)
    ns = 'auc'
    site_element = xml_snippet.elements["/#{ns}:BuildingSync/#{ns}:Facilities/#{ns}:Facility/#{ns}:Sites/#{ns}:Site"]
    if !site_element.nil?
      return BuildingSync::Site.new(site_element, ASHRAE90_1, 'auc')
    else
      expect(site_element.nil?).to be false
    end
  end

  def create_minimum_snippet(occupancy_classification, year_of_const, floor_area_type, floor_area_value)
    xml_path = File.expand_path('./files/building_151_Blank.xml', File.dirname(__FILE__))
    ns = 'auc'
    doc = create_xml_file_object(xml_path)
    site_element = doc.elements["/#{ns}:BuildingSync/#{ns}:Facilities/#{ns}:Facility/#{ns}:Sites/#{ns}:Site"]

    occupancy_classification_element = REXML::Element.new("#{ns}:OccupancyClassification")
    occupancy_classification_element.text = occupancy_classification
    site_element.add_element(occupancy_classification_element)

    building_element = site_element.elements["#{ns}:Buildings/#{ns}:Building"]

    year_of_construction_element = REXML::Element.new("#{ns}:YearOfConstruction")
    year_of_construction_element.text = year_of_const
    building_element.add_element(year_of_construction_element)

    floor_areas_element = REXML::Element.new("#{ns}:FloorAreas")
    floor_area_element = REXML::Element.new("#{ns}:FloorArea")
    floor_area_type_element = REXML::Element.new("#{ns}:FloorAreaType")
    floor_area_type_element.text = floor_area_type
    floor_area_value_element = REXML::Element.new("#{ns}:FloorAreaValue")
    floor_area_value_element.text = floor_area_value

    floor_area_element.add_element(floor_area_type_element)
    floor_area_element.add_element(floor_area_value_element)
    floor_areas_element.add_element(floor_area_element)
    building_element.add_element(floor_areas_element)

    # doc.write(File.open(xml_path, 'w'), 2)

    return doc
  end

  def create_xml_file_object(xml_file_path)
    doc = nil
    File.open(xml_file_path, 'r') do |file|
      doc = REXML::Document.new(file)
    end
    return doc
  end
end
