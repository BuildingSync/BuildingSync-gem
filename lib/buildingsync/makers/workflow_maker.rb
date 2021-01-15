# frozen_string_literal: true

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
require 'rexml/document'

require 'openstudio/common_measures'
require 'openstudio/model_articulation'
require 'openstudio/ee_measures'

require 'buildingsync/extension'
require 'buildingsync/constants'
require 'buildingsync/scenario'
require 'buildingsync/makers/workflow_maker_base'
require 'buildingsync/model_articulation/facility'

module BuildingSync
  # base class for objects that will configure workflows based on building sync files
  class WorkflowMaker < WorkflowMakerBase
    # initialize - load workflow json file and add necessary measure paths
    # @param doc [REXML::Document]
    # @param ns [String]
    def initialize(doc, ns)
      super(doc, ns)

      if !doc.is_a?(REXML::Document)
        raise StandardError, "doc must be an REXML::Document.  Passed object of class: #{doc.class}"
      end

      if !ns.is_a?(String)
        raise StandardError, 'ns must be String.  Passed object of class: Int'
      end

      @facility_xml = nil
      @facility = nil

      @failed_scenarios = []

      # TODO: Be consistent in symbolizing names in hashes or not
      File.open(PHASE_0_BASE_OSW_FILE_PATH, 'r') do |file|
        @workflow = JSON.parse(file.read)
      end

      File.open(WORKFLOW_MAKER_JSON_FILE_PATH, 'r') do |file|
        @workflow_maker_json = JSON.parse(file.read, symbolize_names: true)
      end

      # Add all of the measure directories from the extension gems
      # into the @workflow, then check they exist
      set_measure_paths(get_measure_directories_array)
      measures_exist?
      read_xml
    end

    def read_xml
      facility_xml_temp = @doc.get_elements("#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility")

      # Raise errors for zero or multiple Facilities.  Not supported at this time.
      if facility_xml_temp.nil? || facility_xml_temp.empty?
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMaker.populate_facility_report_and_scenarios', 'There are no Facility elements in your BuildingSync file.')
        raise StandardError, 'There are no Facility elements in your BuildingSync file.'
      elsif facility_xml_temp.size > 1
        @facility_xml = facility_xml_temp.first
        OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.WorkflowMaker.populate_facility_report_and_scenarios', "There are more than one (#{facility_xml_temp.size}) Facility elements in your BuildingSync file. Only the first Facility will be considered (ID: #{@facility_xml.attributes['ID']}")
      else
        @facility_xml = facility_xml_temp.first
      end

      OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.WorkflowMaker.read_xml', "Setting up workflow for Facility ID: #{@facility_xml.attributes['ID']}")

      # Initialize Facility object
      @facility = BuildingSync::Facility.new(@facility_xml, @ns)
    end

    # get the facility object from this workflow
    # @return [BuildingSync::Facility] facility
    def get_facility
      return @facility
    end

    # get the space types of the facility
    # @return [Vector<OpenStudio::Model::SpaceType>] vector of space types
    def get_space_types
      return @facility.get_space_types
    end

    # get model
    # @return [OpenStudio::Model] model
    def get_model
      return @facility.get_model
    end

    # get the current workflow
    # @return [Hash]
    def get_workflow
      return @workflow
    end

    # get scenario elements
    # @return [Array<BuildingSync::Scenario>]
    def get_scenarios
      return @facility.report.scenarios
    end

    # generate the baseline model as osm model
    # @param dir [String]
    # @param epw_file_path [String]
    # @param standard_to_be_used [String] 'ASHRAE90.1' or 'CaliforniaTitle24' are supported options
    # @param ddy_file [String] path to the ddy file
    # @return @see BuildingSync::Facility.write_osm
    def setup_and_sizing_run(dir, epw_file_path, standard_to_be_used, ddy_file = nil)
      @facility.set_all
      @facility.determine_open_studio_standard(standard_to_be_used)
      @facility.generate_baseline_osm(epw_file_path, dir, standard_to_be_used, ddy_file)
      @facility.write_osm(dir)
    end

    # writes the parameters determined during processing back to the BldgSync XML file
    def prepare_final_xml
      @facility.prepare_final_xml
    end

    # # write osm
    # # @param dir [String]
    # def write_osm(dir)
    #   @scenario_types = @facility.write_osm(dir)
    # end

    # iterate over the current measure list in the workflow and check if they are available at the referenced measure directories
    # @return [Boolean]
    def measures_exist?
      all_measures_found = true
      number_measures_found = 0
      @workflow['steps'].each do |step|
        measure_is_valid = false
        measure_dir_name = step['measure_dir_name']
        get_measure_directories_array.each do |potential_measure_path|
          measure_dir_full_path = "#{potential_measure_path}/#{measure_dir_name}"
          if Dir.exist?(measure_dir_full_path)
            measure_is_valid = true
            OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.WorkflowMaker.measures_exist?', "Measure: #{measure_dir_name} found at: #{measure_dir_full_path}")
            number_measures_found += 1
            break
          end
        end
        if !measure_is_valid
          all_measures_found = false
          OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMaker.measures_exist?', "CANNOT find measure with name (#{measure_dir_name}) in any of the measure paths  ")
        end
      end
      if all_measures_found
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.WorkflowMaker.measures_exist?', "Total measures found: #{number_measures_found}. All measures defined by @workflow found.")
        puts "Total measures found: #{number_measures_found}. All measures defined by @workflow found."
      end
      return all_measures_found
    end

    # gets all available measures across all measure directories
    # @return [hash] Looks as follows {path_to_measure_dir: [measure_name1, mn2, etc.], path_to_measure_dir_2: [...]}
    def get_available_measures_hash
      measures_hash = {}
      get_measure_directories_array.each do |potential_measure_path|
        Dir.chdir(potential_measure_path) do
          measures_hash[potential_measure_path] = Dir.glob('*').select { |f| File.directory? f }
        end
      end
      return measures_hash
    end

    # collect all measure directories that contain measures needed for BldgSync
    # @return [array] of measure dirs
    def get_measure_directories_array
      common_measures_instance = OpenStudio::CommonMeasures::Extension.new
      model_articulation_instance = OpenStudio::ModelArticulation::Extension.new
      ee_measures_instance = OpenStudio::EeMeasures::Extension.new
      bldg_sync_instance = BuildingSync::Extension.new
      return [common_measures_instance.measures_dir, model_articulation_instance.measures_dir, bldg_sync_instance.measures_dir, ee_measures_instance.measures_dir]
    end

    # inserts any measure.  traverses through the measures available in the included extensions
    # (common measures, model articulation, etc.) to find the lib/measures/[measure_dir] specified.
    # It is inserted at the relative position according to its type
    # @param measure_goal_type [String] one of: 'EnergyPlusMeasure', 'ReportingMeasure', or 'ModelMeasure'
    # @param measure_dir_name [String] the directory name for the measure, as it appears
    #   in any of the gems, i.e. openstudio-common-measures-gem/lib/measures/[measure_dir_name]
    # @param relative_position [Integer] the position where the measure should be inserted with respect to the measure_goal_type
    # @param args_hash [hash]
    def insert_measure_into_workflow(measure_goal_type, measure_dir_name, relative_position = 0, args_hash = {})
      successfully_added = false
      count = 0 # count for all of the measures, regardless of the type
      measure_type_count = 0 # count of measures specific to the measure_goal_type
      measure_type_found = false
      new_step = {}
      new_step['measure_dir_name'] = measure_dir_name
      new_step['arguments'] = args_hash
      if @workflow['steps'].empty?
        @workflow['steps'].insert(count, new_step)
        successfully_added = true
      else
        @workflow['steps'].each do |step|
          measure_dir_name = step['measure_dir_name']
          measure_type = get_measure_type(measure_dir_name)
          OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.WorkflowMaker.insert_measure_into_workflow', "measure: #{measure_dir_name} with type: #{measure_type} found")
          if measure_type == measure_goal_type
            measure_type_found = true
            if measure_type_count == relative_position
              # insert measure here
              OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.WorkflowMaker.insert_measure_into_workflow', "inserting measure with type (#{measure_goal_type}) at position #{count} and dir: #{measure_dir_name} and type: #{get_measure_type(measure_dir_name)}")
              puts "inserting measure with type (#{measure_goal_type}) at position #{count} and dir: #{measure_dir_name} and type: #{get_measure_type(measure_dir_name)}"
              @workflow['steps'].insert(count, new_step)
              successfully_added = true
              break
            end
            measure_type_count += 1
          elsif measure_type_found
            OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.WorkflowMaker.insert_measure_into_workflow', "inserting measure with type (#{measure_goal_type})at position #{count} and dir: #{measure_dir_name} and type: #{get_measure_type(measure_dir_name)}")
            puts "inserting measure with type (#{measure_goal_type}) at position #{count} and dir: #{measure_dir_name} and type: #{get_measure_type(measure_dir_name)}"
            @workflow['steps'].insert(count - 1, new_step)
            successfully_added = true
            break
          end
          count += 1
        end
      end
      if !successfully_added
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMakerPhaseZero.insert_measure_into_workflow', "CANNOT insert measure with type (#{measure_goal_type}) at position #{count} and dir: #{measure_dir_name} and type: #{get_measure_type(measure_dir_name)}")
      end
      return successfully_added
    end

    # gets the measure type of a measure given its directory - looking up the measure type in the measure.xml file
    # @param measure_dir_name [String] the directory name for the measure, as it appears
    #   in any of the gems, i.e. openstudio-common-measures-gem/lib/measures/[measure_dir_name]
    # @return [String]
    def get_measure_type(measure_dir_name)
      measure_type = nil
      get_measure_directories_array.each do |potential_measure_path|
        measure_dir_full_path = "#{potential_measure_path}/#{measure_dir_name}"
        if Dir.exist?(measure_dir_full_path)
          measure_xml_doc = nil
          File.open(measure_dir_full_path + '/measure.xml', 'r') do |file|
            measure_xml_doc = REXML::Document.new(file)
          end
          measure_xml_doc.elements.each('/measure/attributes/attribute') do |attribute|
            attribute_name = attribute.elements['name'].text
            if attribute_name == 'Measure Type'
              measure_type = attribute.elements['value'].text
            end
          end
        end
      end
      return measure_type
    end

    # Based on the MeasureIDs defined by the Scenario, configure the workflow provided
    # using the default measure arguments defined by the lib/buildingsync/makers/workflow_maker.json
    # @param base_workflow [Hash] a Hash map of the @workflow.  DO NOT  use @workflow directly, should be a deep clone
    # @param scenario [BuildingSync::Scenario] a Scenario object
    def configure_workflow_for_scenario(base_workflow, scenario)
      successful = true

      num_measures = 0
      scenario.get_measure_ids.each do |measure_id|
        measure = @facility.measures.find { |m| m.xget_id == measure_id }
        current_num_measure = num_measures

        sym_to_find = measure.xget_text('SystemCategoryAffected').to_s.to_sym
        categories_found = @workflow_maker_json.key?(sym_to_find)
        if categories_found
          @workflow_maker_json[sym_to_find].each do |category|
            m_name = measure.xget_name.to_sym

            # Where standardized measure names have not been adopted as enumerations
            # in the BuildingSync Schema, a <MeasureName>Other</MeasureName> is used
            # and the actual measure name added
            if m_name == :Other
              m_name = measure.xget_text("CustomMeasureName").to_sym
            end
            if !category[m_name].nil?
              measure_dir_name = category[m_name][:measure_dir_name]
              num_measures += 1
              category[m_name][:arguments].each do |argument|
                if !argument[:condition].nil? && !argument[:condition].empty?
                  set_argument_detail(base_workflow, argument, measure_dir_name, measure.xget_name)
                else
                  set_measure_argument(base_workflow, measure_dir_name, argument[:name], argument[:value])
                end
              end
            end
          end
        else
          OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.WorkflowMaker.configure_workflow_for_scenario', "Category: #{measure.xget_text('SystemCategoryAffected')} not found in workflow_maker.json.")
        end

        if current_num_measure == num_measures
          OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.WorkflowMaker.configure_workflow_for_scenario', "Measure ID: #{measure.xget_id} could not be processed!")
          successful = false
        end
      end

      # ensure that we didn't miss any measures by accident
      OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMaker.configure_workflow_for_scenario', "#{scenario.get_measure_ids.size} measures expected, #{num_measures} found,  measure_ids = #{scenario.get_measure_ids}") if num_measures != scenario.get_measure_ids.size
      return successful
    end

    # TODO: Update this as I believe no longer will work as expected, keys being searched for
    #       by the @facility_xml['key'] don't make sense.
    # set argument details, used when the condition
    # @param workflow [Hash] a hash of the openstudio workflow
    # @param argument [Hash]
    # @param measure_dir_name [String] the directory name for the measure, as it appears
    #   in any of the gems, i.e. openstudio-common-measures-gem/lib/measures/[measure_dir_name]
    # @param measure_name [String]
    def set_argument_detail(workflow, argument, measure_dir_name, measure_name)
      argument_name = ''
      argument_value = ''

      if measure_name == 'Add daylight controls' || measure_name == 'Replace HVAC system type to PZHP'
        if argument[:condition] == @facility_xml['bldg_type']
          argument_name = argument[:name]
          argument_value = "#{argument[:value]} #{@facility_xml['template']}"
        end
      elsif measure_name == 'Replace burner'
        if argument[:condition] == @facility_xml['system_type']
          argument_name = argument[:name]
          argument_value = argument[:value]
        end
      elsif measure_name == 'Replace boiler'
        if argument[:condition] == @facility_xml['system_type']
          argument_name = argument[:name]
          argument_value = argument[:value]
        end
      elsif measure_name == 'Replace package units'
        if argument[:condition] == @facility_xml['system_type']
          argument_name = argument[:name]
          argument_value = argument[:value]
        end
      elsif measure_name == 'Replace HVAC system type to VRF' || measure_name == 'Replace HVAC with GSHP and DOAS' || measure_name == 'Replace AC and heating units with ground coupled heat pump systems'
        if argument[:condition] == @facility_xml['bldg_type']
          argument_name = "#{argument[:name]} #{@facility_xml['template']}"
          argument_value = argument[:value]
        end
      else
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMakerPhaseZero.set_argument_detail', "measure dir name not found #{measure_name}.")
        puts "BuildingSync.WorkflowMakerPhaseZero.set_argument_detail: Measure dir name not found #{measure_name}."
      end

      set_measure_argument(workflow, measure_dir_name, argument_name, argument_value) if !argument_name.nil? && !argument_name.empty?
    end

    # write workflows for scenarios into osw files.  This includes:
    #   - Package of Measure Scenarios
    #   - Current Building Modeled (Baseline) Scenario
    # @param main_output_dir [String] main output path, not scenario specific. i.e. SR should be a subdirectory
    # @return [Boolean] whether writing of all the new workflows was successful
    def write_osws(main_output_dir, only_cb_modeled = false)
      # make sure paths exist
      FileUtils.mkdir_p(main_output_dir)

      if @facility.report.cb_modeled.nil?
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMaker.write_osws', 'OSW cannot be written since no current building modeled scenario is defined. One can be added after file import using the add_cb_modeled method')
        raise StandardError, 'BuildingSync.WorkflowMaker.write_osws: OSW cannot be written since no current building modeled scenario is defined. One can be added after file import using the add_cb_modeled method'
      end

      # Write a workflow for the current building modeled scenario
      cb_modeled_success = write_osw(main_output_dir, @facility.report.cb_modeled)

      if !cb_modeled_success
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMaker.write_osws', 'A workflow was not successfully written for the cb_modeled (Current Building Modeled) Scenario.')
        raise StandardError, 'BuildingSync.WorkflowMaker.write_osws: A workflow was not successfully written for the cb_modeled (Current Building Modeled) Scenario.'
      end

      number_successful = cb_modeled_success ? 1 : 0

      if not only_cb_modeled
        # write an osw for each Package Of Measures scenario
        @facility.report.poms.each do |scenario|
          successful = write_osw(main_output_dir, scenario)
          if successful
            number_successful += 1
          else
            OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMaker.write_osws', "Scenario ID: #{scenario.xget_id}. Unsuccessful write_osw")
          end
        end
      end


      # Compare the total number of potential successes to the number of actual successes
      if only_cb_modeled
        # In this case we should have only 1 success
        expected_successes = 1
        really_successful = number_successful == expected_successes
      else
        # In this case, all pom scenarios should be run + the cb_modeled scenario
        expected_successes = @facility.report.poms.size + 1
        really_successful = number_successful == expected_successes
      end

      if !really_successful
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMaker.write_osws', "Facility ID: #{@facility.xget_id}. Expected #{expected_successes}, Got #{number_successful} OSWs")
      end

      return really_successful
    end

    # Write an OSW for the provided scenario
    # @param main_output_dir [String] main output path, not scenario specific. i.e. SR should be a subdirectory
    # @param [BuildingSync::Scenario]
    # @return [Boolean] whether the writing was successful
    def write_osw(main_output_dir, scenario)
      successful = true
      # deep clone
      base_workflow = deep_copy_workflow

      # configure the workflow based on measures in this scenario
      begin
        # The workflow is updated by configure_workflow, put with pass by reference
        # we are ok to use it later without returning
        if !configure_workflow_for_scenario(base_workflow, scenario)
          successful = false
          OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMaker.write_osw', "Could not configure workflow for scenario #{scenario.xget_name}")
        else
          purge_skipped_from_workflow(base_workflow)
          scenario.set_workflow(base_workflow)
          scenario.write_osw(main_output_dir)
        end
      rescue StandardError => e
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMaker.write_osw', "Could not configure for scenario #{scenario.xget_name}. Error: #{e}")
        puts "Could not configure for scenario #{scenario.xget_name}"
        puts e.backtrace.join("\n\t")
        successful = false
      end
      return successful
    end

    # run osws - running all scenario simulations
    # @param only_cb_modeled [Boolean] used to only run the simulations for the cb_modeled (baseline) scenario
    # @param runner_options [hash]
    def run_osws(output_dir, only_cb_modeled = false, runner_options = {run_simulations: true, verbose: false, num_parallel: 7, max_to_run: Float::INFINITY})
      osw_files = []
      osw_sr_files = []
      if only_cb_modeled
        osw_files << "#{@facility.report.cb_modeled.get_osw_dir}/in.osw"
      else
        Dir.glob("#{output_dir}/**/in.osw") { |osw| osw_files << osw }
      end
      Dir.glob("#{output_dir}/SR/in.osw") { |osw| osw_sr_files << osw }

      runner = OpenStudio::Extension::Runner.new(dirname = Dir.pwd, bundle_without = [], options = runner_options)

      # This doesn't run the workflow defined by the Sizing Run
      return runner.run_osws(osw_files - osw_sr_files)
    end

    # Creates a deep copy of the @workflow be serializing and reloading with JSON
    # @return [Hash] a new workflow object
    def deep_copy_workflow
      return JSON.load(JSON.generate(@workflow))
    end

    # Removes unused measures from a workflow, where __SKIP__ == true
    # @param workflow [Hash] a hash of the openstudio workflow, typically after a deep
    # copy is made and the measures are configured for the specific scenario
    def purge_skipped_from_workflow(workflow)
      non_skipped = []
      if !workflow.nil? && !workflow['steps'].nil? && workflow.key?('steps')
        workflow['steps'].each do |step|
          if !step.nil? && step.key?('arguments') && !step['arguments'].nil?
            if step['arguments'].key?('__SKIP__') && step['arguments']['__SKIP__'] == false
              non_skipped << step
            end
          end
        end
        workflow['steps'] = non_skipped
      end
    end

    # get failed scenarios
    # @return [array]
    def get_failed_scenarios
      return @failed_scenarios
    end

    # cleanup larger files
    # @param osw_dir [String]
    def cleanup_larger_files(osw_dir)
      path = File.join(osw_dir, 'eplusout.sql')
      FileUtils.rm_f(path) if File.exist?(path)
      path = File.join(osw_dir, 'data_point.zip')
      FileUtils.rm_f(path) if File.exist?(path)
      path = File.join(osw_dir, 'eplusout.eso')
      FileUtils.rm_f(path) if File.exist?(path)
      Dir.glob(File.join(osw_dir, '*create_typical_building_from_model*')).each do |path|
        FileUtils.rm_rf(path) if File.exist?(path)
      end
      Dir.glob(File.join(osw_dir, '*create_typical_building_from_model*')).each do |path|
        FileUtils.rm_rf(path) if File.exist?(path)
      end
    end

    # gather results for all CB Modeled and POM Scenarios, including both annual and monthly results
    # - ResourceUse and AllResourceTotal elements are added to the Scenario as part of this process
    # - ResourceUse - holds consumption information about a specific resource / fuel (Electricity, Natural gas, etc.)
    # - AllResourceTotal - holds total site and source energy consumption information
    # @param year_val [Integer]
    # @param baseline_only [Boolean]
    # @return [Boolean]
    def gather_results(year_val = Date.today.year, baseline_only = false)
      # Gather results for the Current Building Modeled (Baseline) Scenario
      @facility.report.cb_modeled.os_gather_results(year_val)

      if !baseline_only
        # Gather results for the Package of Measures scenarios
        @facility.report.poms.each do |scenario|
          scenario.os_gather_results(year_val)
        end
      end
    end
  end
end
