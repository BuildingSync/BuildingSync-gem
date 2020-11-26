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

RSpec.describe 'WorkflowMaker' do
  describe 'Initialization' do
    it 'should raise a StandardError if !doc.is_a REXML::Document' do
      # -- Setup
      doc = ''
      ns = ''

      # -- Assert
      begin
        workflow_maker = BuildingSync::WorkflowMaker.new(doc, ns)
      rescue StandardError => e
        expect(e.message).to eql "doc must be an REXML::Document.  Passed object of class: String"
      end
    end

    it 'should raise a StandardError if !ns.is_a String' do
      # -- Setup
      doc = REXML::Document.new
      ns = 1

      # -- Assert
      begin
        workflow_maker = BuildingSync::WorkflowMaker.new(doc, ns)
      rescue StandardError => e
        expect(e.message).to eql "ns must be String.  Passed object of class: Int"
      end
    end
  end

  describe 'Simple Measure Methods' do
    before(:each) do
      # -- Setup
      g = BuildingSync::Generator.new
      @doc = g.create_minimum_snippet('Retail')
      @ns = 'auc'

      # Currently support measures from 4 Extensions
      cm = OpenStudio::CommonMeasures::Extension.new
      ma = OpenStudio::ModelArticulation::Extension.new
      ee = OpenStudio::EeMeasures::Extension.new
      bsync = BuildingSync::Extension.new

      @expected_measure_paths = Set[cm.measures_dir, ma.measures_dir, ee.measures_dir, bsync.measures_dir]
      @workflow_maker = BuildingSync::WorkflowMaker.new(@doc, @ns)
    end

    # TODO: What does this spec do?
    it 'get_available_measures_hash should return a Hash of measures' do
      measures_hash = @workflow_maker.get_available_measures_hash

      # -- Assert
      expect(measures_hash).to be_an_instance_of(Hash)

      count = 0
      measures_hash.each do |path, list|
        puts "measure path: #{path} with #{list.length} measures"
        count += list.length
        list.each do |measure_path_name|
          puts "     measure name : #{measure_path_name}"
        end
      end
      puts "found #{count} measures"
    end

    it 'measures_exist? should return true if all measures are available' do
      # -- Assert
      expect(@workflow_maker.measures_exist?).to be true
    end

    it 'should get_measure_directories_array for CommonMeasures, ModelArticulation, EeMeasures, and BSyncMeasures' do
      # -- Setup
      actual = @workflow_maker.get_measure_directories_array

      # -- Assert
      expect(actual).to be_an_instance_of(Array)
      expect(actual.to_set == @expected_measure_paths).to be true
    end

    it 'should initialize a workflow as a hash' do
      # -- Assert
      expect(@workflow_maker.measures_exist?).to be true
      expect(@workflow_maker.get_workflow).to be_an_instance_of(Hash)
    end

    it '@workflow set on initialization should have correct measure_paths' do
      # -- Assert
      # Check the measure_paths defined in the workflow
      actual_measure_paths = @workflow_maker.get_workflow['measure_paths'].to_set
      expect(@expected_measure_paths == actual_measure_paths).to be true
    end

    it 'deep_copy_workflow creates a deep copy of the @workflow' do
      # Double check assumptions
      # -- Assert these are the same
      workflow = @workflow_maker.get_workflow
      expect(workflow).to be @workflow_maker.get_workflow

      # -- Assert these objects are different
      workflow_new = @workflow_maker.deep_copy_workflow
      expect(workflow_new).to_not be @workflow_maker.get_workflow

      # -- Assert the hashes are still equivalent
      expect(workflow_new).to eql @workflow_maker.get_workflow

      # Assert the hashes are no longer equivalent
      workflow_new[:new_key] = 'stuff'
      expect(workflow_new).to_not eql @workflow_maker.get_workflow
    end

    it 'should get_available_measures_hash with correct structure, expected keys format' do
      available_measures = @workflow_maker.get_available_measures_hash

      # -- Assert
      expect(available_measures).to be_an_instance_of(Hash)

      # -- Setup
      # The structure of the get_available_measures Hash should look like:
      # {path_to_measure_dir: [measure_name1, mn2, etc.], path_to_measure_dir_2: [...]}
      cm = OpenStudio::CommonMeasures::Extension.new
      expect(available_measures.key?(cm.measures_dir)).to be true

      # -- Assert
      # Just check the name of one measure we know is in the common measures gem
      expect(available_measures[cm.measures_dir].find { |item| item == "SetEnergyPlusMinimumOutdoorAirFlowRate" }).to_not be nil
    end
  end

  describe 'Inserting Measures' do
    before(:each) do
      # -- Setup
      file_name = 'building_151_no_measures.xml'
      @std = CA_TITLE24
      xml_path, @output_path = create_xml_path_and_output_path(file_name, @std, __FILE__, 'v2.2.0')
      @doc = help_load_doc(xml_path)
      @ns = 'auc'

      @workflow_maker = BuildingSync::WorkflowMaker.new(@doc, @ns)
    end

    it 'clear_all_measures should remove all the steps from the workflow' do
      @workflow_maker.clear_all_measures
      expect(@workflow_maker.get_workflow['steps'].empty?).to be true
    end


    it "insert_measure_into_workflow: EnergyPlusMeasure (set_energyplus_minimum_outdoor_air_flow_rate) at the expected position and still simulates" do
      # -- Setup
      # phase_zero_base.osw has 27 ModelMeasures, 1 E+ Measure, 1 Reporting Measure
      measure_type = 'EnergyPlusMeasure'
      measure_dir_name = 'ModifyEnergyPlusCoilCoolingDXSingleSpeedObjects'
      item = 1
      final_expected_position = 27
      args = {
          "ratedTotalCoolingCapacity" => 999.9,
          "ratedCOP" => 0.99,
          "ratedAirFlowRate" => 0.999,
          "condensateRemovalStart" => 9.999,
          "evapLatentRatio" => 0.0999,
          "latentCapTimeConstant" => 4.0
      }

      expect(@workflow_maker.get_workflow['steps'].size).to eq(29)
      @workflow_maker.insert_measure_into_workflow(measure_type, measure_dir_name, item, args)

      # -- Assert
      expect(@workflow_maker.get_workflow['steps'].size).to eq(30)
      expect(@workflow_maker.get_workflow['steps'][final_expected_position]['measure_dir_name']).to eq(measure_dir_name)

      @workflow_maker.determine_standard_perform_sizing_write_osm(@output_path, nil, @std)
      write_osm_checks(@output_path)

      @workflow_maker.write_osws(@output_path)
      @workflow_maker.run_osws(@output_path)
      osw_files = []
      Dir.glob("#{@output_path}/Baseline/in.osw") { |osw| osw_files << osw }

      # -- Assert
      check_osws_simulated(osw_files)
    end

    it "insert_measure_into_workflow: ReportingMeasure (openstudio_results) at the expected position and still simulates" do
      # -- Setup
      # phase_zero_base.osw has 27 ModelMeasures, 1 E+ Measure, 1 Reporting Measure
      measure_type = 'ReportingMeasure'
      measure_dir_name = 'openstudio_results'
      item = 0
      final_expected_position = 29

      expect(@workflow_maker.get_workflow['steps'].size).to eq(29)
      @workflow_maker.insert_measure_into_workflow(measure_type, measure_dir_name, item)

      # -- Assert
      expect(@workflow_maker.get_workflow['steps'].size).to eq(30)
      expect(@workflow_maker.get_workflow['steps'][final_expected_position]['measure_dir_name']).to eq(measure_dir_name)

      @workflow_maker.determine_standard_perform_sizing_write_osm(@output_path, nil, @std)
      write_osm_checks(@output_path)

      @workflow_maker.write_osws(@output_path)
      @workflow_maker.run_osws(@output_path)
      osw_files = []
      Dir.glob("#{@output_path}/Baseline/in.osw") { |osw| osw_files << osw }

      # -- Assert
      check_osws_simulated(osw_files)
    end

    it "insert_measure_into_workflow: ModelMeasure (scale_geometry) at the expected position and still simulates" do
      # -- Setup
      # phase_zero_base.osw has 27 ModelMeasures, 1 E+ Measure, 1 Reporting Measure
      measure_type = 'ModelMeasure'
      measure_dir_name = 'scale_geometry'
      item = 3
      final_expected_position = 3

      expect(@workflow_maker.get_workflow['steps'].size).to eq(29)
      @workflow_maker.insert_measure_into_workflow(measure_type, measure_dir_name, item)

      # -- Assert
      expect(@workflow_maker.get_workflow['steps'].size).to eq(30)
      expect(@workflow_maker.get_workflow['steps'][final_expected_position]['measure_dir_name']).to eq(measure_dir_name)

      @workflow_maker.determine_standard_perform_sizing_write_osm(@output_path, nil, @std)
      write_osm_checks(@output_path)

      @workflow_maker.write_osws(@output_path)
      @workflow_maker.run_osws(@output_path)
      osw_files = []
      Dir.glob("#{@output_path}/Baseline/in.osw") { |osw| osw_files << osw }

      # -- Assert
      check_osws_simulated(osw_files)
    end

  end

  # TODO: additional test to show failing scenario
  it 'building_151_one_scenario.xml configure_workflow_for_scenario should return success = true for both Scenarios' do
    # -- Setup
    file_name = 'building_151_one_scenario.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
    ns = 'auc'
    doc = help_load_doc(xml_path)

    workflow_maker = BuildingSync::WorkflowMaker.new(doc, ns)

    # -- Setup - Create deep copies of the workflows for modification
    baseline_base_workflow = workflow_maker.deep_copy_workflow
    pom_base_workflow = workflow_maker.deep_copy_workflow

    baseline_scenario_xml = doc.get_elements("//#{ns}:Scenario")[0]
    pom_scenario_xml = doc.get_elements("//#{ns}:Scenario")[1]

    # -- Setup - create new scenario elements
    baseline_scenario = BuildingSync::Scenario.new(baseline_scenario_xml, ns)
    pom_scenario = BuildingSync::Scenario.new(pom_scenario_xml, ns)

    baseline_success = workflow_maker.configure_workflow_for_scenario(baseline_base_workflow, baseline_scenario)
    pom_success = workflow_maker.configure_workflow_for_scenario(pom_base_workflow, pom_scenario)

    # -- Assert
    expect(baseline_success).to be true
    expect(pom_success).to be true
  end

  it 'building_151_one_scenario.xml write_osw should return success = true for both Scenarios and write the in.osw' do
    # -- Setup
    file_name = 'building_151_one_scenario.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
    ns = 'auc'
    doc = help_load_doc(xml_path)
    workflow_maker = BuildingSync::WorkflowMaker.new(doc, ns)

    baseline_scenario_xml = doc.get_elements("//#{ns}:Scenario")[0]
    pom_scenario_xml = doc.get_elements("//#{ns}:Scenario")[1]

    # -- Setup - create new scenario elements
    baseline_scenario = BuildingSync::Scenario.new(baseline_scenario_xml, ns)
    pom_scenario = BuildingSync::Scenario.new(pom_scenario_xml, ns)

    baseline_success = workflow_maker.write_osw(output_path, baseline_scenario)
    pom_success = workflow_maker.write_osw(output_path, pom_scenario)

    # -- Assert
    expect(baseline_success).to be true
    expect(pom_success).to be true

    # -- Assert files exist
    expect(File.exist?(File.join(output_path, 'Baseline', 'in.osw'))).to be true
    expect(File.exist?(File.join(output_path, 'LED Only', 'in.osw'))).to be true
  end

  describe 'Results Processing' do

    # TODO: Come back to and verify - what is difference between this and next test?
    xit 'should save annual results to xml file and verify them' do
      # -- Setup
      file_name = 'building_151.xml'
      std = ASHRAE90_1
      xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')

      ns = 'auc'
      doc = help_load_doc(xml_path)
      workflow_maker = BuildingSync::WorkflowMaker.new(doc, ns)
      result = {}
      result[:completed_status] = 'Success'

      annual_results = {}
      annual_results['total_site_energy_savings_mmbtu'] = 100
      annual_results['total_source_energy_savings_mmbtu'] = 200
      annual_results['total_energy_cost_savings'] = 300
      annual_results['baseline_fuel_electricity_kbtu'] = 400
      annual_results['fuel_electricity_kbtu'] = 500
      annual_results['baseline_fuel_natural_gas_kbtu'] = 600
      annual_results['fuel_natural_gas_kbtu'] = 700
      annual_results['annual_peak_electric_demand_kw'] = 800

      scenarios = workflow_maker.get_scenarios
      scenarios.each do |scenario|
        # package_of_measures_or_current_building = workflow_maker.prepare_package_of_measures_or_current_building(scenario)
        # puts "package_of_measures_or_current_building: #{package_of_measures_or_current_building}"
        if scenario.pom? || scenario.cb_modeled?
          scenario.add_openstudio_results(results)
          expect(workflow_maker.add_results_to_scenario(package_of_measures_or_current_building, scenario, scenario_name, {}, result, nil, nil)).to be false
          expect(workflow_maker.add_results_to_scenario(package_of_measures_or_current_building, scenario, scenario_name, annual_results, result, nil, nil)).to be true
        end
        new_variables = workflow_maker.extract_annual_results(scenario, scenario_name, package_of_measures_or_current_building)
        expect(hash_diff(annual_results, new_variables)).to be true
      end
      xml_path_output = xml_path.sub! '/files/', '/output/'
      FileUtils.mkdir_p(File.dirname(xml_path_output))
      workflow_maker.save_xml(xml_path_output)

      doc_output = help_load_doc(xml_path_output)
      workflow_maker_output = BuildingSync::WorkflowMaker.new(doc_output, ns)

      scenarios = workflow_maker_output.get_scenario_elements
      scenarios.each do |scenario|
        scenario_name = scenario.elements["#{ns}:ScenarioName"].text
        puts "scenario_name: #{scenario_name}"
        package_of_measures_or_current_building = workflow_maker_output.prepare_package_of_measures_or_current_building(scenario)
        puts "package_of_measures_or_current_building: #{package_of_measures_or_current_building}"
        new_annual_results = workflow_maker_output.extract_annual_results(scenario, scenario_name, package_of_measures_or_current_building)

        # for some reason <auc:AnnualSavingsSiteEnergy>100</auc:AnnualSavingsSiteEnergy> and <auc:AnnualSavingsCost>300</auc:AnnualSavingsCost> do not get properly read by REXML
        # expect(hash_diff(annual_results, new_annual_results)).to be true
        # todo: find the problem why REXML is loosing some elements on read in??
      end
    end

    # TODO: What does this accomplish that previous test doesn't
    xit 'should save baseline annual results to xml file and verify them' do
      # -- Setup
      file_name = 'building_151.xml'
      std = ASHRAE90_1
      xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')

      ns = 'auc'
      doc = help_load_doc(xml_path)
      workflow_maker = BuildingSync::WorkflowMaker.new(doc, ns)
      result = {}
      result[:completed_status] = 'Success'

      annual_results = {}
      annual_results['total_site_energy_savings_mmbtu'] = 100
      annual_results['total_source_energy_savings_mmbtu'] = 200
      annual_results['total_energy_cost_savings'] = 300
      annual_results['fuel_electricity_kbtu'] = 500
      annual_results['fuel_natural_gas_kbtu'] = 700
      annual_results['annual_peak_electric_demand_kw'] = 800

      scenarios = workflow_maker.get_scenario_elements
      scenarios.each do |scenario|
        scenario_name = scenario.elements["#{ns}:ScenarioName"].text
        if scenario_name == 'Baseline'
          puts "scenario_name: #{scenario_name}"
          package_of_measures_or_current_building = workflow_maker.prepare_package_of_measures_or_current_building(scenario)
          puts "package_of_measures_or_current_building: #{package_of_measures_or_current_building}"
          if package_of_measures_or_current_building
            expect(workflow_maker.add_results_to_scenario(package_of_measures_or_current_building, scenario, scenario_name, annual_results, result, nil, nil)).to be true
          end
          new_variables = workflow_maker.extract_annual_results(scenario, scenario_name, package_of_measures_or_current_building)
          expect(hash_diff(annual_results, new_variables)).to be true
        end
      end
      xml_path_output = xml_path.sub! '/files/', '/output/'
      workflow_maker.save_xml(xml_path_output)

      doc_output = help_load_doc(xml_path_output)
      workflow_maker_output = BuildingSync::WorkflowMaker.new(doc_output, ns)

      scenarios = workflow_maker_output.get_scenario_elements
      scenarios.each do |scenario|
        scenario_name = scenario.elements["#{ns}:ScenarioName"].text
        if scenario_name == 'Baseline'
          puts "scenario_name: #{scenario_name}"
          current_building = workflow_maker_output.get_current_building(scenario)
          puts "current_building: #{current_building}"
          new_annual_results = workflow_maker_output.extract_annual_results(scenario, scenario_name, current_building)
          expect(hash_diff(annual_results, new_annual_results)).to be true
        end
      end
    end

    # TODO: Come back to
    xit 'should process monthly data correctly' do
      # -- Setup
      file_name = 'building_151.xml'
      std = ASHRAE90_1
      xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')

      ns = 'auc'
      doc = help_load_doc(xml_path)
      workflow_maker = BuildingSync::WorkflowMaker.new(doc, ns)

      month_lookup = {1 => 'jan', 2 => 'feb', 3 => 'mar', 4 => 'apr', 5 => 'may', 6 => 'jun', 7 => 'jul', 8 => 'aug', 9 => 'sep', 10 => 'oct', 11 => 'nov', 12 => 'dec'}
      monthly_results = {}
      electricity = 'Electricity'
      natural_gas = 'NaturalGas'

      values_e = []
      values_ng = []
      monthly = {}
      (1..12).each do |month|
        values_e << 10 * month
        values_ng << 10 * month
        electricity_key = electricity.downcase + "_ip_#{month_lookup[month]}"
        monthly[electricity_key.to_sym] = (10 * month).to_s
        natural_gas_key = natural_gas.downcase + "_ip_#{month_lookup[month]}"
        monthly[natural_gas_key.to_sym] = (10 * month).to_s
      end
      monthly_results[BuildingSync::BASELINE] = monthly

      time_series_data = workflow_maker.get_timeseries_data_element(monthly_results, 2020, BuildingSync::BASELINE)

      time_series_data.each do |time_series|
        reading = time_series.elements["#{ns}:IntervalReading"].text.to_f
        if time_series.elements["#{ns}:ResourceUseID"].attributes['IDref'].include? electricity
          shift = values_e.shift * 3.4121416331
          expect(reading).to eq shift
        elsif time_series.elements["#{ns}:ResourceUseID"].attributes['IDref'].include? natural_gas
          shift = values_ng.shift * 3.4121416331
          expect(reading).to eq shift
        end
      end
      expect(values_e.count).to eq 0
      expect(values_ng.count).to eq 0
    end
  end

  # function to compare two hashes iterating over the key and comparing the values
  def hash_diff(left_hash, right_hash)
    different = false
    (left_hash.keys + right_hash.keys).uniq.inject({}) do |memo, key|
      left = left_hash[key]
      right = right_hash[key]

      next memo if left.to_i == right.to_i

      # we get here when we find a difference
      puts "The two hashes are different for key: #{key}: left: #{left} right: #{right}"
      different = true
    end
    return !different
  end
end
