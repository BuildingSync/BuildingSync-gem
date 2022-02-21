# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2021, Alliance for Sustainable Energy, LLC.
# BuildingSync(R), Copyright (c) 2015-2021, Alliance for Sustainable Energy, LLC.
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
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO
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
require 'rexml/document'

require 'buildingsync/generator'
require 'buildingsync/scenario'

require_relative './../spec_helper'

RSpec.describe 'Scenario' do
  it 'should raise an error given a non-Scenario REXML Element' do
    # -- Setup
    ns = 'auc'
    v = '2.4.0'
    g = BuildingSync::Generator.new(ns, v)
    doc_string = g.create_bsync_root_to_building
    doc = REXML::Document.new(doc_string)
    g.add_report_to_first_facility(doc)
    report_elements = doc.get_elements("//#{ns}:Report")

    # -- Create scenario object from report
    begin
      scenario = BuildingSync::Scenario.new(report_elements.first, ns)
    rescue StandardError => e
      expect(e.message).to eql 'Attempted to initialize Scenario object with Element name of: Report'
    end
  end

  it 'should populate a Scenario object given Scenario REXML Element' do
    # -- Setup
    ns = 'auc'
    v = '2.4.0'
    g = BuildingSync::Generator.new(ns, v)
    doc_string = g.create_bsync_root_to_building
    doc = REXML::Document.new(doc_string)
    g.add_report_to_first_facility(doc)
    g.add_scenario_to_first_report(doc)
    scenario_element = doc.get_elements("//#{ns}:Scenarios/#{ns}:Scenario").first

    # -- Create new Scenario object
    scenario = BuildingSync::Scenario.new(scenario_element, ns)

    # -- Assert
    expect(scenario.xget_id == 'Scenario-1').to be true
    expect(scenario.xget_element('ScenarioType')).to be_an_instance_of(REXML::Element)
    expect(scenario.xget_element('ScenarioType').to_s == '<auc:ScenarioType><auc:CurrentBuilding><auc:CalculationMethod><auc:Measured/></auc:CalculationMethod></auc:CurrentBuilding></auc:ScenarioType>')
  end
end

RSpec.describe 'Scenario Measures' do
  it 'building_151_one_scenario.xml should set measure_ids correctly for each Scenario' do
    # -- Setup
    file_name = 'building_151_one_scenario.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.4.0')
    ns = 'auc'
    doc = help_load_doc(xml_path)

    baseline_scenario_xml = doc.get_elements("//#{ns}:Scenario")[0]
    pom_scenario_xml = doc.get_elements("//#{ns}:Scenario")[1]

    # -- Assert we have correct scenarios
    expect(baseline_scenario_xml.attributes['ID']).to eql 'Baseline'
    expect(pom_scenario_xml.attributes['ID']).to eql 'Scenario1'

    # -- Setup - create new scenario elements
    baseline_scenario = BuildingSync::Scenario.new(baseline_scenario_xml, ns)
    pom_scenario = BuildingSync::Scenario.new(pom_scenario_xml, ns)

    # -- Assert
    expect(baseline_scenario.get_measure_ids.empty?).to be true
    expect(pom_scenario.get_measure_ids.size).to eql 1
    expect(pom_scenario.get_measure_ids[0]).to eql 'Measure1'
  end
end

RSpec.describe 'Scenario Type Discovery Methods' do
  to_test = [
    ['CBMeasured', true, false, false, false, false],
    [nil, false, false, false, false, false],
    ['CBModeled', false, false, true, false, false],
    ['POM', false, true, false, false, false],
    ['Benchmark', false, false, false, true, false],
    ['Target', false, false, false, false, true]
  ]
  to_test.each do |test|
    it 'cb_measured?, cb_modeled?, pom?, benchmark?, target? methods should evaluate as expected' do
      # -- Setup
      ns = 'auc'
      v = '2.4.0'
      g = BuildingSync::Generator.new(ns, v)
      doc_string = g.create_bsync_root_to_building
      doc = REXML::Document.new(doc_string)
      g.add_report_to_first_facility(doc)

      # -- Setup
      g.add_scenario_to_first_report(doc, test[0])
      scenario_element = doc.get_elements("//#{ns}:Scenarios/#{ns}:Scenario")[0]

      # -- Create new Scenario object
      scenario = BuildingSync::Scenario.new(scenario_element, ns)

      # -- Assert
      expect(scenario.cb_measured?).to be test[1]
      expect(scenario.pom?).to be test[2]
      expect(scenario.cb_modeled?).to be test[3]
      expect(scenario.benchmark?).to be test[4]
      expect(scenario.target?).to be test[5]
    end
  end
end

RSpec.describe 'Scenario data creation' do
  it 'should remove ResourceUses, AllResourceTotals, and TimeSeriesData from cb_modeled and pom, but not benchmark, target, or cb_measured' do
    # -- Setup
    ns = 'auc'
    v = '2.4.0'
    g = BuildingSync::Generator.new(ns, v)
    doc_string = g.create_bsync_root_to_building
    doc = REXML::Document.new(doc_string)
    g.add_report_to_first_facility(doc)

    # -- Setup - create one of each scenario type
    scenarios = []
    scenario_types = ['CBModeled', 'CBMeasured', 'Target', 'Benchmark', 'POM']
    scenario_types.each_with_index do |i, st|
      scenarios << g.add_scenario_to_first_report(doc, st, "Scenario-#{i}")
    end

    # -- Setup
    scenarios.each do |scenario|
      g.add_energy_resource_use_to_scenario(scenario)
      g.add_all_resource_total_to_scenario(scenario)
      g.add_time_series_to_scenario(scenario)
      s = BuildingSync::Scenario.new(scenario, ns)
      if s.pom? || s.cb_modeled?
        expect(s.get_resource_uses.empty?).to be true
        expect(s.get_all_resource_totals.empty?).to be true
        expect(s.get_time_series_data.empty?).to be true
      else
        expect(s.get_resource_uses.size).to eql 1
        expect(s.get_all_resource_totals.size).to eql 1
        expect(s.get_time_series_data.size).to eql 1
      end
    end
  end
  it 'should have attributes (all_resource_totals, resource_uses, time_series_data) with the correct types' do
    # -- Setup
    ns = 'auc'
    v = '2.4.0'
    g = BuildingSync::Generator.new(ns, v)
    doc_string = g.create_bsync_root_to_building
    doc = REXML::Document.new(doc_string)
    g.add_report_to_first_facility(doc)

    # Add a scenario type that will not have the results deleted from it
    scenario = g.add_scenario_to_first_report(doc, 'Target')
    g.add_energy_resource_use_to_scenario(scenario)
    g.add_all_resource_total_to_scenario(scenario)
    g.add_time_series_to_scenario(scenario)

    s = BuildingSync::Scenario.new(scenario, ns)

    # -- Assert
    expect(s.get_resource_uses).to be_an_instance_of(Array)
    expect(s.get_all_resource_totals).to be_an_instance_of(Array)
    expect(s.get_time_series_data).to be_an_instance_of(Array)

    expect(s.get_resource_uses[0]).to be_an_instance_of(BuildingSync::ResourceUse)
    expect(s.get_all_resource_totals[0]).to be_an_instance_of(BuildingSync::AllResourceTotal)
    expect(s.get_time_series_data[0]).to be_an_instance_of(BuildingSync::TimeSeries)
  end
end

RSpec.describe 'Scenario workflow configuration' do
  it 'set_workflow should set the correct attribute given a Hash' do
    # -- Setup
    ns = 'auc'
    v = '2.4.0'
    g = BuildingSync::Generator.new(ns, v)
    doc_string = g.create_bsync_root_to_building
    doc = REXML::Document.new(doc_string)
    g.add_report_to_first_facility(doc)

    # -- Setup
    # Only requirements for a workflow is that it is a Hash
    workflow = {
      "seed_file": '../in.osm'
    }
    scenario = g.add_scenario_to_first_report(doc, 'CBModeled')
    s = BuildingSync::Scenario.new(scenario, ns)

    # -- Assert
    expect(s.get_workflow.empty?).to be true
    s.set_workflow(workflow)
    expect(s.get_workflow.empty?).to be false
  end
  it 'set_workflow should raise a StandardError given a non-hash object' do
    # -- Setup
    ns = 'auc'
    v = '2.4.0'
    g = BuildingSync::Generator.new(ns, v)
    doc_string = g.create_bsync_root_to_building
    doc = REXML::Document.new(doc_string)
    g.add_report_to_first_facility(doc)

    # -- Setup
    # Only requirements for a workflow is that it is a Hash
    workflow = true
    scenario = g.add_scenario_to_first_report(doc, 'CBModeled')
    s = BuildingSync::Scenario.new(scenario, ns)

    # -- Assert
    expect(s.get_workflow.empty?).to be true
    begin
      s.set_workflow(workflow)

      # should not get here
      expect(false).to be true
    rescue StandardError => e
      expect(e.message).to eql 'BuildingSync.Scenario.set_workflow Scenario ID: Scenario-1.  Cannot set_workflow, argument must be a Hash, not a TrueClass'
    end
  end
  it 'set_main_output_dir should set the @main_output_dir attribute' do
    # -- Setup
    ns = 'auc'
    v = '2.4.0'
    g = BuildingSync::Generator.new(ns, v)
    doc_string = g.create_bsync_root_to_building
    doc = REXML::Document.new(doc_string)
    g.add_report_to_first_facility(doc)

    # -- Setup
    # Only requirements for a workflow is that it is a Hash
    scenario = g.add_scenario_to_first_report(doc, 'CBModeled')
    s = BuildingSync::Scenario.new(scenario, ns)

    # -- Assert
    expect(s.get_main_output_dir.nil?).to be true
    s.set_main_output_dir('/path/to/dir')
    expect(s.get_main_output_dir).to eql '/path/to/dir'
  end
  it 'set_osw_dir should set the @osw_dir attribute using the Scenario ID' do
    # -- Setup
    ns = 'auc'
    v = '2.4.0'
    g = BuildingSync::Generator.new(ns, v)
    doc_string = g.create_bsync_root_to_building
    doc = REXML::Document.new(doc_string)
    g.add_report_to_first_facility(doc)

    # -- Setup
    # Only requirements for a workflow is that it is a Hash
    # Default ID for scenario added by this method is Scenario-1
    scenario = g.add_scenario_to_first_report(doc, 'CBModeled')
    s = BuildingSync::Scenario.new(scenario, ns)

    # -- Assert
    expect(s.get_osw_dir.nil?).to be true
    s.set_osw_dir('/path/to/dir')
    expect(s.get_osw_dir).to eql '/path/to/dir/Scenario-1'
  end
  it 'set_osw_dir should set the @osw_dir attribute using the ScenarioName when provided' do
    # -- Setup
    ns = 'auc'
    v = '2.4.0'
    g = BuildingSync::Generator.new(ns, v)
    doc_string = g.create_bsync_root_to_building
    doc = REXML::Document.new(doc_string)
    g.add_report_to_first_facility(doc)

    # -- Setup
    # Only requirements for a workflow is that it is a Hash
    # Default ID for scenario added by this method is Scenario-1
    scenario = g.add_scenario_to_first_report(doc, 'CBModeled')

    # Add a name to the Scenario
    scenario_name = REXML::Element.new("#{ns}:ScenarioName", scenario)
    scenario_name.text = 'LED Only'
    s = BuildingSync::Scenario.new(scenario, ns)

    # -- Assert
    expect(s.get_osw_dir.nil?).to be true
    s.set_osw_dir('/path/to/dir')
    expect(s.get_osw_dir).to eql '/path/to/dir/LED Only'
  end
  it 'osw_mkdir_p make the specified directory only when @osw_dir is set, else it raises an error' do
    # -- Setup
    ns = 'auc'
    v = '2.4.0'
    g = BuildingSync::Generator.new(ns, v)
    doc_string = g.create_bsync_root_to_building
    doc = REXML::Document.new(doc_string)
    g.add_report_to_first_facility(doc)

    # -- Setup output path
    file_name = 'blank.file'
    main_output_path = File.join(SPEC_OUTPUT_DIR, "#{File.basename(__FILE__, File.extname(__FILE__))}/#{File.basename(file_name, File.extname(file_name))}")
    FileUtils.rm_rf(main_output_path) if Dir.exist?(main_output_path)

    # -- Setup
    # Only requirements for a workflow is that it is a Hash
    # Default ID for scenario added by this method is Scenario-1
    scenario = g.add_scenario_to_first_report(doc, 'CBModeled')
    s = BuildingSync::Scenario.new(scenario, ns)

    # -- Assert - no @osw_dir set, should StandardError
    expect(s.get_osw_dir.nil?).to be true
    begin
      s.osw_mkdir_p
    rescue StandardError => e
      expect(e.message).to eql 'BuildingSync.Scenario.osw_mkdir_p Scenario ID: Scenario-1.  @osw_dir must be set first'
    end

    # -- Assert - @osw_dir set, should work.
    expect(s.get_osw_dir.nil?).to be true
    s.set_osw_dir(main_output_path)
    s.osw_mkdir_p
    expect(Dir.exist?(s.get_osw_dir)).to be true
  end
  it 'write_osw should work regardless of the data in the @workflow' do
    # -- Setup
    ns = 'auc'
    v = '2.4.0'
    g = BuildingSync::Generator.new(ns, v)
    doc_string = g.create_bsync_root_to_building
    doc = REXML::Document.new(doc_string)
    g.add_report_to_first_facility(doc)

    # -- Setup output path
    file_name = 'blank.file'
    main_output_path = File.join(SPEC_OUTPUT_DIR, "#{File.basename(__FILE__, File.extname(__FILE__))}/#{File.basename(file_name, File.extname(file_name))}")
    FileUtils.rm_rf(main_output_path) if Dir.exist?(main_output_path)

    # -- Setup
    # Only requirements for a workflow is that it is a Hash
    # Default ID for scenario added by this method is Scenario-1
    scenario = g.add_scenario_to_first_report(doc, 'CBModeled')
    s = BuildingSync::Scenario.new(scenario, ns)

    in_osw = File.join(main_output_path, 'Scenario-1', 'in.osw')

    # -- Assert - should work with empty workflow
    expect(s.get_workflow.empty?).to be true
    s.write_osw(main_output_path)
    expect(File.exist?(in_osw)).to be true

    # -- Setup
    workflow = {
      "seed_file": '../in.osm'
    }

    # -- Assert - should work with
    File.delete(in_osw)
    expect(File.exist?(in_osw)).to be false
    s.set_workflow(workflow)
    s.write_osw(main_output_path)
    expect(File.exist?(in_osw)).to be true
  end
end

RSpec.describe 'Scenario Results Parsing' do
  describe 'Annual Results' do
    it 'os_add_resource_uses should create two ResourceUses (Electricity, Natural gas) and add correct child elements and values' do
      # -- Setup
      ns = 'auc'
      g = BuildingSync::Generator.new(ns)
      doc_string = g.create_bsync_root_to_building
      doc = REXML::Document.new(doc_string)
      g.add_report_to_first_facility(doc)

      # -- Setup
      scenario_xml = g.add_scenario_to_first_report(doc, 'CBModeled')
      s = BuildingSync::Scenario.new(scenario_xml, ns)

      # -- Setup - read in IP results json file
      results = {}
      File.open(File.join(SPEC_FILES_DIR, 'ip_results.json'), 'r') do |file|
        results = JSON.parse(file.read)
      end
      s.os_add_resource_uses(results)

      # -- Assert
      expect(s.get_resource_uses.size).to eq(2)

      # -- Assert - Electricity checks
      elec = s.get_resource_uses[0]
      expect(elec.xget_text('EnergyResource')).to eq('Electricity')
      expect(elec.xget_text('EndUse')).to eq('All end uses')
      expect(elec.xget_text_as_float('AnnualFuelUseConsistentUnits')).to be_within(0.01).of(180.644)
      expect(elec.xget_text_as_float('AnnualPeakConsistentUnits')).to be_within(0.01).of(19.06)

      # -- Assert - Natural Gas checks
      ng = s.get_resource_uses[1]
      expect(ng.xget_text('EnergyResource')).to eq('Natural gas')
      expect(ng.xget_text('EndUse')).to eq('All end uses')
      expect(ng.xget_text_as_float('AnnualFuelUseConsistentUnits')).to be_within(0.01).of(0.218)
    end

    it 'os_add_all_resource_totals should create one AllResourceTotal with the correct child elements and values' do
      # -- Setup
      ns = 'auc'
      g = BuildingSync::Generator.new(ns)
      doc_string = g.create_bsync_root_to_building
      doc = REXML::Document.new(doc_string)
      g.add_report_to_first_facility(doc)

      # -- Setup
      scenario_xml = g.add_scenario_to_first_report(doc, 'CBModeled')
      s = BuildingSync::Scenario.new(scenario_xml, ns)

      # -- Setup - read in IP results json file
      results = {}
      File.open(File.join(SPEC_FILES_DIR, 'ip_results.json'), 'r') do |file|
        results = JSON.parse(file.read)
      end
      s.os_add_all_resource_totals(results)

      # -- Assert
      expect(s.get_all_resource_totals.size).to eq(1)

      # -- Assert - Electricity checks
      art = s.get_all_resource_totals[0]
      expect(art.xget_text('EndUse')).to eq('All end uses')
      expect(art.xget_text_as_float('SiteEnergyUse')).to be_within(0.01).of(180_862.46)
      expect(art.xget_text_as_float('SiteEnergyUseIntensity')).to be_within(0.01).of(32.87)
    end
  end

  describe 'Monthly Processing' do
    before(:each) do
      # -- Setup
      ns = 'auc'
      g = BuildingSync::Generator.new(ns)
      doc_string = g.create_bsync_root_to_building
      @doc = REXML::Document.new(doc_string)
      g.add_report_to_first_facility(@doc)

      # -- Setup
      scenario_xml = g.add_scenario_to_first_report(@doc, 'CBModeled')
      @s = BuildingSync::Scenario.new(scenario_xml, ns)

      # -- Setup - read in IP results json file
      @results = {}
      File.open(File.join(SPEC_FILES_DIR, 'ip_results.json'), 'r') do |file|
        @results = JSON.parse(file.read)
      end

      # -- This adds the necessary ResourceUses which we need to link to
      @s.os_add_resource_uses(@results)
    end
    # TODO
    it 'os_parse_monthly_all_end_uses_results should add monthly timeseries data and link to the correct ResourceUse' do
      @s.os_parse_monthly_all_end_uses_results
    end
  end
end
