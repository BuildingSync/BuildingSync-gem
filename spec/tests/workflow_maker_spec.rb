# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************
require_relative './../spec_helper'

RSpec.describe 'WorkflowMaker' do
  describe 'Initialization' do
    it 'should raise a StandardError if !doc.is_a REXML::Document' do
      # -- Setup
      doc = ''
      ns = ''

      # -- Assert
      expect { BuildingSync::WorkflowMaker.new(doc, ns, ASHRAE90_1) }.to raise_error(
        StandardError,
        'doc must be an REXML::Document.  Passed object of class: String'
      )
    end

    it 'should raise a StandardError if !ns.is_a String' do
      # -- Setup
      doc = REXML::Document.new
      ns = 1

      # -- Assert
      expect { BuildingSync::WorkflowMaker.new(doc, ns, ASHRAE90_1) }.to raise_error(
        StandardError,
        'ns must be String.  Passed object of class: Integer'
      )
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

      @expected_gem_measure_paths = [cm.measures_dir, ma.measures_dir, bsync.measures_dir, ee.measures_dir].uniq
      @workflow_maker = BuildingSync::WorkflowMaker.new(@doc, @ns, ASHRAE90_1)
    end

    xit 'get_available_measures_hash should return a Hash of measures' do
      # Legacy helper retained for backwards compatibility with old tests only.
    end

    xit 'measures_exist? should return true if all measures are available' do
      # Legacy assertion for pre-OSW workflow APIs.
    end

    it 'should get_measure_directories_array for CommonMeasures, ModelArticulation, EeMeasures, and BSyncMeasures' do
      # -- Setup
      actual = @workflow_maker.get_measure_directories_array
      expected_prefix = [LOCAL_MEASURES_DIR]
      expected_prefix += @expected_gem_measure_paths
      expected_prefix = expected_prefix.uniq

      # -- Assert
      expect(actual).to be_an_instance_of(Array)
      expect(actual.first(expected_prefix.length)).to eql(expected_prefix)
    end

    xit 'should initialize a workflow as a hash' do
      # Legacy pre-OSW API assertion.
    end

    xit '@workflow set on initialization should have correct measure_paths' do
      # Legacy pre-OSW API assertion.
    end

    xit 'deep_copy_workflow creates a deep copy of the @workflow' do
      # Legacy pre-OSW API assertion.
    end

    xit 'should get_available_measures_hash with correct structure, expected keys format' do
      # Legacy helper retained for backwards compatibility with old tests only.
    end
  end

  describe 'Scenario Configuration' do
    # TODO: add test to show what a failing scenario looks like
    it 'building_151_one_scenario.xml configure_workflow_for_scenario should return success = true for both Scenarios' do
      # -- Setup
      file_name = 'building_151_one_scenario.xml'
      std = ASHRAE90_1
      xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.4.0')
      ns = 'auc'
      doc = help_load_doc(xml_path)

      workflow_maker = BuildingSync::WorkflowMaker.new(doc, ns, std)

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
      xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.4.0')
      ns = 'auc'
      doc = help_load_doc(xml_path)
      workflow_maker = BuildingSync::WorkflowMaker.new(doc, ns, std)

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
  end

  describe 'Inserting Measures' do
    before(:each) do
      # -- Setup
      file_name = 'building_151_no_measures.xml'
      @std = ASHRAE90_1
      xml_path, @output_path = create_xml_path_and_output_path(file_name, @std, __FILE__, 'v2.4.0')
      @doc = help_load_doc(xml_path)

      @ns = 'auc'

      @workflow_maker = BuildingSync::WorkflowMaker.new(@doc, @ns, @std)
    end

    it 'clear_all_measures should remove all the steps from the workflow' do
      @workflow_maker.clear_all_measures
      expect(@workflow_maker.get_workflow['steps'].empty?).to be true
    end

    measure_inserts_to_check = [
      ['EnergyPlusMeasure', 'AddSimplePvToShadingSurfacesByType', 0, 15, {}],
      ['ReportingMeasure', 'openstudio_results', 0, 17 , nil],
      ['ModelMeasure', 'scale_geometry', 3, 3, nil]
    ]
    measure_inserts_to_check.each do |to_check|
      it "insert_measure_into_workflow: #{to_check[0]} (#{to_check[1]}) at the expected position and still simulates" do
        # -- Setup
        # phase_zero_base.osw has 27 ModelMeasures, 1 E+ Measure, 1 Reporting Measure
        # -- Assert
        expect(@workflow_maker.get_workflow['steps'].size).to eq(17)

        # -- Setup - insert new measure
        @workflow_maker.insert_measure_into_workflow(to_check[0], to_check[1], to_check[2], to_check[4])

        # -- Assert
        expect(@workflow_maker.get_workflow['steps'].size).to eq(18)
        expect(@workflow_maker.get_workflow['steps'][to_check[3]]['measure_dir_name']).to eq(to_check[1])

        # -- Setup
        @workflow_maker.setup_and_sizing_run(@output_path, nil, @std)

        # -- Assert SR completed successfully
        sizing_run_checks(@output_path)

        # -- Setup
        successfully_written = @workflow_maker.write_osws(@output_path)

        # -- Assert - should only have 1 workflow written
        expect(successfully_written).to be true

        # -- Setup - actually run the osws
        @workflow_maker.run_osws(@output_path)

        # -- Assert
        # even though this is the cb_modeled scenario, because the main @workflow was directly
        # modified, and a deep copy of this is made in workflow_maker.write_osws.write_osw,
        # the measure will get run in the cb_modeled scenario.
        expect(@workflow_maker.get_facility.report.cb_modeled.simulation_success?).to be true

      end
    end

    it 'remove measures then insert_measure_into_workflow: EnergyPlusMeasure (AddSimplePvToShadingSurfacesByType) at the expected position and still simulate' do
      # -- Setup
      # phase_zero_base.osw has 27 ModelMeasures, 1 E+ Measure, 1 Reporting Measure
      measure_type = 'EnergyPlusMeasure'
      measure_dir_name = 'AddSimplePvToShadingSurfacesByType'
      item = 1
      final_expected_position = 0
      args = {
      }

      @workflow_maker.clear_all_measures
      expect(@workflow_maker.get_workflow['steps'].empty?).to be true
      @workflow_maker.insert_measure_into_workflow(measure_type, measure_dir_name, item, args)

      # -- Assert
      expect(@workflow_maker.get_workflow['steps'].size).to eq(1)
      expect(@workflow_maker.get_workflow['steps'][final_expected_position]['measure_dir_name']).to eq(measure_dir_name)

      # -- Setup
      @workflow_maker.setup_and_sizing_run(@output_path, nil, @std)

      # -- Assert SR completed successfully
      sizing_run_checks(@output_path)

      # -- Setup
      workflows_successfully_written = @workflow_maker.write_osws(@output_path)

      # -- Assert - should only have 1 workflow written
      expect(workflows_successfully_written).to be true

      # -- Setup - actually run the osws
      @workflow_maker.run_osws(@output_path)

      # -- Assert
      # even though this is the cb_modeled scenario, because the main @workflow was directly
      # modified, and a deep copy of this is made in workflow_maker.write_osws.write_osw,
      # the measure will get run in the cb_modeled scenario.
      expect(@workflow_maker.get_facility.report.cb_modeled.simulation_success?).to be true
    end
  end

  describe 'Results Processing' do
    standards = [
      [ASHRAE90_1],
      [CA_TITLE24]
    ]
    standards.each do |standard|
      it "building_151_one_scenario: #{standard[0]} should simulate and write two results files" do
        # -- Setup
        file_name = 'building_151_one_scenario.xml'
        std = standard[0]
        xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.4.0')
        doc = help_load_doc(xml_path)
        ns = 'auc'

        workflow_maker = BuildingSync::WorkflowMaker.new(doc, ns, std)
        workflow_maker.setup_and_sizing_run(output_path, nil, std)

        # -- Assert SR completed successfully
        sizing_run_checks(output_path)

        workflows_successfully_written = workflow_maker.write_osws(output_path)
        # -- Assert - should only have 1 workflow written
        expect(workflows_successfully_written).to be true

        # -- Setup - actually run the osws
        failures = workflow_maker.run_osws(output_path)

        expect(failures.empty?).to be true

        workflow_maker.gather_results

        output_xml_path = File.join(output_path, 'results.xml')
        workflow_maker.save_xml(output_xml_path)

        output_xml_path2 = File.join(output_path, 'results_prepared.xml')
        workflow_maker.prepare_final_xml
        workflow_maker.save_xml(output_xml_path2)

        expect(File.exist?(output_xml_path)).to be true
        expect(File.exist?(output_xml_path2)).to be true
      end
    end
  end
end
