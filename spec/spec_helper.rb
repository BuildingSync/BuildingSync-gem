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
require 'buildingsync/generator'
require 'rspec-parameterized'

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
  config.include BuildingSync::Helper

  SPEC_OUTPUT_DIR = File.expand_path('output', __dir__)
  SPEC_FILES_DIR = File.expand_path('files', __dir__)
  SPEC_WEATHER_DIR = File.expand_path('weather', __dir__)

  def create_xml_path_and_output_path(file_name, std, spec_file_name, version = nil)
    if version.nil?
      xml_path = File.join(SPEC_FILES_DIR, file_name)

      # The output path will look something like:
      # to/spec/output/translator_baseline_generation_spec/building_151/Caliornia
      output_path = File.join(SPEC_OUTPUT_DIR, "#{File.basename(spec_file_name , File.extname(spec_file_name ))}/#{File.basename(xml_path, File.extname(xml_path))}")
      output_path = File.join(output_path, "#{std.split('.')[0]}")
    else
      xml_path = File.join(SPEC_FILES_DIR, version, file_name)

      # The output path will look something like:
      # to/spec/output/translator_baseline_generation_spec/building_151/Caliornia

      output_path = File.join(SPEC_OUTPUT_DIR, version, "#{File.basename(spec_file_name , File.extname(spec_file_name ))}/#{File.basename(xml_path, File.extname(xml_path))}")
      output_path = File.join(output_path, "#{std.split('.')[0]}")
    end

    puts xml_path
    puts output_path
    expect(File.exist?(xml_path)).to be true
    return xml_path, output_path
  end

  def numeric?(val)
    Float(val) != nil rescue false
  end

  # run baseline simulation
  # @param osm_name [String]
  # @param epw_file_path [String]
  def run_baseline_simulation(osm_name, epw_file_path)
    basic_dir = File.dirname(osm_name)
    file_name = File.basename(osm_name)

    osm_baseline_dir = File.join(basic_dir, BuildingSync::BASELINE)
    if !File.exist?(osm_baseline_dir)
      FileUtils.mkdir_p(osm_baseline_dir)
    end
    osm_baseline_path = File.join(osm_baseline_dir, file_name)
    FileUtils.cp(osm_name, osm_baseline_dir)
    workflow = OpenStudio::WorkflowJSON.new
    workflow.setSeedFile(osm_baseline_path)
    workflow.setWeatherFile(epw_file_path)
    osw_path = osm_baseline_path.gsub('.osm', '.osw')
    workflow.saveAs(File.absolute_path(osw_path.to_s))

    extension = OpenStudio::Extension::Extension.new
    runner_options = { run_simulations: true }
    runner = OpenStudio::Extension::Runner.new(extension.root_dir, nil, runner_options)
    runner.run_osw(osw_path, osm_baseline_dir)
  end

  # generate baseline idf and compare
  # @param file_name [String]
  # @param standard_to_be_used [String]
  # @param epw_file_name [String]
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
    translator.sizing_run_and_write_osm

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

  # save idf from osm
  # @param osm_file [String]
  # @param idf_file [String]
  def save_idf_from_osm(osm_file, idf_file)
    model = OpenStudio::Model::Model.load(osm_file).get
    workspace = OpenStudio::EnergyPlus::ForwardTranslator.new.translateModel(model)
    puts "IDF file (#{File.basename(idf_file)})successfully saved" if workspace.save(idf_file)
  end

  # test baseline and scenario creation with simulation
  # @param file_name [String]
  # @param expected_number_of_measures [Integer]
  # @param standard_to_be_used [String]
  # @param epw_file_name [String]
  # @param simulate [Boolean]
  def test_baseline_and_scenario_creation_with_simulation(xml_path, output_path, expected_number_of_measures, standard_to_be_used = CA_TITLE24, epw_file_name = nil, simulate = true)
    current_year = Date.today.year
    translator = test_baseline_and_scenario_creation(xml_path, output_path, expected_number_of_measures, standard_to_be_used, epw_file_name)

    osw_files = []
    Dir.glob("#{out_path}/**/*.osw") { |osw| osw_files << osw }

    if simulate
      translator.run_osws

      dir_path = File.dirname(osw_files[0])
      parent_dir_path = File.expand_path('..', dir_path)

      successful = translator.gather_results(parent_dir_path)
      puts 'Error during results gathering, please check earlier error messages for issues with measures.' if !successful
      expect(successful).to be true
      translator.save_xml(File.join(parent_dir_path, 'results.xml'))
      expect(File.exist?(File.join(parent_dir_path, 'results.xml'))).to be true
    else
      puts 'Not simulate'
    end
  end

  # test baseline and scenario creation
  # @param file_name [String]
  # @param expected_number_of_measures [Integer]
  # @param standard_to_be_used [String]
  # @param epw_file_name [String]
  def test_baseline_and_scenario_creation(file_name, output_path, expected_number_of_measures, standard_to_be_used = CA_TITLE24, epw_file_name = nil)

    translator = translator_write_osm_and_perform_checks(file_name, output_path, standard_to_be_used, epw_file_name)
    translator.write_osws

    osw_files = []
    osw_sr_files = []
    Dir.glob("#{out_path}/**/*.osw") { |osw| osw_files << osw }
    Dir.glob("#{out_path}/SR/*.osw") { |osw| osw_sr_files << osw }

    # we compare the counts, by also considering the two potential osw files in the SR directory
    expect(osw_files.size).to eq expected_number_of_measures + osw_sr_files.size
    return translator
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

    write_osm_checks(output_path)

    run_baseline_simulation(output_path + '/in.osm', epw_file_path)

    translator_run_baseline_osm_checks(output_path)
  end

  def translator_write_run_baseline_gather_save_perform_all_checks(xml_path, output_path, epw_file_path = nil, standard_to_be_used = ASHRAE90_1)
    # -- Assert translator.write_osm checks
    translator = translator_write_osm_and_perform_checks(xml_path, output_path, epw_file_path, standard_to_be_used)

    # -- Setup
    epw_file_path = '' if epw_file_path.nil? || !File.exist?(epw_file_path)
    translator.run_baseline_osm(epw_file_path)

    # -- Assert translator.run_baseline_osm checks
    translator_run_baseline_osm_checks(output_path)

    # -- Setup
    success = translator.gather_results(output_path)

    # -- Assert
    expected_resource_uses = ['Electricity', 'Natural gas']
    translator_gather_results_check_current_building_modeled(translator, success, expected_resource_uses)

    # -- Assert
    results_file_path = File.join(output_path, 'results.xml')
    translator_save_xml_checks(translator, results_file_path)
  end

  # Creates a new Translator for the file specified and runs the write_osm method and checks:
  #  - output_path/SR directory created (for sizing run)
  #  - output_path/SR/run/finished.job exists
  #  - output_path/SR/run/failed.job doesn't exist
  #  - output_path/in.osm exists  --  which becomes the seed model for all future models
  # @param xml_path [String] full path to BuildingSync XML file
  # @param output_path [String] full path to output directory where new files should be saved
  # @param epw_file_path [String] optional, full path to epw file
  def translator_write_osm_and_perform_checks(xml_path, output_path, epw_file_path = nil, standard_to_be_used = ASHRAE90_1)
    # -- Assert
    expect(File.exist?(xml_path)).to be true
    if !epw_file_path.nil? && !epw_file_path == ''
      expect(File.exist?(epw_file_path)).to be true
      puts "Found epw: #{epw_file_path}"
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

    # -- Setup
    # Create a new Translator and write the OSM
    translator = BuildingSync::Translator.new(xml_path, output_path, epw_file_path, standard_to_be_used)
    translator.sizing_run_and_write_osm

    # -- Assert
    write_osm_checks(output_path)
    return translator
  end

  def write_osm_checks(output_path)
    # -- Assert
    # Check SR path exists
    # BuildingSync-gem/spec/output/translator_write_osm/L000_OpenStudio_Pre-Simulation_03/SR
    sr_path = File.join(output_path, 'SR')
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
    expect(File.exist?(File.join(output_path, 'in.osm'))).to be true
  end

  def translator_run_baseline_osm_checks(output_path)
    # Check Baseline directory gets created
    # BuildingSync-gem/spec/output/translator_write_osm/L000_OpenStudio_Pre-Simulation_03/Baseline
    baseline_path = File.join(output_path, 'Baseline')
    expect(Dir.exist?(baseline_path)).to be true

    # Expect job not to have failed
    failed_path = File.join(baseline_path, 'failed.job')
    expect(File.exist?(failed_path)).to be false

    # Expect job finished
    # BuildingSync-gem/spec/output/translator_write_osm/L000_OpenStudio_Pre-Simulation_03/Baseline/finished.job
    finished_path = File.join(baseline_path, 'finished.job')
    expect(File.exist?(finished_path)).to be true

    # Expect SQL file available
    eplusout_sql_path = File.join(baseline_path, 'eplusout.sql')
    expect(File.exist?(eplusout_sql_path)).to be true
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
  def translator_gather_results_check_current_building_modeled(translator, success, expected_resource_uses)
    # -- Assert
    # gather_results simply prepares all of the results in memory as an REXML::Document
    expect(success).to be true
    expect(translator.get_failed_scenarios.empty?).to be(true), "Scenarios #{translator.get_failed_scenarios.join(', ')} failed to run"

    doc = translator.get_doc
    expect(doc).to be_an_instance_of(REXML::Document)

    # There should be one Current Building Modeled scenario (referred to as Baseline)
    current_building_modeled_scenario = REXML::XPath.match(doc, "//auc:Scenarios/auc:Scenario[auc:ScenarioType/auc:CurrentBuilding/auc:CalculationMethod/auc:Modeled]")
    expect(current_building_modeled_scenario.size).to eql 1

    expected_resource_uses.each do |use|
      # Check that the energy resource use actually gets created
      resource = REXML::XPath.match(current_building_modeled_scenario, "./auc:ResourceUses/auc:ResourceUse[auc:EnergyResource/text()='#{use}']")
      expect(resource.size).to eql 1
      resource = resource.first()
      expect(resource).to be_an_instance_of(REXML::Element)

      # Check that 12 months of TimeSeries data is inserted into the document
      xp = "./auc:TimeSeriesData/auc:TimeSeries[auc:ReadingType/text() = 'Total' and auc:IntervalFrequency/text() = 'Month' and auc:ResourceUseID/@IDref = '#{resource.attribute('ID')}']"
      ts_elements = REXML::XPath.match(current_building_modeled_scenario, xp)

      expect(ts_elements.size).to eql 12
      ts_elements.each do |ts_element|
        # Check that there is an actual value for an interval reading and that it can be cast to a float
        interval_reading = ts_element.get_elements('./auc:IntervalReading')
        expect(interval_reading.size).to eql 1
        interval_reading = interval_reading.first()
        expect(interval_reading).to be_an_instance_of(REXML::Element)
        expect(interval_reading.has_text?).to be true
        text = interval_reading.get_text.to_s
        expect(numeric?(text)).to be_an_instance_of(Float)
      end
    end
  end

  # @param translator [BuildingSync::Translator]
  # @param results_file_path [String]
  def translator_save_xml_checks(translator, results_file_path)
    # -- Assert file doesn't exist
    expect(File.exist?(results_file_path)).to be false

    # -- Setup
    translator.save_xml(results_file_path)

    # -- Assert
    expect(File.exist?(results_file_path)).to be true
  end

end
