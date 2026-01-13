# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************
require 'rexml/document'

require 'openstudio/common_measures'
require 'openstudio/model_articulation'
require 'openstudio/ee_measures'

require 'buildingsync/extension'
require 'buildingsync/constants'
require 'buildingsync/scenario'
require 'buildingsync/makers/workflow_maker_base'
require 'buildingsync/makers/osw_arg_populator'
require 'buildingsync/model_articulation/facility'

module BuildingSync
  # base class for objects that will configure workflows based on building sync files
  class WorkflowMaker < WorkflowMakerBase
    # initialize - load workflow json file and add necessary measure paths
    # @param doc [REXML::Document]
    # @param ns [String]
    def initialize(doc, ns, standard_to_be_used)
      super(doc, ns)

      @facility_xml = nil
      @facility = nil
      @standard_to_be_used = standard_to_be_used

      File.open(WORKFLOW_MAKER_JSON_FILE_PATH, 'r') do |file|
        @workflow_maker_json = JSON.parse(file.read, symbolize_names: true)
      end

      read_xml
    end

    def read_xml
      facility_xml_temp = @doc.get_elements("#{get_prefix}BuildingSync/#{get_prefix}Facilities/#{get_prefix}Facility")

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
      @facility = BuildingSync::Facility.new(@facility_xml, @ns, @standard_to_be_used)
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

    # get scenario elements
    # @return [Array<BuildingSync::Scenario>]
    def get_scenarios
      return @facility.report.scenarios
    end

    # writes the parameters determined during processing back to the BldgSync XML file
    def prepare_final_xml
      @facility.prepare_final_xml
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

        sym_to_find = measure.xget_text('SystemCategoryAffected')
        if sym_to_find.nil? || sym_to_find.empty?
          OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.WorkflowMaker.configure_workflow_for_scenario', "Measure ID: #{measure.xget_id} does not define a SystemCategoryAffected.")
          successful = false
        else
          sym_to_find = sym_to_find.to_s.to_sym
        end

        # 'Other HVAC' or 'Cooling System' as examples
        categories_found = @workflow_maker_json.key?(sym_to_find)
        if categories_found
          m_name = measure.xget_name

          if m_name.nil? || m_name.empty?
            OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.WorkflowMaker.configure_workflow_for_scenario', "Measure ID: #{measure.xget_id} does not have a MeasureName defined.")
            successful = false
          else
            m_name = m_name.to_sym
          end

          # Where standardized measure names have not been adopted as enumerations
          # in the BuildingSync Schema, a <MeasureName>Other</MeasureName> is used
          # and the actual measure name added
          if m_name == :Other
            m_name = measure.xget_text('CustomMeasureName')
            if m_name.nil? || m_name.empty?
              OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.WorkflowMaker.configure_workflow_for_scenario', "Measure ID: #{measure.xget_id} has a MeasureName of 'Other' but does not have a CustomMeasureName defined.")
              successful = false
            else
              m_name = m_name.to_sym
            end
          end
          measure_found = false
          @workflow_maker_json[sym_to_find].each do |category|
            # m_name is, for example: 'Replace HVAC system type to VRF'

            if !category[m_name].nil?
              measure_found = true
              measure_dir_name = category[m_name][:measure_dir_name]
              num_measures += 1
              category[m_name][:arguments].each do |argument|
                # Certain arguments are only applied under specific conditions
                #
                if !argument[:condition].nil? && !argument[:condition].empty?
                  set_argument_detail(base_workflow, argument, measure_dir_name, m_name.to_s)
                else
                  set_measure_argument(base_workflow, measure_dir_name, argument[:name], argument[:value])
                end
              end
            end
          end
          if !measure_found
            OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.WorkflowMaker.configure_workflow_for_scenario', "Could not find measure '#{m_name}' under category #{sym_to_find} in workflow_maker.json.")
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
      OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMaker.configure_workflow_for_scenario', "#{scenario.get_measure_ids.size} measures expected, #{num_measures} resolved,  expected measure_ids = #{scenario.get_measure_ids}") if num_measures != scenario.get_measure_ids.size
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
        # For these measures, the condition is based on the standards building type determined
        if argument[:condition] == @facility.site.get_building_type
          argument_name = argument[:name]

          # This is a really terrible way to do this.  It fails
          # in many scenarios
          argument_value = "#{argument[:value]} #{@facility.site.get_standard_template}"
        end
      elsif measure_name == 'Replace burner'
        if argument[:condition] == @facility.site.get_system_type
          argument_name = argument[:name]
          argument_value = argument[:value]
        end
      elsif measure_name == 'Replace boiler'
        if argument[:condition] == @facility.site.get_system_type
          argument_name = argument[:name]
          argument_value = argument[:value]
        end
      elsif measure_name == 'Replace package units'
        if argument[:condition] == @facility.site.get_system_type
          argument_name = argument[:name]
          argument_value = argument[:value]
        end
      elsif measure_name == 'Replace HVAC system type to VRF' || measure_name == 'Replace HVAC with GSHP and DOAS' || measure_name == 'Replace AC and heating units with ground coupled heat pump systems'
        if argument[:condition] == @facility.site.get_building_type
          argument_name = (argument[:name]).to_s
          argument_value = argument[:value]
        end
      else
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMaker.set_argument_detail', "measure dir name not found #{measure_name}.")
        puts "BuildingSync.WorkflowMaker.set_argument_detail: Measure dir name not found #{measure_name}."
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

      if !only_cb_modeled
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

    def assert_baseline_osw_exists(baseline_osw_path)
      if !File.file?(baseline_osw_path)
        error_message = (
          "this function required #{baseline_owm_path}, which does not exist. "\
          "Create #{baseline_owm_path} with `write_baseline_osw` and try again."
        )
        OpenStudio.logFree(OpenStudio::Error, "BuildingSync.WorkflowMaker.assert_baseline_osw_exists", error_message)
        raise StandardError, "BuildingSync.WorkflowMaker.assert_baseline_osw_exists: #{error_message}"
      end
    end

    def assert_baseline_osm_exists(baseline_osm_path)
      if !File.file?(baseline_osm_path)
        error_message = (
          "this function required #{baseline_osm_path}, which does not exist. "\
          "Create #{baseline_osm_path} with `run_baseline_osw` and try again."
        )
        OpenStudio.logFree(OpenStudio::Error, "BuildingSync.WorkflowMaker.assert_baseline_osm_exists", error_message)
        raise StandardError, "BuildingSync.WorkflowMaker.assert_baseline_osm_exists: #{error_message}"
      end
    end

    def write_baseline_osw(model_dir, epw_file_path)
      # start with an empty baseline workflow
      file = File.read(EMPTY_BASELINE_OSW_PATH)
      baseline_osw = JSON.parse(file, symbolize_names: true)

      # parse the facility
      @facility.set_all
      @facility.set_standard_template
      @facility.set_weather_and_climate_zone(epw_file_path)

      # populate the baseline measures
      OSWARGPopulator::populate_set_run_period_args(baseline_osw, @facility)
      OSWARGPopulator::populate_change_building_location_args(baseline_osw, @facility)

      OSWARGPopulator::populate_create_bar_from_building_type_ratios_args(baseline_osw, @facility)
      OSWARGPopulator::populate_create_typical_building_from_model_args(baseline_osw, @facility)

      OSWARGPopulator::populate_set_lighting_loads_by_LPD_args(baseline_osw, @facility)
      OSWARGPopulator::populate_set_electric_equipment_loads_by_epd_args(baseline_osw, @facility)
      OSWARGPopulator::populate_openstudio_results_args(baseline_osw, @facility)

      # write to file
      workflow_dir = File.join(model_dir, 'baseline')
      FileUtils.mkdir_p(workflow_dir)
      File.open(File.join(workflow_dir, 'in.osw'), 'w') do |file|
        file << JSON.pretty_generate(baseline_osw)
      end
    end

    def run_baseline_osw(output_dir, runner_options = { run_simulations: true, verbose: false, num_parallel: 7, max_to_run: Float::INFINITY })
      # assert we have a baseline osm
      baseline_osw_path = "#{output_dir}/baseline/in.osw"
      assert_baseline_osw_exists(baseline_osw_path)

      # run the baseline osm
      runner = OpenStudio::Extension::Runner.new(dirname = Dir.pwd, bundle_without = [], options = runner_options)
      return runner.run_osws([baseline_osw_path])
    end

    def write_report_osws(output_dir)
      # assert we have a baseline osm
      baseline_owm_path = "#{output_dir}/baseline/in.osm"
      assert_baseline_osm_exists(baseline_owm_path)

      # write a osw for each scenario in the report
      number_successful = 0
      @facility.report.poms.each do |scenario|
        successful = write_osw(output_dir, scenario, baseline_owm_path)
        number_successful += successful.to_i
      end

      # Log it
      OpenStudio.logFree(
        OpenStudio::Error,
        'BuildingSync.WorkflowMaker.write_report_osws',
        "Facility ID: #{@facility.xget_id}. Expected #{@facility.report.poms.length()}, Got #{number_successful} OSWs"
      )
    end

    def run_report_osws(output_dir, runner_options = { run_simulations: true, verbose: true, num_parallel: 7, max_to_run: Float::INFINITY })
      # get the all the osws but for the baseline
      report_osws = Dir.glob("#{output_dir}/**/in.osw")
      report_osws = report_osws - ["#{output_dir}/baseline/**/in.osw"]

      # run them
      runner = OpenStudio::Extension::Runner.new(dirname = Dir.pwd, bundle_without = [], options = runner_options)
      return runner.run_osws(report_osws)
    end


    # Write an OSW for the provided scenario
    # @param main_output_dir [String] main output path, not scenario specific. i.e. SR should be a subdirectory
    # @param [BuildingSync::Scenario]
    # @return [Boolean] whether the writing was successful
    def write_osw(main_output_dir, scenario, baseline_osm_path=nil)
      successful = true
      # deep clone
      base_workflow = deep_copy_workflow

      if baseline_osm_path
        base_workflow["seed_file"] = baseline_osm_path
      end

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
    def run_osws(output_dir, only_cb_modeled = false, runner_options = { run_simulations: true, verbose: false, num_parallel: 7, max_to_run: Float::INFINITY })
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

    # Removes unused measures from a workflow, where __SKIP__ == true
    # @param workflow [Hash] a hash of the openstudio workflow, typically after a deep
    # copy is made and the measures are configured for the specific scenario
    # KAF: reworked to only delete measures with an explicit __SKIP__ == true
    # (sometimes measure don't have a skip at all, assume we want to keep those)
    def purge_skipped_from_workflow(workflow)
      non_skipped = []
      if !workflow.nil? && !workflow['steps'].nil? && workflow.key?('steps')
        workflow['steps'].each do |step|
          if !step.nil? && step.key?('arguments')
            if step['arguments'].nil?
              # no arguments, keep anyway
              non_skipped << step
            elsif step['arguments'].key?('__SKIP__') && step['arguments']['__SKIP__'] == false
              # skip is set to false, keep
              non_skipped << step
            elsif !step['arguments'].key?('__SKIP__')
              # no "SKIP" argument, keep anyway
              non_skipped << step
            end
          end
        end
        workflow['steps'] = non_skipped
      end
    end

    # get failed scenarios
    # @return [Array<BuildingSync::Scenario>]
    def get_failed_scenarios
      failed = []
      @facility.report.scenarios.each do |scenario|
        failed << scenario if !scenario.simulation_success?
      end
      return failed
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
