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
require_relative 'workflow_maker_base'
require 'openstudio/common_measures'
require 'openstudio/model_articulation'
require 'openstudio/ee_measures'
require_relative '../../../lib/buildingsync/extension'

module BuildingSync
  # base class for objects that will configure workflows based on building sync files
  class WorkflowMaker < WorkflowMakerBase

    # initialize - load workflow json file and add necessary measure paths
    # @param doc [REXML::Document]
    # @param ns [String]
    def initialize(doc, ns)
      super

      # load the workflow
      @workflow = nil
      @facility = nil

      # log failed scenarios
      @failed_scenarios = []
      @scenarios = []

      # select base osw for standalone, small office, medium office
      base_osw = 'phase_zero_base.osw'

      workflow_path = File.join(File.dirname(__FILE__), base_osw)
      raise "File '#{workflow_path}' does not exist" unless File.exist?(workflow_path)

      File.open(workflow_path, 'r') do |file|
        @workflow = JSON.parse(file.read)
        set_measure_paths(@workflow, get_measure_directories_array)
      end
      check_if_measures_exist
    end

    # iterate over the current measure list in the workflow and check if they are available at the referenced measure directories
    # @return [Boolean]
    def check_if_measures_exist
      all_measures_found = true
      @workflow['steps'].each do |step|
        measure_is_valid = false
        measure_dir_name = step['measure_dir_name']
        get_measure_directories_array.each do |potential_measure_path|
          measure_dir_full_path = "#{potential_measure_path}/#{measure_dir_name}"
          if Dir.exist?(measure_dir_full_path)
            measure_is_valid = true
            puts "measure found in: #{measure_dir_full_path}/"
            break
          end
        end
        if !measure_is_valid
          all_measures_found = false
          OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMaker.check_if_measures_exist', "CANNOT find measure with name (#{measure_dir_name}) in any of the measure paths  ")
        end
      end
      return all_measures_found
    end

    # gets all available measures across all measure directories
    # @return [hash]
    def get_list_of_available_measures
      list_of_measures = {}
      get_measure_directories_array.each do |potential_measure_path|
        Dir.chdir(potential_measure_path) do
          list_of_measures[potential_measure_path] = Dir.glob('*').select{ |f| File.directory? f }
        end
      end
      return list_of_measures
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

    # insert an EnergyPlus measure to the list of existing measures - by default (item = 0) it gets added as first EnergyPlus measure
    # @param measure_dir [String]
    # @param item [Integer]
    # @param args_hash [hash]
    def insert_energyplus_measure(measure_dir, item = 0, args_hash = {})
      insert_measure('EnergyPlusMeasure', measure_dir, item, args_hash)
    end

    # insert a Reporting measure to the list of existing measures - by default (item = 0) it gets added as first Reporting measure
    # @param measure_dir [String]
    # @param item [Integer]
    # @param args_hash [hash]
    def insert_reporting_measure(measure_dir, item = 0, args_hash = {})
      insert_measure('ReportingMeasure', measure_dir, item, args_hash)
    end

    # insert a Model measure to the list of existing measures - by default (item = 0) it gets added as first Model measure
    # @param measure_dir [String]
    # @param item [Integer]
    # @param args_hash [hash]
    def insert_model_measure(measure_dir, item = 0, args_hash = {})
      insert_measure('ModelMeasure', measure_dir, item, args_hash)
    end

    # inserts any measure
    # @param measure_goal_type [String]
    # @param measure_dir [String]
    # @param item [Integer]
    # @param args_hash [hash]
    def insert_measure(measure_goal_type, measure_dir, item = 0, args_hash = {})
      successfully_added = false
      count = 0
      measure_type_count = 0
      measure_type_found = false
      if @workflow['steps'].empty?
        new_step = {}
        new_step['measure_dir_name'] = measure_dir
        new_step['arguments'] = args_hash
        @workflow['steps'].insert(count, new_step)
        successfully_added = true
      else
        @workflow['steps'].each do |step|
          measure_dir_name = step['measure_dir_name']
          measure_type = get_measure_type(measure_dir_name)
          OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.WorkflowMakerPhaseZero.insert_measure', "measure: #{measure_dir_name} with type: #{measure_type} found")
          if measure_type == measure_goal_type
            measure_type_found = true
            if measure_type_count == item
              # insert measure here
              OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.WorkflowMakerPhaseZero.insert_measure', "inserting measure with type (#{measure_goal_type}) at position #{count} and dir: #{measure_dir} and type: #{get_measure_type(measure_dir)}")
              puts "inserting measure with type (#{measure_goal_type}) at position #{count} and dir: #{measure_dir} and type: #{get_measure_type(measure_dir)}"
              new_step = {}
              new_step['measure_dir_name'] = measure_dir
              new_step['arguments'] = args_hash
              @workflow['steps'].insert(count, new_step)
              successfully_added = true
              break
            end
            measure_type_count += 1
          elsif measure_type_found
            OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.WorkflowMakerPhaseZero.insert_measure', "inserting measure with type (#{measure_goal_type})at position #{count} and dir: #{measure_dir} and type: #{get_measure_type(measure_dir)}")
            puts "inserting measure with type (#{measure_goal_type})at position #{count} and dir: #{measure_dir} and type: #{get_measure_type(measure_dir)}"
            new_step = {}
            new_step['measure_dir_name'] = measure_dir
            @workflow['steps'].insert(count - 1, new_step)
            successfully_added = true
            break
          end
          count += 1
        end
      end
      if !successfully_added
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMakerPhaseZero.insert_measure', "CANNOT insert measure with type (#{measure_goal_type}) at position #{count} and dir: #{measure_dir} and type: #{get_measure_type(measure_dir)}")
      end
      return successfully_added
    end

    # gets the measure type of a measure given its directory - looking up the measure type in the measure.xml file
    # @param measure_dir [String]
    # @return [String]
    def get_measure_type(measure_dir)
      measure_type = nil
      get_measure_directories_array.each do |potential_measure_path|
        measure_dir_full_path = "#{potential_measure_path}/#{measure_dir}"
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

    # get the current workflow
    # @return [hash]
    def get_workflow
      return @workflow
    end

    # get the name of a measure within the xml structure
    # @param measure_category [String]
    # @param measure [REXML:Element]
    # @return [String]
    def get_measure_name(measure_category, measure)
      measure_name = ''
      if measure_category == 'Lighting'
        measure_name = measure.elements["#{@ns}:TechnologyCategories/#{@ns}:TechnologyCategory/#{@ns}:LightingImprovements/#{@ns}:MeasureName"].text
      elsif measure_category == 'Plug Load'
        measure_name = measure.elements["#{@ns}:TechnologyCategories/#{@ns}:TechnologyCategory/#{@ns}:PlugLoadReductions/#{@ns}:MeasureName"].text
      elsif measure_category == 'Refrigeration'
        measure_name = measure.elements["#{@ns}:TechnologyCategories/#{@ns}:TechnologyCategory/#{@ns}:Refrigeration/#{@ns}:MeasureName"].text
      elsif measure_category == 'Wall' || measure_category == 'Roof' || measure_category == 'Ceiling' || measure_category == 'Fenestration'
        measure_name = measure.elements["#{@ns}:TechnologyCategories/#{@ns}:TechnologyCategory/#{@ns}:BuildingEnvelopeModifications/#{@ns}:MeasureName"].text
      elsif measure_category == 'Cooling System' || measure_category == 'General Controls and Operations' || measure_category == 'Heat Recovery'
        measure_name = measure.elements["#{@ns}:TechnologyCategories/#{@ns}:TechnologyCategory/#{@ns}:OtherHVAC/#{@ns}:MeasureName"].text
      elsif measure_category == 'Heating System'
        if defined? measure.elements["#{@ns}:TechnologyCategories/#{@ns}:TechnologyCategory/#{@ns}:OtherHVAC/#{@ns}:MeasureName"].text
          measure_name = measure.elements["#{@ns}:TechnologyCategories/#{@ns}:TechnologyCategory/#{@ns}:OtherHVAC/#{@ns}:MeasureName"].text
        end
        if defined? measure.elements["#{@ns}:TechnologyCategories/#{@ns}:TechnologyCategory/#{@ns}:BoilerPlantImprovements/#{@ns}:MeasureName"].text
          measure_name = measure.elements["#{@ns}:TechnologyCategories/#{@ns}:TechnologyCategory/#{@ns}:BoilerPlantImprovements/#{@ns}:MeasureName"].text
        end
      elsif measure_category == 'Other HVAC'
        measure_name = measure.elements["#{@ns}:TechnologyCategories/#{@ns}:TechnologyCategory/#{@ns}:*/#{@ns}:MeasureName"].text

        # DLM: somme measures don't have a direct BuildingSync equivalent, use UserDefinedField 'OpenStudioMeasureName' for now
        if measure_name == 'Other'
          measure.elements.each("#{@ns}:UserDefinedFields/#{@ns}:UserDefinedField") do |user_defined_field|
            field_name = user_defined_field.elements["#{@ns}:FieldName"].text
            if field_name == 'OpenStudioMeasureName'
              measure_name = user_defined_field.elements["#{@ns}:FieldValue"].text
            end
          end
        end
      elsif measure_category == 'Fan'
        measure_name = measure.elements["#{@ns}:TechnologyCategories/#{@ns}:TechnologyCategory/#{@ns}:OtherElectricMotorsAndDrives/#{@ns}:MeasureName"].text
      elsif measure_category == 'Air Distribution'
        measure_name = measure.elements["#{@ns}:TechnologyCategories/#{@ns}:TechnologyCategory/#{@ns}:*/#{@ns}:MeasureName"].text
      elsif measure_category == 'Domestic Hot Water'
        measure_name = measure.elements["#{@ns}:TechnologyCategories/#{@ns}:TechnologyCategory/#{@ns}:ChilledWaterHotWaterAndSteamDistributionSystems/#{@ns}:MeasureName"].text
      elsif measure_category == 'Water Use'
        measure_name = measure.elements["#{@ns}:TechnologyCategories/#{@ns}:TechnologyCategory/#{@ns}:WaterAndSewerConservationSystems/#{@ns}:MeasureName"].text

      else
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMakerPhaseZero.set_argument_detail', "measure dir name not found #{measure_dir_name}.")
      end
      return measure_name
    end

    # set argument details
    # @param osw [String]
    # @param argument [hash]
    # @param measure_dir_name [String]
    # @param measure_name [String]
    def set_argument_detail(osw, argument, measure_dir_name, measure_name)
      argument_name = ''
      argument_value = ''

      if measure_name == 'Add daylight controls' || measure_name == 'Replace HVAC system type to PZHP'
        if argument[:condition] == @facility['bldg_type']
          argument_name = argument[:name]
          argument_value = "#{argument[:value]} #{@facility['template']}"
        end
      elsif measure_name == 'Replace burner'
        if argument[:condition] == @facility['system_type']
          argument_name = argument[:name]
          argument_value = argument[:value]
        end
      elsif measure_name == 'Replace boiler'
        if argument[:condition] == @facility['system_type']
          argument_name = argument[:name]
          argument_value = argument[:value]
        end
      elsif measure_name == 'Replace package units'
        if argument[:condition] == @facility['system_type']
          argument_name = argument[:name]
          argument_value = argument[:value]
        end
      elsif measure_name == 'Replace HVAC system type to VRF' || measure_name == 'Replace HVAC with GSHP and DOAS' || measure_name == 'Replace AC and heating units with ground coupled heat pump systems'
        if argument[:condition] == @facility['bldg_type']
          argument_name = "#{argument[:name]} #{@facility['template']}"
          argument_value = argument[:value]
        end
      else
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMakerPhaseZero.set_argument_detail', "measure dir name not found #{measure_name}.")
        puts "BuildingSync.WorkflowMakerPhaseZero.set_argument_detail: Measure dir name not found #{measure_name}."
      end

      set_measure_argument(osw, measure_dir_name, argument_name, argument_value) if !argument_name.nil? && !argument_name.empty?
    end

    # configure for scenario
    # @param osw [String]
    # @param scenario [REXML:Element]
    def configure_for_scenario(osw, scenario)
      successful = true
      measure_ids = []
      scenario.elements.each("#{@ns}:ScenarioType/#{@ns}:PackageOfMeasures/#{@ns}:MeasureIDs/#{@ns}:MeasureID") do |measure_id|
        measure_ids << measure_id.attributes['IDref']
      end

      num_measures = 0
      measure_ids.each do |measure_id|
        @doc.elements.each("//#{@ns}:Measure[@ID='#{measure_id}']") do |measure|
          measure_category = measure.elements["#{@ns}:SystemCategoryAffected"].text

          current_num_measure = num_measures

          measure_name = get_measure_name(measure_category, measure)

          json_file_path = File.expand_path('workflow_maker.json', File.dirname(__FILE__))
          json = eval(File.read(json_file_path))

          json[:"#{measure_category}"].each do |meas_name|
            if !meas_name[:"#{measure_name}"].nil?
              measure_dir_name = meas_name[:"#{measure_name}"][:measure_dir_name]
              num_measures += 1
              meas_name[:"#{measure_name}"][:arguments].each do |argument|
                if !argument[:condition].nil? && !argument[:condition].empty?
                  set_argument_detail(osw, argument, measure_dir_name, measure_name)
                else
                  set_measure_argument(osw, measure_dir_name, argument[:name], argument[:value])
                end
              end
            end
          end

          if current_num_measure == num_measures
            measure_name = measure.elements["#{@ns}:TechnologyCategories/#{@ns}:TechnologyCategory/#{@ns}:*/#{@ns}:MeasureName"].text
            measure_long_description = measure.elements["#{@ns}:LongDescription"].text
            OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.WorkflowMaker.configure_for_scenario', "Measure with name: #{measure_name} and Description: #{measure_long_description} could not be processed!")
            successful = false
          end
        end
      end

      # ensure that we didn't miss any measures by accident
      OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMaker.configure_for_scenario', "#{measure_ids.size} measures expected, #{num_measures} found,  measure_ids = #{measure_ids}") if num_measures != measure_ids.size
      return successful
    end

    # get scenario elements
    # @return [REXML:Element]
    def get_scenario_elements
      if @scenarios.empty?
        get_scenarios.elements.each("#{@ns}:Scenario") do |scenario|
          if scenario.is_a? REXML::Element
            @scenarios.push(scenario)
          end
        end
        if @scenarios.empty?
          puts 'No scenarios found in your BuildingSync XML file!'
        end
      end
      return @scenarios
    end

    # get scenarios
    # @return [REXML:Element]
    def get_scenarios
      scenarios = @doc.elements["#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility/#{@ns}:Reports/#{@ns}:Report/#{@ns}:Scenarios"]
      if scenarios.nil?
        scenarios = @doc.elements["#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility/#{@ns}:Report/#{@ns}:Scenarios"]
      end
      return scenarios
    end

    # check if the scenario is a baseline scenario
    # @param scenario [REXML:Element]
    # @return [Boolean]
    def scenario_is_baseline_scenario(scenario)
      # first we check if we find the new scenario type definition
      return true if scenario.elements["#{@ns}:ScenarioType/#{@ns}:CurrentBuilding/#{@ns}:CalculationMethod/#{@ns}:Modeled"]
      return false
    end

    # check if the scenario is a measured scenario
    # @param scenario [REXML:Element]
    # @return [Boolean]
    def scenario_is_measured_scenario(scenario)
      # first we check if we find the new scenario type definition
      return true if scenario.elements["#{@ns}:ScenarioType/#{@ns}:CurrentBuilding/#{@ns}:CalculationMethod/#{@ns}:Measured"]
      return false
    end

    # write workflows for all scenarios into osw files
    # @param facility [REXML:Element]
    # @param dir [String]
    # @return [Boolean]
    def write_osws(facility, dir)
      super

      successful = true
      @facility = facility
      scenarios = get_scenario_elements
      # ensure there is a 'Baseline' scenario
      puts 'Looking for the baseline scenario ...'
      found_baseline = false
      scenarios.each do |scenario|
        scenario_name = scenario.elements["#{@ns}:ScenarioName"].text
        puts "scenario with name #{scenario_name} found"
        if scenario_is_baseline_scenario(scenario)
          found_baseline = true
          break
        end
      end

      if !found_baseline
        if !scenarios.nil?
          scenario_element = REXML::Element.new("#{@ns}:Scenario")
          scenario_element.attributes['ID'] = BASELINE

          scenario_name_element = REXML::Element.new("#{@ns}:ScenarioName")
          scenario_name_element.text = BASELINE
          scenario_element.add_element(scenario_name_element)

          # adding XML elements for the new way to define a baseline scenario
          current_building = REXML::Element.new("#{@ns}:CurrentBuilding")
          calculation_method = REXML::Element.new("#{@ns}:CalculationMethod")
          modeled = REXML::Element.new("#{@ns}:Modeled")
          calculation_method.add_element(modeled)
          current_building.add_element(calculation_method)
          scenario_element.add_element(current_building)
          get_scenarios.add_element(scenario_element)
          puts '.....adding a new baseline scenario'
        end
      end

      found_baseline = false
      scenarios.each do |scenario|
        if scenario_is_baseline_scenario(scenario)
          found_baseline = true
          break
        end
      end

      if !found_baseline
        puts 'Cannot find or create Baseline scenario'
        exit
      end

      # write an osw for each scenario
      scenarios.each do |scenario|
        # get information about the scenario
        scenario_name = scenario.elements["#{@ns}:ScenarioName"].text
        next if scenario_is_measured_scenario(scenario)

        # deep clone
        osw = JSON.load(JSON.generate(@workflow))

        # configure the workflow based on measures in this scenario
        begin
          successful = false if !configure_for_scenario(osw, scenario)

          # dir for the osw
          osw_dir = get_osw_dir(dir, scenario)
          FileUtils.mkdir_p(osw_dir)

          # write the osw
          path = File.join(osw_dir, 'in.osw')
          File.open(path, 'w') do |file|
            file << JSON.generate(osw)
          end
        rescue StandardError => e
          OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMaker.write_osws', "Could not configure for scenario #{scenario_name}")
          puts "Could not configure for scenario #{scenario_name}"
          puts e.backtrace.join("\n\t")
        end
      end
      return successful
    end

    # get measure result
    # @param result [hash]
    # @param measure_dir_name [String]
    # @param result_name [String]
    # @return [Float]
    def get_measure_result(result, measure_dir_name, result_name)
      result[:steps].each do |step|
        if step[:measure_dir_name] == measure_dir_name
          if step[:result] && step[:result][:step_values]
            step[:result][:step_values].each do |step_value|
              if step_value[:name] == result_name
                return step_value[:value]
              end
            end
          end
        end
      end
      OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMaker.get_measure_result', "Did not find any steps for measure #{measure_dir_name} for result #{result_name}")
      return nil
    end

    # get failed scenarios
    # @return [array]
    def get_failed_scenarios
      return @failed_scenarios
    end

    # save BuildingSync xml
    # @param filename [String]
    def save_xml(filename)
      # first we make sure all directories exist
      FileUtils.mkdir_p(File.dirname(filename))
      # then we can save the file
      File.open(filename, 'w') do |file|
        @doc.write(file)
      end
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

    # get results for all scenarios
    # @param dir [String]
    # @param baseline_only [Boolean]
    # @return [array] of results and monthly results in hashes
    def get_result_for_scenarios(dir, baseline_only)
      results = {}
      monthly_results = {}
      get_scenario_elements.each do |scenario|
        # get information about the scenario
        if scenario.elements["#{@ns}:ScenarioName"]
          scenario_name = scenario.elements["#{@ns}:ScenarioName"].text
        else
          scenario_name = scenario.attributes['ID']
        end
        next if scenario_is_measured_scenario(scenario)
        next if !scenario_is_baseline_scenario(scenario) && baseline_only

        # dir for the osw
        osw_dir = get_osw_dir(dir, scenario)
        # cleanup large files
        cleanup_larger_files(osw_dir)

        # find the osw
        path = File.join(osw_dir, 'out.osw')
        if !File.exist?(path)
          puts "Cannot load results for scenario #{scenario_name}, because the osw files does not exist #{path}"
          next
        end
        File.open(path, 'r') do |file|
          results[scenario_name] = JSON.parse(file.read, symbolize_names: true)
        end
        # open results.json to get monthly timeseries
        # just grabbed openstudio_results
        path2 = File.join(osw_dir, 'results.json')
        File.open(path2, 'r') do |file|
          temp_res = JSON.parse(file.read, symbolize_names: true)
          monthly_results[scenario_name] = temp_res[:OpenStudioResults]
        end
      end
      return results, monthly_results
    end

    # delete resource element
    # @param scenario [REXML::Element]
    # @param package_of_measures [REXML::Element]
    def delete_resource_element(scenario, package_of_measures)
      if package_of_measures
        package_of_measures.elements.delete("#{@ns}:AnnualSavingsSiteEnergy")
        package_of_measures.elements.delete("#{@ns}:AnnualSavingsCost")
        package_of_measures.elements.delete("#{@ns}:CalculationMethod")
        package_of_measures.elements.delete("#{@ns}AnnualSavingsByFuels")
      end
      scenario.elements.delete("#{@ns}AllResourceTotals")
      scenario.elements.delete("#{@ns}RsourceUses")
      scenario.elements.delete("#{@ns}AnnualSavingsByFuels")
    end

    # get package of measures
    # @param scenario [REXML::Element]
    # @return [REXML::Element]
    def get_package_of_measures(scenario)
      return scenario.elements["#{@ns}:ScenarioType"].elements["#{@ns}:PackageOfMeasures"]
    end

    # get current building
    # @param scenario [REXML::Element]
    # @return [REXML::Element]
    def get_current_building(scenario)
      return scenario.elements["#{@ns}:ScenarioType"].elements["#{@ns}:CurrentBuilding"]
    end

    # prepare package of measures or current building
    # @param scenario [REXML::Element]
    # @return [REXML::Element]
    def prepare_package_of_measures_or_current_building(scenario)
      package_of_measures_or_current_building = get_package_of_measures(scenario)
      if package_of_measures_or_current_building.nil?
        package_of_measures_or_current_building = get_current_building(scenario)
      end
      # delete previous results
      delete_resource_element(scenario, package_of_measures_or_current_building)

      # preserve existing user defined fields if they exist
      # KAF: there should no longer be any UDFs
      user_defined_fields = scenario.elements["#{@ns}:UserDefinedFields"]
      if !user_defined_fields.nil?
        # delete previous results (if using an old schema)
        to_remove = []
        user_defined_fields.elements.each("#{@ns}:UserDefinedField") do |user_defined_field|
          name_element = user_defined_field.elements["#{@ns}:FieldName"]
          if name_element.nil?
            to_remove << user_defined_field
          elsif /OpenStudio/.match(name_element.text)
            to_remove << user_defined_field
          end
        end

        to_remove.each do |element|
          user_defined_fields.elements.delete(element)
        end
      end
      return package_of_measures_or_current_building
    end

    # add calculation method element
    # @param result [hash]
    # @return [REXML::Element]
    def add_calc_method_element(result)
      # this is now in PackageOfMeasures.CalculationMethod.Modeled.SimulationCompletionStatus
      # options are: Not Started, Started, Finished, Failed, Unknown
      calc_method = REXML::Element.new("#{@ns}:CalculationMethod")
      modeled = REXML::Element.new("#{@ns}:Modeled")
      software_program_used = REXML::Element.new("#{@ns}:SoftwareProgramUsed")
      software_program_used.text = 'OpenStudio'
      modeled.add_element(software_program_used)
      software_program_version = REXML::Element.new("#{@ns}:SoftwareProgramVersion")
      software_program_version.text = OpenStudio.openStudioLongVersion.to_s
      modeled.add_element(software_program_version)
      weather_data_type = REXML::Element.new("#{@ns}:WeatherDataType")
      weather_data_type.text = 'TMY3'
      modeled.add_element(weather_data_type)
      sim_completion_status = REXML::Element.new("#{@ns}:SimulationCompletionStatus")
      sim_completion_status.text = result[:completed_status] == 'Success' ? 'Finished' : 'Failed'
      modeled.add_element(sim_completion_status)
      calc_method.add_element(modeled)
      return calc_method
    end

    # add results to xml file and calculate annual savings
    # @param package_of_measures [REXML::Element]
    # @param variables [hash]
    # @return [REXML::Element]
    def calculate_annual_savings_value(package_of_measures, variables)
      if(variables.key?('total_site_energy_savings_mmbtu'))
        annual_savings_site_energy = REXML::Element.new("#{@ns}:AnnualSavingsSiteEnergy")
        annual_savings_site_energy.text = variables['total_site_energy_savings_mmbtu']
        package_of_measures.add_element(annual_savings_site_energy)
      else
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMaker.calculate_annual_savings_value', "Cannot add 'total site energy savings' variable to the BldgSync file since it is missing.")
      end

      if(variables.key?('total_source_energy_savings_mmbtu'))
        annual_savings_source_energy = REXML::Element.new("#{@ns}:AnnualSavingsSourceEnergy")
        annual_savings_source_energy.text = variables['total_source_energy_savings_mmbtu']
        package_of_measures.add_element(annual_savings_source_energy)
      else
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMaker.calculate_annual_savings_value', "Cannot add 'total source energy savings' variable to the BldgSync file since it is missing.")
      end

      if(variables.key?('total_energy_cost_savings'))
        annual_savings_energy_cost = REXML::Element.new("#{@ns}:AnnualSavingsCost")
        annual_savings_energy_cost.text = variables['total_energy_cost_savings'].to_i # BuildingSync wants an integer, might be a BuildingSync bug
        package_of_measures.add_element(annual_savings_energy_cost)
      else
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMaker.calculate_annual_savings_value', "Cannot add 'total energy cost savings' variable to the BldgSync file since it is missing.")
      end

      # KAF: adding annual savings by fuel
      annual_savings = REXML::Element.new("#{@ns}:AnnualSavingsByFuels")
      if(variables.key?('baseline_fuel_electricity_kbtu') && variables.key?('fuel_electricity_kbtu'))
        electricity_savings = variables['baseline_fuel_electricity_kbtu'] - variables['fuel_electricity_kbtu']
        annual_saving = REXML::Element.new("#{@ns}:AnnualSavingsByFuel")
        energy_res = REXML::Element.new("#{@ns}:EnergyResource")
        energy_res.text = 'Electricity'
        annual_saving.add_element(energy_res)
        resource_units = REXML::Element.new("#{@ns}:ResourceUnits")
        resource_units.text = 'kBtu'
        annual_saving.add_element(resource_units)
        savings_native = REXML::Element.new("#{@ns}:AnnualSavingsNativeUnits") # this is in kBtu
        savings_native.text = electricity_savings.to_s
        annual_saving.add_element(savings_native)
        annual_savings.add_element(annual_saving)
      else
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMaker.calculate_annual_savings_value', "Cannot add 'baseline fuel electricity' and 'fuel electricity kbtu' variable to the BldgSync file since it is missing.")
      end
      if(variables.key?('baseline_fuel_natural_gas_kbtu') && variables.key?('fuel_natural_gas_kbtu'))
        natural_gas_savings = variables['baseline_fuel_natural_gas_kbtu'] - variables['fuel_natural_gas_kbtu']
        annual_saving = REXML::Element.new("#{@ns}:AnnualSavingsByFuel")
        energy_res = REXML::Element.new("#{@ns}:EnergyResource")
        energy_res.text = 'Natural gas'
        annual_saving.add_element(energy_res)
        resource_units = REXML::Element.new("#{@ns}:ResourceUnits")
        resource_units.text = 'kBtu'
        annual_saving.add_element(resource_units)
        savings_native = REXML::Element.new("#{@ns}:AnnualSavingsNativeUnits") # this is in kBtu
        savings_native.text = natural_gas_savings.to_s
        annual_saving.add_element(savings_native)
        annual_savings.add_element(annual_saving)
      else
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMaker.calculate_annual_savings_value', "Cannot add 'baseline fuel natural gas' and 'fuel natural gas' variable to the BldgSync file since it is missing.")
      end
      return annual_savings
    end

    # get resource uses element
    # @param scenario_name [String]
    # @param variables [hash]
    # @return [REXML::Element]
    def get_resource_uses_element(scenario_name, variables)
      res_uses = REXML::Element.new("#{@ns}:ResourceUses")
      scenario_name_ns = scenario_name.gsub(' ', '_').gsub(/[^0-9a-z_]/i, '')
      # ELECTRICITY
      res_use = REXML::Element.new("#{@ns}:ResourceUse")
      res_use.add_attribute('ID', scenario_name_ns + '_Electricity')
      if variables.key?('fuel_electricity_kbtu') && variables['fuel_electricity_kbtu']
        energy_res = REXML::Element.new("#{@ns}:EnergyResource")
        energy_res.text = 'Electricity'
        res_units = REXML::Element.new("#{@ns}:ResourceUnits")
        res_units.text = 'kBtu'
        native_units = REXML::Element.new("#{@ns}:AnnualFuelUseNativeUnits")
        native_units.text = variables['fuel_electricity_kbtu'].to_s
        consistent_units = REXML::Element.new("#{@ns}:AnnualFuelUseConsistentUnits")
        if variables['fuel_electricity_kbtu']
          consistent_units.text = (variables['fuel_electricity_kbtu'] / 1000.0).to_s # convert to MMBtu
          res_use.add_element(consistent_units)
        end
        res_use.add_element(energy_res)
        res_use.add_element(res_units)
        res_use.add_element(native_units)

        if variables.key?('annual_peak_electric_demand_kw') && variables['annual_peak_electric_demand_kw']
          peak_units = REXML::Element.new("#{@ns}:PeakResourceUnits")
          peak_units.text = 'kW'
          peak_native_units = REXML::Element.new("#{@ns}:AnnualPeakNativeUnits")
          peak_native_units.text = variables['annual_peak_electric_demand_kw'].to_s
          peak_consistent_units = REXML::Element.new("#{@ns}:AnnualPeakConsistentUnits")
          peak_consistent_units.text = variables['annual_peak_electric_demand_kw'].to_s
          res_use.add_element(peak_units)
          res_use.add_element(peak_native_units)
          res_use.add_element(peak_consistent_units)
        end
        res_uses.add_element(res_use)
      end
      # NATURAL GAS
      if variables.key?('fuel_natural_gas_kbtu') && variables['fuel_natural_gas_kbtu']
        res_use = REXML::Element.new("#{@ns}:ResourceUse")
        res_use.add_attribute('ID', scenario_name_ns + '_NaturalGas')
        energy_res = REXML::Element.new("#{@ns}:EnergyResource")
        energy_res.text = 'Natural gas'
        res_units = REXML::Element.new("#{@ns}:ResourceUnits")
        res_units.text = 'kBtu'
        native_units = REXML::Element.new("#{@ns}:AnnualFuelUseNativeUnits")
        native_units.text = variables['fuel_natural_gas_kbtu'].to_s
        consistent_units = REXML::Element.new("#{@ns}:AnnualFuelUseConsistentUnits")
        consistent_units.text = (variables['fuel_natural_gas_kbtu'] / 1000.0).to_s # in MMBtu
        res_use.add_element(energy_res)
        res_use.add_element(res_units)
        res_use.add_element(native_units)
        res_use.add_element(consistent_units)
        res_uses.add_element(res_use)
      end
      return res_uses
    end

    # get timeseries element
    # @param monthly_results [hash]
    # @param year_val [Integer]
    # @param scenario_name [String]
    # @param timeseriesdata [REXML:Element]
    # @param key_value [String]
    def get_timeseries_element(monthly_results, year_val, scenario_name, timeseriesdata, key_value)
      if !monthly_results.nil?
        month_lookup = {1 => 'jan', 2 => 'feb', 3 => 'mar', 4 => 'apr', 5 => 'may', 6 => 'jun', 7 => 'jul', 8 => 'aug', 9 => 'sep', 10 => 'oct', 11 => 'nov', 12 => 'dec'}
        scenario_name_ns = scenario_name.gsub(' ', '_').gsub(/[^0-9a-z_]/i, '')

        (1..12).each do |month|
          timeseries = REXML::Element.new("#{@ns}:TimeSeries")
          reading_type = REXML::Element.new("#{@ns}:ReadingType")
          reading_type.text = 'Total'
          timeseries.add_element(reading_type)
          ts_quantity = REXML::Element.new("#{@ns}:TimeSeriesReadingQuantity")
          ts_quantity.text = 'Energy'
          timeseries.add_element(ts_quantity)
          start_time = REXML::Element.new("#{@ns}:StartTimeStamp")
          if month < 10
            start_time.text = year_val.to_s + '-0' + month.to_s + '-01T00:00:00'
          else
            start_time.text = year_val.to_s + '-' + month.to_s + '-01T00:00:00'
          end
          timeseries.add_element(start_time)
          end_time = REXML::Element.new("#{@ns}:EndTimeStamp")
          if month < 9
            end_time.text = year_val.to_s + '-0' + (month + 1).to_s + '-01T00:00:00'
          elsif month < 12
            end_time.text = year_val.to_s + '-' + (month + 1).to_s + '-01T00:00:00'
          else
            end_time.text = year_val.to_s + '-01-01T00:00:00'
          end
          timeseries.add_element(end_time)
          interval_frequency = REXML::Element.new("#{@ns}:IntervalFrequency")
          interval_frequency.text = 'Month'
          timeseries.add_element(interval_frequency)
          interval_reading = REXML::Element.new("#{@ns}:IntervalReading")
          the_key = key_value.downcase + "_ip_#{month_lookup[month]}"
          # puts "saving value 123: #{monthly_results[scenario_name][the_key]}"
          if !monthly_results[scenario_name][the_key.to_sym].nil?
            interval_reading.text = monthly_results[scenario_name][the_key.to_sym].to_i * 3.4121416331 # kWh to kBtu
          end
          timeseries.add_element(interval_reading)
          resource_id = REXML::Element.new("#{@ns}:ResourceUseID")
          resource_id.add_attribute('IDref', scenario_name_ns + '_' + key_value)
          timeseries.add_element(resource_id)
          timeseriesdata.add_element(timeseries)
        end
      else
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMaker.get_timeseries_element', "Cannot add monthly report values to the BldgSync file since it is missing.")
      end
    end

    # get timeseries data element
    # @param monthly_results [hash]
    # @param year_val [Integer]
    # @param scenario_name [String]
    # @return [REXML:Element]
    def get_timeseries_data_element(monthly_results, year_val, scenario_name)
      timeseriesdata = REXML::Element.new("#{@ns}:TimeSeriesData")

      # Electricity
      # looking for: "electricity_ip_jan" through "electricity_ip_dec"
      # convert from kWh to kBtu
      get_timeseries_element(monthly_results, year_val, scenario_name, timeseriesdata, 'Electricity')
      # Natural Gas
      # looking for: "natural_gas_ip_jan" through "natural_gas_ip_dec"
      # convert from MMBtu to kBtu
      get_timeseries_element(monthly_results, year_val, scenario_name, timeseriesdata, 'NaturalGas')

      return timeseriesdata
    end

    # get all resource totals element
    # @param variables [hash]
    # @return [REXML::Element]
    def get_all_resource_totals_element(variables)
      all_res_totals = REXML::Element.new("#{@ns}:AllResourceTotals")
      all_res_total = REXML::Element.new("#{@ns}:AllResourceTotal")
      end_use = REXML::Element.new("#{@ns}:EndUse")
      end_use.text = 'All end uses'
      site_energy_use = REXML::Element.new("#{@ns}:SiteEnergyUse")
      site_energy_use.text = variables['total_site_energy_kbtu'].to_s
      site_energy_use_intensity = REXML::Element.new("#{@ns}:SiteEnergyUseIntensity")
      site_energy_use_intensity.text = variables['total_site_eui_kbtu_ft2'].to_s
      source_energy_use = REXML::Element.new("#{@ns}:SourceEnergyUse")
      source_energy_use.text = variables['total_source_energy_kbtu'].to_s
      source_energy_use_intensity = REXML::Element.new("#{@ns}:SourceEnergyUseIntensity")
      source_energy_use_intensity.text = variables['total_source_eui_kbtu_ft2'].to_s
      all_res_total.add_element(end_use)
      all_res_total.add_element(site_energy_use)
      all_res_total.add_element(site_energy_use_intensity)
      all_res_total.add_element(source_energy_use)
      all_res_total.add_element(source_energy_use_intensity)
      all_res_totals.add_element(all_res_total)
      return all_res_totals
    end

    # gather annual results
    # @param dir [String]
    # @param result [hash]
    # @param scenario_name [String]
    # @param baseline [hash]
    # @param is_baseline [Boolean]
    # @return [REXML:Element]
    def gather_annual_results(dir, result, scenario_name, baseline, is_baseline)
      variables = {}
      # Check out.osw "openstudio_results" for output variables
      variables['total_site_energy_kbtu'] = get_measure_result(result, 'openstudio_results', 'total_site_energy') # in kBtu
      variables['total_site_eui_kbtu_ft2'] = get_measure_result(result, 'openstudio_results', 'total_site_eui') # in kBtu/ft2
      # temporary hack to get source energy
      eplustbl_path = File.join(dir, scenario_name, 'eplustbl.htm')
      variables['total_source_energy_kbtu'], variables['total_source_eui_kbtu_ft2'] = get_source_energy_array(eplustbl_path)

      variables['fuel_electricity_kbtu'] = get_measure_result(result, 'openstudio_results', 'fuel_electricity') # in kBtu
      variables['fuel_natural_gas_kbtu'] = get_measure_result(result, 'openstudio_results', 'fuel_natural_gas') # in kBtu
      variables['annual_peak_electric_demand_kw'] = get_measure_result(result, 'openstudio_results', 'annual_peak_electric_demand') # in kW
      variables['annual_utility_cost'] = get_measure_result(result, 'openstudio_results', 'annual_utility_cost') # in $

      if(!is_baseline)
        variables['baseline_total_site_energy_kbtu'] = get_measure_result(baseline, 'openstudio_results', 'total_site_energy') # in kBtu
        variables['baseline_total_site_eui_kbtu_ft2'] = get_measure_result(baseline, 'openstudio_results', 'total_site_eui') # in kBtu/ft2
        # temporary hack
        baseline_eplustbl_path = File.join(dir, 'Baseline', 'eplustbl.htm')
        variables['baseline_total_source_energy_kbtu'], variables['baseline_total_source_eui_kbtu_ft2'] = get_source_energy_array(baseline_eplustbl_path)

        variables['baseline_fuel_electricity_kbtu'] = get_measure_result(baseline, 'openstudio_results', 'fuel_electricity') # in kBtu
        variables['baseline_fuel_natural_gas_kbtu'] = get_measure_result(baseline, 'openstudio_results', 'fuel_natural_gas') # in kBtu
        variables['baseline_annual_peak_electric_demand_kw'] = get_measure_result(baseline, 'openstudio_results', 'annual_peak_electric_demand') # in kW
        variables['baseline_annual_utility_cost'] = get_measure_result(baseline, 'openstudio_results', 'annual_utility_cost') # in $
      end

      variables['total_site_energy_savings_mmbtu'] = 0
      if variables['baseline_total_site_energy_kbtu'] && variables['total_site_energy_kbtu']
        variables['total_site_energy_savings_mmbtu'] = (variables['baseline_total_site_energy_kbtu'] - variables['total_site_energy_kbtu']) / 1000.0 # in MMBtu
      end

      variables['total_source_energy_savings_mmbtu']= 0
      if variables['baseline_total_source_energy_kbtu'] && variables['total_source_energy_kbtu']
        variables['total_source_energy_savings_mmbtu'] = (variables['baseline_total_source_energy_kbtu'] - variables['total_source_energy_kbtu']) / 1000.0 # in MMBtu
      end

      variables['total_energy_cost_savings'] = 0
      if variables['baseline_annual_utility_cost'] && variables['annual_utility_cost']
        variables['total_energy_cost_savings'] = variables['baseline_annual_utility_cost'] - variables['annual_utility_cost']
      end

      return variables
    end

    # get result for scenario
    # @param results [hash]
    # @param scenario [REXML:Element]
    # @return [array]
    def get_result_for_scenario(results, scenario)
      # code here
      scenario_name = scenario.elements["#{@ns}:ScenarioName"].text

      result = results[scenario_name]
      baseline = results[BASELINE]

      if result.nil?
        puts "Cannot load results for scenario #{scenario_name}, because the result is nil"
        @failed_scenarios << scenario_name
        return
      elsif baseline.nil?
        puts "Cannot load baseline results for scenario #{scenario_name}"
        @failed_scenarios << scenario_name
        return
      end

      if result['completed_status'] == 'Success' || result[:completed_status] == 'Success'
        # success
      else
        @failed_scenarios << scenario_name
      end

      return result, baseline
    end

    # adding results to a specific scenario
    # @param package_of_measures [REXML:Element]
    # @param scenario [REXML:Element]
    # @param scenario_name [String]
    # @param annual_results [hash]
    # @param result [hash]
    # @param monthly_results [hash]
    # @param year_val [Integer]
    def add_results_to_scenario(package_of_measures, scenario, scenario_name, annual_results, result, monthly_results, year_val)
      # first we need to check if we have any result variables
      if !annual_results || annual_results.empty?
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMaker.add_results_to_scenario', "result variables are null, cannot add results from scenario: #{scenario_name}to BldgSync file.")
        return false
      end
      # this is now in PackageOfMeasures.CalculationMethod.Modeled.SimulationCompletionStatus
      # options are: Not Started, Started, Finished, Failed, Unknown
      if package_of_measures
        package_of_measures.add_element(add_calc_method_element(result))
        package_of_measures.add_element(calculate_annual_savings_value(package_of_measures, annual_results))
      else
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMaker.add_results_to_scenario', "Scenario: #{scenario_name} does not have a package of measures xml element defined.")
      end

      res_uses = get_resource_uses_element(scenario_name, annual_results)
      scenario_type = scenario.elements["#{@ns}:ScenarioType"]
      scenario.insert_after(scenario_type, res_uses)

      # already added ResourceUses above. Needed as ResourceUseID reference
      timeseries_data = get_timeseries_data_element(monthly_results, year_val, scenario_name)
      scenario.insert_after(res_uses, timeseries_data)

      # all the totals
      all_res_totals = get_all_resource_totals_element(annual_results)
      scenario.insert_after(timeseries_data, all_res_totals)

      # no longer using user defined fields
      scenario.elements.delete("#{@ns}:UserDefinedFields")
      return true
    end

    # get osw dir
    # @param dir [String]
    # @param scenario [REXML:Element]
    # @return [String]
    def get_osw_dir(dir, scenario)
      scenario_name = scenario.elements["#{@ns}:ScenarioName"].text
      return File.join(dir, scenario_name)
    end

    # gather results
    # @param dir [String]
    # @param year_val [Integer]
    # @param baseline_only [Boolean]
    # @return [Boolean]
    def gather_results(dir, year_val = Date.today.year, baseline_only = false)
      results_counter = 0
      successful = true
      super
      begin
        scenarios_found = false

        # write an osw for each scenario
        results, monthly_results = get_result_for_scenarios(dir, baseline_only)

        get_scenario_elements.each do |scenario|
          begin
            scenarios_found = true
            # get information about the scenario
            scenario_name = scenario.elements["#{@ns}:ScenarioName"].text
            next if scenario_is_measured_scenario(scenario)
            next if !scenario_is_baseline_scenario(scenario) && baseline_only
            results_counter += 1
            package_of_measures_or_current_building = prepare_package_of_measures_or_current_building(scenario)
            result, baseline = get_result_for_scenario(results, scenario)
            annual_results = gather_annual_results(dir, result, scenario_name, baseline, scenario_name == 'Baseline')
            add_results_to_scenario(package_of_measures_or_current_building, scenario, scenario_name, annual_results, result, monthly_results, year_val)
          rescue StandardError => e
            OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMaker.gather_results', "The following error occurred #{e.message} while processing results in #{dir}")
            end_file = File.join(get_osw_dir(dir, scenario), 'eplusout.end')
            if File.file?(end_file)
              # we open the .end file to determine if EnergyPlus was successful or not
              energy_plus_string = File.open(end_file, &:readline)
              if energy_plus_string.include? 'Fatal Error Detected'
                OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMaker.gather_results', "EnergyPlus simulation did not succeed! #{energy_plus_string}")
                # if we found out that there was a fatal error we search the err file for the first error.
                File.open(File.join(osw_dir, 'eplusout.err')).each do |line|
                  if line.include? '** Severe  **'
                    OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMaker.gather_results', "Severe error occured! #{line}")
                  elsif line.include? '**  Fatal  **'
                    OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMaker.gather_results', "Fatal error occured! #{line}")
                  end
                end
              end
            else
              run_log = File.open(File.join(osw_dir, 'run.log'), &:readline)
              OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMaker.gather_results', "Workflow did not succeed! #{run_log}")
            end
          end
        end

        puts 'No scenarios found in BuildingSync XML File, please check the object hierarchy for errors.' if !scenarios_found
      rescue StandardError => e
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMaker.gather_results', "The following error occurred #{e.message} while processing results in #{dir}")
        successful = false
      end

      if results_counter > 0
        puts "#{results_counter} scenarios successfully simulated and results processed"
      end
      return successful
    end

    # get source energy array
    # @param eplustbl_path [String]
    # @return [array]
    def get_source_energy_array(eplustbl_path)
      # DLM: total hack because these are not reported in the out.osw
      # output is array of [source_energy, source_eui] in kBtu and kBtu/ft2
      result = []
      File.open(eplustbl_path, 'r') do |f|
        while line = f.gets
          if /\<td align=\"right\"\>Total Source Energy\<\/td\>/.match(line)
            result << /\<td align=\"right\"\>(.*?)<\/td\>/.match(f.gets)[1].to_f
            result << /\<td align=\"right\"\>(.*?)<\/td\>/.match(f.gets)[1].to_f
            break
          end
        end
      end

      result[0] = result[0] * 947.8171203133 # GJ to kBtu
      result[1] = result[1] * 0.947817120313 * 0.092903 # MJ/m2 to kBtu/ft2

      return result[0], result[1]
    end

    # extract annual results
    # @param scenario [REXML:Element]
    # @param scenario_name [String]
    # @param package_of_measures [REXML:Element]
    # @return [hash]
    def extract_annual_results(scenario, scenario_name, package_of_measures)
      variables = {}

      if package_of_measures
        if(package_of_measures.elements["#{@ns}:AnnualSavingsSiteEnergy"])
          variables['total_site_energy_savings_mmbtu'] = package_of_measures.elements["#{@ns}:AnnualSavingsSiteEnergy"].text
        end
        if(package_of_measures.elements["#{@ns}:AnnualSavingsSourceEnergy"])
          variables['total_source_energy_savings_mmbtu'] = package_of_measures.elements["#{@ns}:AnnualSavingsSourceEnergy"].text
        end
        if(package_of_measures.elements["#{@ns}:AnnualSavingsCost"])
          variables['total_energy_cost_savings'] = package_of_measures.elements["#{@ns}:AnnualSavingsCost"].text
        end
      end

      if scenario.elements["#{@ns}:ResourceUses"]
        scenario.elements["#{@ns}:ResourceUses"].each do |resource_use|
          if resource_use.elements["#{@ns}:EnergyResource"].text == 'Electricity'
            variables['fuel_electricity_kbtu'] = resource_use.elements["#{@ns}:AnnualFuelUseNativeUnits"].text
            if resource_use.elements["#{@ns}:PeakResourceUnits"].text == 'kW'
              variables['annual_peak_electric_demand_kw'] = resource_use.elements["#{@ns}:AnnualPeakNativeUnits"].text
            end
          elsif resource_use.elements["#{@ns}:EnergyResource"].text == 'Natural gas'
            variables['fuel_natural_gas_kbtu'] = resource_use.elements["#{@ns}:AnnualFuelUseNativeUnits"].text
          end
        end
      else
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMaker.extract_annual_results', "Scenario: #{scenario_name} does not have any ResourceUses xml elements defined.")
      end

      if package_of_measures && package_of_measures.elements["#{@ns}:AnnualSavingsByFuels"]
        package_of_measures.elements["#{@ns}:AnnualSavingsByFuels"].each do |annual_savings|
          if annual_savings.elements["#{@ns}:EnergyResource"].text == 'Electricity'
            variables['baseline_fuel_electricity_kbtu'] = annual_savings.elements["#{@ns}:AnnualSavingsNativeUnits"].text.to_i + variables['fuel_electricity_kbtu'].to_i
          elsif annual_savings.elements["#{@ns}:EnergyResource"].text == 'Natural gas'
            variables['baseline_fuel_natural_gas_kbtu'] = annual_savings.elements["#{@ns}:AnnualSavingsNativeUnits"].text.to_i + variables['fuel_natural_gas_kbtu'].to_i
          end
        end
      else
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMaker.extract_annual_results', "Scenario: #{scenario_name} does not have any AnnualSavingsByFuels xml elements defined.")
      end

      if scenario.elements["#{@ns}:AllResourceTotals"]
        scenario.elements["#{@ns}:AllResourceTotals"].each do |all_resource_total|
          if all_resource_total.elements["#{@ns}:SiteEnergyUse"]
            variables['total_site_energy_kbtu'] = all_resource_total.elements["#{@ns}:SiteEnergyUse"].text
          elsif all_resource_total.elements["#{@ns}:SiteEnergyUseIntensity"]
            variables['total_site_eui_kbtu_ft2'] = all_resource_total.elements["#{@ns}:SiteEnergyUseIntensity"].text
          elsif all_resource_total.elements["#{@ns}:SourceEnergyUse"]
            variables['total_source_energy_kbtu'] = all_resource_total.elements["#{@ns}:SourceEnergyUse"].text
          elsif all_resource_total.elements["#{@ns}:SourceEnergyUseIntensity"]
            variables['total_source_eui_kbtu_ft2'] = all_resource_total.elements["#{@ns}:SourceEnergyUseIntensity"].text
          end
        end
      else
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMaker.extract_annual_results', "Scenario: #{scenario_name} does not have any AllResourceTotals xml elements defined.")
      end
      return variables
    end
  end
end
