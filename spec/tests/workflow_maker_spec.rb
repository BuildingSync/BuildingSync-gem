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

RSpec.describe 'WorkFlow Maker' do
  it 'should get_measure_directories_array for CommonMeasures, ModelArticulation, EeMeasures, and BSyncMeasures' do
    # -- Setup
    # For initialization, needs no substantial info.
    doc = REXML::Document.new
    ns = 'auc'
    wm = BuildingSync::WorkflowMaker.new(doc, ns)
    # Currently support measures from 4 Extensions
    cm = OpenStudio::CommonMeasures::Extension.new
    ma = OpenStudio::ModelArticulation::Extension.new
    ee = OpenStudio::EeMeasures::Extension.new
    bsync = BuildingSync::Extension.new

    expected_measure_paths = Set[cm.measures_dir, ma.measures_dir, ee.measures_dir, bsync.measures_dir]
    actual = wm.get_measure_directories_array

    # -- Assert
    expect(actual).to be_an_instance_of(Array)
    expect(actual.to_set == expected_measure_paths).to be true
  end

  it 'should initialize a workflow as a hash, have expected @workflow["measure_paths"]' do
    # -- Setup
    # For initialization, needs no substantial info.
    doc = REXML::Document.new
    ns = 'auc'
    wm = BuildingSync::WorkflowMaker.new(doc, ns)

    # -- Assert
    expect(wm.check_if_measures_exist).to be true
    expect(wm.get_workflow).to be_an_instance_of(Hash)

    # -- Setup
    # Currently support measures from 4 Extensions
    cm = OpenStudio::CommonMeasures::Extension.new
    ma = OpenStudio::ModelArticulation::Extension.new
    ee = OpenStudio::EeMeasures::Extension.new
    bsync = BuildingSync::Extension.new
    # Create a set of expected measure paths
    expected_measure_paths = Set[cm.measures_dir, ma.measures_dir, ee.measures_dir, bsync.measures_dir]

    # -- Assert
    # Check the measure_paths defined in the workflow
    actual_measure_paths = wm.get_workflow['measure_paths'].to_set
    expect(expected_measure_paths == actual_measure_paths).to be true
  end

  it 'should get_available_measures_hash with correct structure, expected keys format' do
    # -- Setup
    # For initialization, needs no substantial info.
    doc = REXML::Document.new
    ns = 'auc'
    wm = BuildingSync::WorkflowMaker.new(doc, ns)
    available_measures = wm.get_available_measures_hash

    # -- Assert
    expect(available_measures).to be_an_instance_of(Hash)

    # -- Setup
    # The structure of the get_available_measures Hash should look like:
    # {path_to_measure_dir: [measure_name1, mn2, etc.], path_to_measure_dir_2: [...]}
    cm = OpenStudio::CommonMeasures::Extension.new
    expect(available_measures.key?(cm.measures_dir)).to be true

    # -- Assert
    # Just check the name of one measure we know is in the common measures gem
    expect(available_measures[cm.measures_dir].find { |item | item == "SetEnergyPlusMinimumOutdoorAirFlowRate"}).to_not be nil
  end

  # TODO: Come back to and verify - what is difference between this and next test?
  it 'should save annual results to xml file and verify them' do
    file_name = 'building_151.xml'
    xml_path = File.expand_path("./../files/#{file_name}", File.dirname(__FILE__))
    expect(File.exist?(xml_path)).to be true

    ns = 'auc'
    doc = BuildingSync::Helper.read_xml_file_document(xml_path)
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

    scenarios = workflow_maker.get_scenario_elements
    scenarios.each do |scenario|
      scenario_name = scenario.elements["#{ns}:ScenarioName"].text
      puts "scenario_name: #{scenario_name}"
      package_of_measures_or_current_building = workflow_maker.prepare_package_of_measures_or_current_building(scenario)
      puts "package_of_measures_or_current_building: #{package_of_measures_or_current_building}"
      if package_of_measures_or_current_building
        expect(workflow_maker.add_results_to_scenario(package_of_measures_or_current_building, scenario, scenario_name, {}, result, nil, nil)).to be false
        expect(workflow_maker.add_results_to_scenario(package_of_measures_or_current_building, scenario, scenario_name, annual_results, result, nil, nil)).to be true
      end
      new_variables = workflow_maker.extract_annual_results(scenario, scenario_name, package_of_measures_or_current_building)
      expect(hash_diff(annual_results, new_variables)).to be true
    end
    xml_path_output = xml_path.sub! '/files/', '/output/'
    FileUtils.mkdir_p(File.dirname(xml_path_output))
    workflow_maker.save_xml(xml_path_output)

    doc_output = BuildingSync::Helper.read_xml_file_document(xml_path_output)
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
  it 'should save baseline annual results to xml file and verify them' do
    file_name = 'building_151.xml'
    xml_path = File.expand_path("./../files/#{file_name}", File.dirname(__FILE__))
    expect(File.exist?(xml_path)).to be true

    ns = 'auc'
    doc = BuildingSync::Helper.read_xml_file_document(xml_path)
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

    doc_output = BuildingSync::Helper.read_xml_file_document(xml_path_output)
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

  it 'create_calculation_method_element(result) should correctly create and return an auc:CalculationMethod element' do
    # -- Setup
    file_name = 'building_151.xml'
    xml_path = File.expand_path("./../files/#{file_name}", File.dirname(__FILE__))
    expect(File.exist?(xml_path)).to be true
    ns = 'auc'
    doc = BuildingSync::Helper.read_xml_file_document(xml_path)
    workflow_maker = BuildingSync::WorkflowMaker.new(doc, ns)

    # -- Setup
    # Create a dummy result
    result_success = {}
    result_failed = {}
    result_xxx = {}

    result_success[:completed_status] = 'Success'
    result_failed[:completed_status] = 'Failed'
    result_xxx[:completed_status] = 'XXX'

    calc_method_success = workflow_maker.create_calculation_method_element(result_success)
    calc_method_failed = workflow_maker.create_calculation_method_element(result_failed)
    calc_method_xxx = workflow_maker.create_calculation_method_element(result_xxx)

    # -- Assert
    expect(calc_method_success.elements["#{ns}:Modeled/#{ns}:SimulationCompletionStatus"].text).to be == 'Finished'
    expect(calc_method_failed.elements["#{ns}:Modeled/#{ns}:SimulationCompletionStatus"].text).to eq 'Failed'
    expect(calc_method_xxx.elements["#{ns}:Modeled/#{ns}:SimulationCompletionStatus"].text).to eq 'Failed'
  end

  # TODO: Come back to
  it 'should process monthly data correctly' do
    # -- Setup
    file_name = 'building_151.xml'
    xml_path = File.expand_path("./../files/#{file_name}", File.dirname(__FILE__))
    expect(File.exist?(xml_path)).to be true
    ns = 'auc'
    doc = BuildingSync::Helper.read_xml_file_document(xml_path)
    workflow_maker = BuildingSync::WorkflowMaker.new(doc, ns)

    month_lookup = { 1 => 'jan', 2 => 'feb', 3 => 'mar', 4 => 'apr', 5 => 'may', 6 => 'jun', 7 => 'jul', 8 => 'aug', 9 => 'sep', 10 => 'oct', 11 => 'nov', 12 => 'dec' }
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
