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
    end

    def get_measure_directories_array
      common_measures_instance = OpenStudio::CommonMeasures::Extension.new
      model_articulation_instance = OpenStudio::ModelArticulation::Extension.new
      ee_measures_instance = OpenStudio::EeMeasures::Extension.new
      bldg_sync_instance = BuildingSync::Extension.new
      return [common_measures_instance.measures_dir, model_articulation_instance.measures_dir, bldg_sync_instance.measures_dir, 'R:\NREL\edv-experiment-1\.bundle\install\ruby\2.2.0\gems\openstudio-standards-0.2.9\lib']
    end

    def insert_energyplus_measure(measure_dir, item = 0, args_hash = {})
      insert_measure('EnergyPlusMeasure', measure_dir, item, args_hash)
    end

    def insert_reporting_measure(measure_dir, item = 0, args_hash = {})
      insert_measure('ReportingMeasure', measure_dir, item, args_hash)
    end

    def insert_model_measure(measure_dir, item = 0, args_hash = {})
      insert_measure('ModelMeasure', measure_dir, item, args_hash)
    end

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

    def get_workflow
      return @workflow
    end

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

    def get_scenarios
      scenarios = @doc.elements["#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility/#{@ns}:Reports/#{@ns}:Report/#{@ns}:Scenarios"]
      return scenarios
    end

    def scenario_is_baseline_scenario(scenario)
      # first we check if we find the new scenario type definition
      return true if scenario.elements["#{@ns}:CurrentBuilding/#{@ns}:CalculationMethod/#{@ns}:Modeled"]
      return false
    end

    def scenario_is_measured_scenario(scenario)
      # first we check if we find the new scenario type definition
      return true if scenario.elements["#{@ns}:CurrentBuilding/#{@ns}:CalculationMethod/#{@ns}:Measured"]
      return false
    end

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

          scenario_type_element = REXML::Element.new("#{@ns}:ScenarioType")
          package_of_measures_element = REXML::Element.new("#{@ns}:PackageOfMeasures")
          reference_case_element = REXML::Element.new("#{@ns}:ReferenceCase")
          reference_case_element.attributes['IDref'] = BASELINE
          package_of_measures_element.add_element(reference_case_element)
          scenario_type_element.add_element(package_of_measures_element)
          scenario_element.add_element(scenario_type_element)

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
          osw_dir = File.join(dir, scenario_name)
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

      return nil
    end

    def get_failed_scenarios
      return @failed_scenarios
    end

    def save_xml(filename)
      File.open(filename, 'w') do |file|
        @doc.write(file)
      end
    end

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
        osw_dir = File.join(dir, scenario_name)
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

    def delete_resource_element(scenario, package_of_measures)
      package_of_measures.elements.delete("#{@ns}:AnnualSavingsSiteEnergy")
      package_of_measures.elements.delete("#{@ns}:AnnualSavingsCost")
      package_of_measures.elements.delete("#{@ns}:CalculationMethod")
      package_of_measures.elements.delete("#{@ns}AnnualSavingsByFuels")
      scenario.elements.delete("#{@ns}AllResourceTotals")
      scenario.elements.delete("#{@ns}RsourceUses")
      scenario.elements.delete("#{@ns}AnnualSavingsByFuels")
    end

    def get_package_of_measures(scenario)
      return scenario.elements["#{@ns}:ScenarioType"].elements["#{@ns}:PackageOfMeasures"]
    end

    def delete_previous_results(scenario)
      package_of_measures = get_package_of_measures(scenario)
      # delete previous results
      delete_resource_element(scenario, package_of_measures)

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
      return package_of_measures
    end

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

    def get_resource_uses_element(scenario_name, variables)
      res_uses = REXML::Element.new("#{@ns}:ResourceUses")
      scenario_name_ns = scenario_name.gsub(' ', '_').gsub(/[^0-9a-z_]/i, '')
      # ELECTRICITY
      res_use = REXML::Element.new("#{@ns}:ResourceUse")
      res_use.add_attribute('ID', scenario_name_ns + '_Electricity')
      if variables.key?('fuel_electricity_kbtu')
        energy_res = REXML::Element.new("#{@ns}:EnergyResource")
        energy_res.text = 'Electricity'
        res_units = REXML::Element.new("#{@ns}:ResourceUnits")
        res_units.text = 'kBtu'
        native_units = REXML::Element.new("#{@ns}:AnnualFuelUseNativeUnits")
        native_units.text = variables['fuel_electricity_kbtu'].to_s
        consistent_units = REXML::Element.new("#{@ns}:AnnualFuelUseConsistentUnits")
        consistent_units.text = (variables['fuel_electricity_kbtu'] / 1000.0).to_s # convert to MMBtu
        res_use.add_element(energy_res)
        res_use.add_element(res_units)
        res_use.add_element(native_units)
        res_use.add_element(consistent_units)
        if variables.key?('annual_peak_electric_demand_kw')
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
      if variables.key?('fuel_natural_gas_kbtu')
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

    def gather_annual_results(dir, result, scenario_name, baseline)
      variables = {}
      # Check out.osw "openstudio_results" for output variables
      variables['total_site_energy_kbtu'] = get_measure_result(result, 'openstudio_results', 'total_site_energy') # in kBtu
      variables['baseline_total_site_energy_kbtu'] = get_measure_result(baseline, 'openstudio_results', 'total_site_energy') # in kBtu

      variables['total_site_eui_kbtu_ft2'] = get_measure_result(result, 'openstudio_results', 'total_site_eui') # in kBtu/ft2
      variables['baseline_total_site_eui_kbtu_ft2'] = get_measure_result(baseline, 'openstudio_results', 'total_site_eui') # in kBtu/ft2

      # temporary hack to get source energy
      eplustbl_path = File.join(dir, scenario_name, 'eplustbl.htm')
      variables['total_source_energy_kbtu'], variables['total_source_eui_kbtu_ft2'] = get_source_energy_array(eplustbl_path)

      baseline_eplustbl_path = File.join(dir, BASELINE, 'eplustbl.htm')
      variables['baseline_total_source_energy_kbtu'], variables['baseline_total_source_eui_kbtu_ft2'] = get_source_energy_array(baseline_eplustbl_path)
      # end hack

      variables['fuel_electricity_kbtu'] = get_measure_result(result, 'openstudio_results', 'fuel_electricity') # in kBtu
      variables['baseline_fuel_electricity_kbtu'] = get_measure_result(baseline, 'openstudio_results', 'fuel_electricity') # in kBtu

      variables['fuel_natural_gas_kbtu'] = get_measure_result(result, 'openstudio_results', 'fuel_natural_gas') # in kBtu
      variables['baseline_fuel_natural_gas_kbtu'] = get_measure_result(baseline, 'openstudio_results', 'fuel_natural_gas') # in kBtu

      variables['annual_peak_electric_demand_kw'] = get_measure_result(result, 'openstudio_results', 'annual_peak_electric_demand') # in kW
      variables['baseline_annual_peak_electric_demand_kw'] = get_measure_result(baseline, 'openstudio_results', 'annual_peak_electric_demand') # in kW

      variables['annual_utility_cost'] = get_measure_result(result, 'openstudio_results', 'annual_utility_cost') # in $
      variables['baseline_annual_utility_cost'] = get_measure_result(baseline, 'openstudio_results', 'annual_utility_cost') # in $

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
    def add_results_to_scenario(package_of_measures, scenario, scenario_name, annual_results, result, monthly_results, year_val)
      # first we need to check if we have any result variables
      if !annual_results || annual_results.length == 0
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMaker.add_results_to_scenario', "result variables are null, cannot add results from scenario: #{scenario_name}to BldgSync file.")
        return false
      end
      # this is now in PackageOfMeasures.CalculationMethod.Modeled.SimulationCompletionStatus
      # options are: Not Started, Started, Finished, Failed, Unknown
      package_of_measures.add_element(add_calc_method_element(result))
      package_of_measures.add_element(calculate_annual_savings_value(package_of_measures, annual_results))

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

    def gather_results(dir, year_val, baseline_only = false)
      results_counter = 0
      successful = true
      super
      begin
        scenarios_found = false

        # write an osw for each scenario
        results, monthly_results = get_result_for_scenarios(dir, baseline_only)

        if !baseline_only
          get_scenario_elements.each do |scenario|
            scenarios_found = true
            # get information about the scenario
            scenario_name = scenario.elements["#{@ns}:ScenarioName"].text
            next if scenario_is_measured_scenario(scenario)
            next if scenario_is_baseline_scenario(scenario)

            results_counter += 1
            package_of_measures = delete_previous_results(scenario)
            result, baseline = get_result_for_scenario(results, scenario)
            annual_results = gather_annual_results(dir, result, scenario_name, baseline)

            add_results_to_scenario(package_of_measures, scenario, scenario_name, annual_results, result, monthly_results, year_val)
          end
        end

        puts 'No scenarios found in BuildingSync XML File, please check the object hierarchy for errors.' if !scenarios_found
      rescue StandardError => e
        puts "The following error occurred #{e.message} while processing results in #{dir}"
        successful = false
      end

      if results_counter > 0
        puts "#{results_counter} scenarios successfully simulated and results processed"
      end
      return successful
    end

    # DLM: total hack because these are not reported in the out.osw
    # output is array of [source_energy, source_eui] in kBtu and kBtu/ft2
    def get_source_energy_array(eplustbl_path)
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

    def extract_annual_results(scenario, package_of_measures)
      variables = {}

      if(package_of_measures.elements["#{@ns}:AnnualSavingsSiteEnergy"])
        variables['total_site_energy_savings_mmbtu'] = package_of_measures.elements["#{@ns}:AnnualSavingsSiteEnergy"].text
      end
      if(package_of_measures.elements["#{@ns}:AnnualSavingsSourceEnergy"])
        variables['total_source_energy_savings_mmbtu'] = package_of_measures.elements["#{@ns}:AnnualSavingsSourceEnergy"].text
      end
      if(package_of_measures.elements["#{@ns}:AnnualSavingsCost"])
        variables['total_energy_cost_savings'] = package_of_measures.elements["#{@ns}:AnnualSavingsCost"].text
      end

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

      package_of_measures.elements["#{@ns}:AnnualSavingsByFuels"].each do |annual_savings|
        if annual_savings.elements["#{@ns}:EnergyResource"].text == 'Electricity'
          variables['baseline_fuel_electricity_kbtu'] = annual_savings.elements["#{@ns}:AnnualSavingsNativeUnits"].text.to_i + variables['fuel_electricity_kbtu'].to_i
        elsif annual_savings.elements["#{@ns}:EnergyResource"].text == 'Natural gas'
          variables['baseline_fuel_natural_gas_kbtu'] = annual_savings.elements["#{@ns}:AnnualSavingsNativeUnits"].text.to_i + variables['fuel_natural_gas_kbtu'].to_i
        end
      end

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
      return variables
    end
  end
end
