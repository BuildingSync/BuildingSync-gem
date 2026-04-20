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
      begin
        workflow_maker = BuildingSync::WorkflowMaker.new(doc, ns, ASHRAE90_1)
      rescue StandardError => e
        expect(e.message).to eql 'doc must be an REXML::Document.  Passed object of class: String'
      end
    end

    it 'should raise a StandardError if !ns.is_a String' do
      # -- Setup
      doc = REXML::Document.new
      ns = 1

      # -- Assert
      begin
        workflow_maker = BuildingSync::WorkflowMaker.new(doc, ns, ASHRAE90_1)
      rescue StandardError => e
        expect(e.message).to eql 'ns must be String.  Passed object of class: Integer'
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
      @workflow_maker = BuildingSync::WorkflowMaker.new(@doc, @ns, ASHRAE90_1)
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
      expect(available_measures[cm.measures_dir].find { |item| item == 'SetEnergyPlusMinimumOutdoorAirFlowRate' }).to_not be nil
    end
  end

  describe 'Scenario Configuration' do
    # TODO: add test to show what a failing scenario looks like
    it 'building_151_one_scenario.xml configure_workflow_for_scenario should return success = true for both Scenarios' do
      # -- Setup
      file_name = 'building_151_one_scenario.xml'
      std = ASHRAE90_1
      xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.7.0')
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
      xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.7.0')
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
      expect(File.exist?(File.join(output_path, 'cb_modeled', 'in.osw'))).to be true
      expect(File.exist?(File.join(output_path, 'LED Only', 'in.osw'))).to be true
    end
  end

  describe 'Inserting Measures' do
    before(:each) do
      # -- Setup
      file_name = 'building_151_no_measures.xml'
      @std = ASHRAE90_1
      xml_path, @output_path = create_xml_path_and_output_path(file_name, @std, __FILE__, 'v2.7.0')
      @doc = help_load_doc(xml_path)

      @ns = 'auc'

      @workflow_maker = BuildingSync::WorkflowMaker.new(@doc, @ns, @std)
    end

    it 'clear_all_measures should remove all the steps from the workflow' do
      @workflow_maker.clear_all_measures
      expect(@workflow_maker.get_workflow['steps'].empty?).to be true
    end

    measure_inserts_to_check = [
      ['EnergyPlusMeasure', 'AddSimplePvToShadingSurfacesByType', 0, 27, {}],
      ['ReportingMeasure', 'openstudio_results', 0, 27, nil],
      ['ModelMeasure', 'scale_geometry', 3, 3, nil]
    ]
    measure_inserts_to_check.each do |to_check|
      it "insert_measure_into_workflow: #{to_check[0]} (#{to_check[1]}) at the expected position and still simulates" do
        # -- Setup
        # Workflow is pre-populated with ModelMeasures from workflow_maker.json that exist in installed gems
        # -- Assert
        expect(@workflow_maker.get_workflow['steps'].size).to eq(28)

        # -- Setup - insert new measure
        @workflow_maker.insert_measure_into_workflow(to_check[0], to_check[1], to_check[2], to_check[4])

        # -- Assert
        expect(@workflow_maker.get_workflow['steps'].size).to eq(29)
        expect(@workflow_maker.get_workflow['steps'][to_check[3]]['measure_dir_name']).to eq(to_check[1])

        # -- Setup - write and run baseline OSW
        epw_file_path = File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw')
        @workflow_maker.write_baseline_osw(@output_path, epw_file_path)
        @workflow_maker.run_baseline_osw(@output_path)

        # -- Assert baseline completed successfully
        out_osw_path = File.join(@output_path, 'baseline', 'out.osw')
        expect(File.exist?(out_osw_path)).to be true
        out_osw = JSON.parse(File.read(out_osw_path), symbolize_names: true)
        expect(out_osw[:completed_status]).to eq 'Success'

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
      # Workflow is pre-populated with ModelMeasures from workflow_maker.json that exist in installed gems
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

      # -- Setup - write and run baseline OSW
      epw_file_path = File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw')
      @workflow_maker.write_baseline_osw(@output_path, epw_file_path)
      @workflow_maker.run_baseline_osw(@output_path)

      # -- Assert baseline completed successfully
      out_osw_path = File.join(@output_path, 'baseline', 'out.osw')
      expect(File.exist?(out_osw_path)).to be true
      out_osw = JSON.parse(File.read(out_osw_path), symbolize_names: true)
      expect(out_osw[:completed_status]).to eq 'Success'

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
        xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.7.0')
        doc = help_load_doc(xml_path)
        ns = 'auc'

        workflow_maker = BuildingSync::WorkflowMaker.new(doc, ns, std)

        # -- Setup - write and run baseline OSW
        epw_file_path = File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw')
        workflow_maker.write_baseline_osw(output_path, epw_file_path)
        workflow_maker.run_baseline_osw(output_path)

        # -- Assert baseline completed successfully
        out_osw_path = File.join(output_path, 'baseline', 'out.osw')
        expect(File.exist?(out_osw_path)).to be true
        out_osw = JSON.parse(File.read(out_osw_path), symbolize_names: true)
        expect(out_osw[:completed_status]).to eq 'Success'

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
