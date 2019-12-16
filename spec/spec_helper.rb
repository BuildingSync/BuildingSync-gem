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
    basic_dir = File.dirname(osm_name)
    file_name = File.basename(osm_name)

    osm_baseline_dir = File.join(basic_dir, 'Baseline')
    if !File.exist?(osm_baseline_dir)
      FileUtils.mkdir_p(osm_baseline_dir)
    end
    osm_baseline_path = File.join(osm_baseline_dir, file_name)
    FileUtils.cp(osm_name, osm_baseline_dir)
    puts "osm_baseline_path: #{osm_baseline_path}"
    workflow = OpenStudio::WorkflowJSON.new
    workflow.setSeedFile(osm_baseline_path)
    workflow.setWeatherFile(File.join('../../../weather', epw_name))
    osw_path = osm_baseline_path.gsub('.osm', '.osw')
    workflow.saveAs(File.absolute_path(osw_path.to_s))

    if BuildingSync::Extension::DO_SIMULATIONS || BuildingSync::Extension::SIMULATE_BASELINE_ONLY
      cli_path = OpenStudio.getOpenStudioCLI
      cmd = "\"#{cli_path}\" run -w \"#{osw_path}\""
      # cmd = "\"#{cli_path}\" --verbose run -w \"#{osw_path}\""
      puts cmd

      # Run the sizing run
      OpenstudioStandards.run_command(cmd)

      expect(File.exist?(osm_baseline_path.gsub('in.osm', 'run/eplusout.sql'))).to be true
      # expect(File.exist?(osm_name.gsub('in.osm', 'run/eplusout.sql'))).to be true
    end
  end

  def run_scenario_simulations(osw_files)
    cli_path = OpenStudio.getOpenStudioCLI
    if BuildingSync::Extension::DO_SIMULATIONS || !BuildingSync::Extension::SIMULATE_BASELINE_ONLY
      counter = 1
      Parallel.each(osw_files, in_threads: BuildingSync::Extension::NUM_PARALLEL) do |osw_file|
        cmd = "\"#{cli_path}\" run -w \"#{osw_file}\""
        # cmd = "\"#{cli_path}\" --verbose run -w \"#{osw_file}\""
        puts "#{counter}) #{cmd}"
        counter += 1
        # Run the sizing run
        OpenstudioStandards.run_command(cmd)

        sql_file = osw_file.gsub('in.osw', 'eplusout.sql')
        puts "Simulation not completed successfully for file: #{osw_file}" if !File.exist?(sql_file)
        expect(File.exist?(sql_file)).to be true
      end
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
    return translator
  end

  def generated_baseline_idf_and_compare(file_name, standard_to_be_used = CA_TITLE24, epw_file_name = nil)
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

    base_file_name = File.basename(file_name, '.xml')
    new_osm_file = "#{out_path}/#{base_file_name}.osm"
    puts "Looking for the following OSM file: #{new_osm_file}"
    expect(File.exist?(new_osm_file)).to be true

    new_idf_file = "#{out_path}/#{base_file_name}.idf"
    save_idf_from_osm(new_osm_file, new_idf_file)

    osm_comparison_file_path = File.expand_path('files/filecomparison', File.dirname(__FILE__))
    old_osm_file = "#{osm_comparison_file_path}/#{base_file_name}.osm"
    puts "Looking for the following OSM file: #{old_osm_file}"
    expect(File.exist?(old_osm_file)).to be true
    old_idf_file = "#{osm_comparison_file_path}/#{base_file_name}.idf"
    File.delete(old_idf_file) if File.exist?(old_idf_file)
    save_idf_from_osm(old_osm_file, old_idf_file)

    old_file_size = File.size(old_idf_file)
    new_file_size = File.size(new_idf_file)
    puts "original idf file size #{old_file_size} bytes versus new idf file size #{new_file_size} bytes"
    expect((old_file_size - new_file_size).abs <= 1).to be true

    line_not_match_counter = compare_two_idf_files(old_idf_file, new_idf_file)

    expect(line_not_match_counter == 0).to be true
  end

  def compare_two_idf_files(old_idf_file, new_idf_file)
    idf_file1 = File.open(old_idf_file)
    idf_file2 = File.open(new_idf_file)

    file1_lines = idf_file1.readlines
    file2_lines = idf_file2.readlines

    line_not_match_counter = 0
    counter = 0
    file1_lines.each do |line|
      if !line.include?('Sub Surface') && !file2_lines[counter].eql?(line)
        puts "This is the newly create idf file line : #{line} on line no : #{counter}"
        puts "This is the original idf file line : #{file2_lines[counter]} on line no : #{counter}"
        line_not_match_counter += 1
      end
      counter += 1
    end
    return line_not_match_counter
  end

  def generate_idf_file(model)
    workspace = OpenStudio::EnergyPlus::ForwardTranslator.new.translateModel(model)
    new_file_path = "#{@osm_file_path}/in.idf"
    # first delete idf file if exist
    File.delete(new_file_path) if File.exist?(new_file_path)

    # now create idf file.
    p 'IDF file successfully saved' if workspace.save(new_file_path)

    original_file_path = "#{@osm_file_path}/originalfiles"
    oldModel = OpenStudio::Model::Model.load("#{original_file_path}/in.osm").get
    workspace = OpenStudio::EnergyPlus::ForwardTranslator.new.translateModel(oldModel)
    # first delete the file if exist
    File.delete("#{original_file_path}/in.idf") if File.exist?("#{original_file_path}/in.idf")

    p 'IDF file 2 successfully saved' if workspace.save("#{original_file_path}/in.idf")
  end

  def save_idf_from_osm(osm_file, idf_file)
    model = OpenStudio::Model::Model.load(osm_file).get
    workspace = OpenStudio::EnergyPlus::ForwardTranslator.new.translateModel(model)
    puts "IDF file (#{File.basename(idf_file)})successfully saved" if workspace.save(idf_file)
  end

  def test_baseline_and_scenario_creation_with_simulation(file_name, expected_number_of_measures, standard_to_be_used = CA_TITLE24, epw_file_name = nil, run_simulation = true)
    xml_path = File.expand_path("./files/#{file_name}", File.dirname(__FILE__))
    expect(File.exist?(xml_path)).to be true

    out_path = File.expand_path("./output/#{File.basename(file_name, File.extname(file_name))}/", File.dirname(__FILE__))

    if File.exist?(out_path)
      FileUtils.rm_rf(out_path)
    end

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

    if run_simulation
      translator.run_osws

      dir_path = File.dirname(osw_files[0])
      parent_dir_path = File.expand_path('..', dir_path)

      translator.gather_results(parent_dir_path)
      translator.save_xml(File.join(parent_dir_path, 'results.xml'))
    end
  end

  def create_minimum_site(occupancy_classification, year_of_const, floor_area_type, floor_area_value)
    xml_snippet = create_minimum_snippet(occupancy_classification, year_of_const, floor_area_type, floor_area_value)
    ns = 'auc'
    site_element = xml_snippet.elements["/#{ns}:BuildingSync/#{ns}:Facilities/#{ns}:Facility/#{ns}:Sites/#{ns}:Site"]
    if !site_element.nil?
      return BuildingSync::Site.new(site_element, 'auc')
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
