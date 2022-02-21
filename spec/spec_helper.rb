# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2022, Alliance for Sustainable Energy, LLC.
# BuildingSync(R), Copyright (c) 2015-2022, Alliance for Sustainable Energy, LLC.
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
require 'buildingsync/generator'

# try to load configuration, use defaults if doesn't exist
begin
  require_relative '../config'
rescue LoadError, StandardError
  module BuildingSync
    # location of openstudio CLI
    OPENSTUDIO_EXE = 'openstudio'

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
  config.include BuildingSync::Helper
  config.include BuildingSync::XmlGetSet

  SPEC_OUTPUT_DIR = File.expand_path('output', __dir__)
  SPEC_FILES_DIR = File.expand_path('files', __dir__)
  SPEC_WEATHER_DIR = File.expand_path('weather', __dir__)

  def create_xml_path_and_output_path(file_name, std, spec_file_name, version = nil)
    if version.nil?
      xml_path = File.join(SPEC_FILES_DIR, file_name)

      # The output path will look something like:
      # to/spec/output/translator_baseline_generation_spec/building_151/Caliornia
      output_path = File.join(SPEC_OUTPUT_DIR, "#{File.basename(spec_file_name, File.extname(spec_file_name))}/#{File.basename(xml_path, File.extname(xml_path))}")
      output_path = File.join(output_path, (std.split('.')[0]).to_s)
    else
      xml_path = File.join(SPEC_FILES_DIR, version, file_name)

      # The output path will look something like:
      # to/spec/output/translator_baseline_generation_spec/building_151/Caliornia

      output_path = File.join(SPEC_OUTPUT_DIR, version, "#{File.basename(spec_file_name, File.extname(spec_file_name))}/#{File.basename(xml_path, File.extname(xml_path))}")
      output_path = File.join(output_path, (std.split('.')[0]).to_s)
    end

    # -- Setup
    # Delete the directory and start over if it does exist so we are not checking old results
    if File.exist?(output_path)
      puts "Removing dir: #{output_path}"
      FileUtils.rm_rf(output_path)
      expect(Dir.exist?(output_path)).to be false
    end
    FileUtils.mkdir_p(output_path) if !File.exist?(output_path)
    expect(Dir.exist?(output_path)).to be true
    expect(File.exist?(xml_path)).to be true
    puts xml_path
    puts output_path
    return xml_path, output_path
  end

  # @return [Boolean] if the value is numeric
  def numeric?(val)
    !Float(val).nil?
  rescue StandardError
    false
  end

  # compare two idf files
  # @param old_idf_file [String]
  # @param new_idf_file [String]
  # @return [Integer] number of lines that did not match
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

  # generate idf file#
  # @param model [OpenStudio::Model]
  def generate_idf_file(model)
    workspace = OpenStudio::EnergyPlus::ForwardTranslator.new.translateModel(model)
    new_file_path = "#{@osm_file_path}/in.idf"
    # first delete idf file if exist
    File.delete(new_file_path) if File.exist?(new_file_path)

    # now create idf file.
    puts 'IDF file successfully saved' if workspace.save(new_file_path)

    original_file_path = "#{@osm_file_path}/originalfiles"
    old_model = OpenStudio::Model::Model.load("#{original_file_path}/in.osm").get
    workspace = OpenStudio::EnergyPlus::ForwardTranslator.new.translateModel(old_model)
    # first delete the file if exist
    File.delete("#{original_file_path}/in.idf") if File.exist?("#{original_file_path}/in.idf")

    puts 'IDF file 2 successfully saved' if workspace.save("#{original_file_path}/in.idf")
  end

  # run minimum facility
  # @param occupancy_classification [String]
  # @param year_of_const [Integer]
  # @param floor_area_type [String]
  # @param floor_area_value [Float]
  # @param standard_to_be_used [String]
  # @param spec_name [String]
  def run_minimum_facility(occupancy_classification, year_of_const, floor_area_type, floor_area_value, standard_to_be_used, spec_name, floors_above_grade = 1)
    # -- Setup
    generator = BuildingSync::Generator.new
    facility = generator.create_minimum_facility(occupancy_classification, year_of_const, floor_area_type, floor_area_value, floors_above_grade)
    facility.determine_open_studio_standard(standard_to_be_used)

    epw_file_path = File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw')
    output_path = File.join(SPEC_OUTPUT_DIR, "#{spec_name}/#{occupancy_classification}/Year#{year_of_const}")

    # Remove if previously exists
    if Dir.exist?(output_path)
      FileUtils.rm_rf(output_path)
    end
    expect(Dir.exist?(output_path)).to be false

    # Recreate fresh directory
    FileUtils.mkdir_p(output_path)
    expect(Dir.exist?(output_path)).to be true

    expect(facility.generate_baseline_osm(epw_file_path, output_path, standard_to_be_used)).to be true
    facility.write_osm(output_path)

    sizing_run_checks(output_path)
  end

  # test writing scenarios
  # @param translator [BuildingSync::Translator]
  # @param output_path [String]
  # @param expected_number_of_scenarios [Integer]
  def translator_write_osws_and_check(translator, output_path, expected_number_of_scenarios)
    workflows_successfully_written = translator.write_osws

    # -- Assert
    expect(workflows_successfully_written).to be true

    osw_files = []
    osw_sr_files = []
    Dir.glob("#{output_path}/**/in.osw") { |osw| osw_files << osw }
    Dir.glob("#{output_path}/SR/in.osw") { |osw| osw_sr_files << osw }

    # We always expect there to only be one
    # sizing run file
    expect(osw_sr_files.size).to eq 1

    # Here we test the actual number of additional scenarios that got created
    non_sr_osws = osw_files - osw_sr_files
    expect(non_sr_osws.size).to eq expected_number_of_scenarios
  end

  # Creates a new Translator for the file specified and runs the setup_and_sizing_run method and checks:
  #  - output_path/SR directory created (for sizing run)
  #  - output_path/SR/run/finished.job exists
  #  - output_path/SR/run/failed.job doesn't exist
  #  - output_path/in.osm exists  --  which becomes the seed model for all future models
  # @param xml_path [String] full path to BuildingSync XML file
  # @param output_path [String] full path to output directory where new files should be saved
  # @param epw_file_path [String] optional, full path to epw file
  def translator_sizing_run_and_check(xml_path, output_path, epw_file_path = nil, standard_to_be_used = ASHRAE90_1)
    # -- Assert
    expect(File.exist?(xml_path)).to be true
    if !epw_file_path.nil? && !epw_file_path == ''
      expect(File.exist?(epw_file_path)).to be true
      puts "Found epw: #{epw_file_path}"
    end

    # -- Setup
    # Create a new Translator and write the OSM
    translator = BuildingSync::Translator.new(xml_path, output_path, epw_file_path, standard_to_be_used)
    translator.setup_and_sizing_run

    # -- Assert
    sizing_run_checks(output_path)
    return translator
  end

  # @param main_output_dir [String] main output path, not scenario specific. i.e. SR should be a subdirectory
  def sizing_run_checks(main_output_dir)
    # -- Assert
    # Check SR path exists
    # BuildingSync-gem/spec/output/translator_write_osm/L000_OpenStudio_Pre-Simulation_03/SR
    sr_path = File.join(main_output_dir, 'SR')
    expect(Dir.exist?(sr_path)).to be true

    # -- Assert
    # Check SR has finished successfully
    # BuildingSync-gem/spec/output/translator_write_osm/L000_OpenStudio_Pre-Simulation_03/SR/run/finished.job
    sr_success_file = File.join(sr_path, 'run/finished.job')
    expect(File.exist?(sr_success_file)).to be true

    # -- Assert
    # Check SR has not failed
    # BuildingSync-gem/spec/output/translator_write_osm/L000_OpenStudio_Pre-Simulation_03/SR/run/failed.job
    sr_failed_file = File.join(sr_path, 'run/failed.job')
    expect(File.exist?(sr_failed_file)).to be false

    # -- Assert
    # Check in.osm written to the main output_path
    # BuildingSync-gem/spec/output/translator_write_osm/L000_OpenStudio_Pre-Simulation_03/in.osm
    expect(File.exist?(File.join(main_output_dir, 'in.osm'))).to be true
  end

  # Checks that results from a single Baseline modeling scenario have been added to the REXML::Document in memory
  #  specifically checks:
  #  - no scenarios have failed
  #  - each expected ResourceUse is declared
  #  - 12 months of timeseries data has been added for each ResourceUse
  #  - The values of the auc:TimeSeries/auc:IntervalReading are numeric
  # @param translator [BuildingSync::Translator] gather_results method should previously have been run
  # @param success [Boolean] the returned value from translator.gather_results
  # @param expected_resource_uses [Array<String>] auc:EnergyResource values to check, i.e. 'Electricity', 'Natural gas'
  # @return [void]
  def translator_gather_results_checks(translator, expected_resource_uses)
    translator.gather_results

    # -- Assert result_gathered set to true
    expect(translator.results_gathered).to be true

    # -- Assert
    # gather_results simply prepares all of the results in memory as an REXML::Document
    expect(translator.get_failed_scenarios.empty?).to be(true), "Scenarios #{translator.get_failed_scenarios.join(', ')} failed to run"

    doc = translator.doc
    prefix = translator.get_prefix
    expect(doc).to be_an_instance_of(REXML::Document)

    # There should be one Current Building Modeled scenario (referred to as Baseline)
    current_building_modeled_scenario = REXML::XPath.match(doc, "//#{prefix}Scenarios/#{prefix}Scenario[#{prefix}ScenarioType/#{prefix}CurrentBuilding/#{prefix}CalculationMethod/#{prefix}Modeled]")
    expect(current_building_modeled_scenario.size).to eql 1

    expected_resource_uses.each do |use|
      # Check that the energy resource use actually gets created
      resource = REXML::XPath.match(current_building_modeled_scenario, "./#{prefix}ResourceUses/#{prefix}ResourceUse[#{prefix}EnergyResource/text()='#{use}']")
      expect(resource.size).to eql 1
      resource = resource.first
      expect(resource).to be_an_instance_of(REXML::Element)

      # Check that 12 months of TimeSeries data is inserted into the document
      xp = "./#{prefix}TimeSeriesData/#{prefix}TimeSeries[#{prefix}ReadingType/text() = 'Total' and #{prefix}IntervalFrequency/text() = 'Month' and #{prefix}ResourceUseID/@IDref = '#{resource.attribute('ID')}']"
      ts_elements = REXML::XPath.match(current_building_modeled_scenario, xp)

      expect(ts_elements.size).to eql 12
      ts_elements.each do |ts_element|
        # Check that there is an actual value for an interval reading and that it can be cast to a float
        interval_reading = ts_element.get_elements("./#{prefix}IntervalReading")
        expect(interval_reading.size).to eql 1
        interval_reading = interval_reading.first
        expect(interval_reading).to be_an_instance_of(REXML::Element)
        expect(interval_reading.has_text?).to be true
        text = interval_reading.get_text.to_s
        expect(numeric?(text)).to be true
      end
    end
  end

  def check_osws_simulated(main_output_dir, expected_number_scenarios_excluding_sr)
    osw_files = []
    osw_sr_files = []
    Dir.glob("#{main_output_dir}/**/in.osw") { |osw| osw_files << osw }
    Dir.glob("#{main_output_dir}/SR/in.osw") { |osw| osw_sr_files << osw }

    # -- Assert - simulations are as we expect them
    expect(osw_files.size).to eq(expected_number_scenarios_excluding_sr + 1) # includes SR
    expect(osw_sr_files.size).to eq(1)

    osw_exclude_sr = osw_files - osw_sr_files
    osw_exclude_sr.each do |osw|
      sql_file = osw.gsub('in.osw', 'eplusout.sql')
      finished_job = osw.gsub('in.osw', 'finished.job')
      failed_job = osw.gsub('in.osw', 'failed.job')
      expect(File.exist?(sql_file)).to be true
      expect(File.exist?(finished_job)).to be true
      expect(File.exist?(failed_job)).to be false
    end
  end

  # @param translator [BuildingSync::Translator]
  # @param results_file_path [String]
  def translator_save_xml_checks(translator, results_file_path)
    # -- Assert file doesn't exist
    expect(File.exist?(results_file_path)).to be false

    # -- Setup
    translator.save_xml

    # -- Assert
    expect(File.exist?(results_file_path)).to be true
  end

  def get_tests
    tests = [
      # file_name, standard, epw_path, schema_version, expected number of scenarios, including cb_modeled
      ['building_151.xml', ASHRAE90_1, nil, 'v2.2.0', 30],
      ['building_151_n1.xml', ASHRAE90_1, nil, 'v2.2.0', 30],
      ['DC GSA Headquarters.xml', ASHRAE90_1, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.2.0', 2],
      ['DC GSA HeadquartersWithClimateZone.xml', ASHRAE90_1, nil, 'v2.2.0', 2],
      ['L000_OpenStudio_Pre-Simulation_01.xml', ASHRAE90_1, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.2.0', 1],
      ['L000_OpenStudio_Pre-Simulation_02.xml', ASHRAE90_1, nil, 'v2.2.0', 1],
      ['L000_OpenStudio_Pre-Simulation_03.xml', ASHRAE90_1, nil, 'v2.2.0', 1],
      ['L000_OpenStudio_Pre-Simulation_04.xml', ASHRAE90_1, nil, 'v2.2.0', 1],

      # Test once issues get fixed
      # See translator_sizing_run_spec errors
      #
      # ['building_151_level1.xml', ASHRAE90_1, nil, 'v2.2.0', 30],
      # ['L100_Audit.xml', CA_TITLE24, nil, 'v2.2.0', 2],
      # ['Golden Test File.xml', CA_TITLE24, nil, 'v2.2.0', 2],

      # These have inherent flaws in their file structure and will not pass
      # They are kept here for reference.
      # See translator_sizing_run_spec errors
      #
      # - BuildingSync Website Valid Schema.xml (OccupancyClassification not defined)
      # - AT_example_property_report_25 (OccupancyClassification not defined)
    ]
    return tests
  end

  # Weather Spec Helper Functions
  def check_weather_file_exist(epw_path)
    # check weather file exist or not
    expect(File.exist?(epw_path)).to be true

    epw_path['.epw'] = '.ddy'

    # check design day file exist or not
    expect(File.exist?(epw_path)).to be true
  end

  def get_state_and_city_name(file_name, ns)
    doc = get_xml_object(file_name)

    address_element = doc.elements["#{ns}:BuildingSync/#{ns}:Facilities/#{ns}:Facility/#{ns}:Sites/#{ns}:Site"]

    city = address_element.elements["#{ns}:Address/#{ns}:City"].text
    state = address_element.elements["#{ns}:Address/#{ns}:State"].text
    return state, city
  end

  def get_weather_id(file_name, ns)
    doc = get_xml_object(file_name)
    site_element = doc.elements["#{ns}:BuildingSync/#{ns}:Facilities/#{ns}:Facility/#{ns}:Sites/#{ns}:Site"]

    return site_element.elements["#{ns}:WeatherDataStationID"].text
  end

  def get_xml_object(file_name)
    xml_path = File.join(SPEC_FILES_DIR, 'v2.2.0', file_name)
    expect(File.exist?(xml_path)).to be true

    return help_load_doc(xml_path)
  end

  class DummyClass
    include BuildingSync::Helper
    include BuildingSync::XmlGetSet
    def initialize(base_xml, ns)
      @base_xml = base_xml
      @ns = ns
    end
  end
end
