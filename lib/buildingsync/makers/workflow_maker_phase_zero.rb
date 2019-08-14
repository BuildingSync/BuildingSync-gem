# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2019, Alliance for Sustainable Energy, LLC.
# BuildingSync(R), Copyright (c) 2015-2019, Alliance for Sustainable Energy, LLC.
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
require_relative '../workflow_maker'
require 'openstudio/common_measures'
require 'openstudio/model_articulation'
require 'openstudio-extension'
require_relative '../../../lib/buildingsync/extension'

module BuildingSync
  # base class for objects that will configure workflows based on building sync files
  class PhaseZeroWorkflowMaker < WorkflowMaker
    @@facility = nil
    def initialize(doc, ns)
      super

      # load the workflow
      @workflow = nil

      # log failed scenarios
      @failed_scenarios = []
      @scenario_types = nil

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
      bldg_sync_instance = BuildingSync::Extension.new
      return [common_measures_instance.measures_dir, model_articulation_instance.measures_dir, bldg_sync_instance.measures_dir]
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
      @workflow['steps'].each do |step|
        measure_dir_name = step['measure_dir_name']
        measure_type = get_measure_type(measure_dir_name)
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.WorkflowMakerPhaseZero.insert_measure', "measure: #{measure_dir_name} with type: #{measure_type} found")
        puts "measure: #{measure_dir_name} with type: #{measure_type} found"
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
      if (!successfully_added)
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
      puts "measure_dir: #{measure_dir} with type: #{measure_type}"
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
        if argument[:condition] == @@facility['bldg_type']
          argument_name = argument[:name]
          argument_value = "#{argument[:value]} #{@@facility['template']}"
        end
      elsif measure_name == 'Replace burner'
        if argument[:condition] == @@facility['system_type']
          argument_name = argument[:name]
          argument_value = argument[:value]
        end
      elsif measure_name == 'Replace boiler'
        if argument[:condition] == @@facility['system_type']
          argument_name = argument[:name]
          argument_value = argument[:value]
        end
      elsif measure_name == 'Replace package units'
        if argument[:condition] == @@facility['system_type']
          argument_name = argument[:name]
          argument_value = argument[:value]
        end
      elsif measure_name == 'Replace HVAC system type to VRF' || measure_name == 'Replace HVAC with GSHP and DOAS' || measure_name == 'Replace AC and heating units with ground coupled heat pump systems'
        if argument[:condition] == @@facility['bldg_type']
          argument_name = "#{argument[:name]} #{@@facility['template']}"
          argument_value = argument[:value]
        end
      else
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMakerPhaseZero.set_argument_detail', "measure dir name not found #{measure_name}.")
        puts "BuildingSync.WorkflowMakerPhaseZero.set_argument_detail: Measure dir name not found #{measure_name}."
      end

      set_measure_argument(osw, measure_dir_name, argument_name, argument_value) if !argument_name.nil? && !argument_name.empty?
    end

    def configure_for_scenario(osw, scenario)
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

              meas_name[:"#{measure_name}"][:arguments].each do |argument|
                num_measures += 1
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
          end
        end
      end

      # ensure that we didn't miss any measures by accident
      OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMaker.configure_for_scenario', "#{measure_ids.size} measures expected, #{num_measures} found,  measure_ids = #{measure_ids}") if num_measures != measure_ids.size
    end

    def write_osws(dir)
      super

      # ensure there is a 'Baseline' scenario
      found_baseline = false
      @doc.elements.each("#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility/#{@ns}:Report/#{@ns}:Scenarios/#{@ns}:Scenario") do |scenario|
        scenario_name = scenario.elements["#{@ns}:ScenarioName"].text
        if scenario_name == 'Baseline'
          found_baseline = true
          break
        end
      end

      if !found_baseline
        scenarios_element = @doc.elements["#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility/#{@ns}:Report/#{@ns}:Scenarios"]

        scenario_element = REXML::Element.new("#{@ns}:Scenario")
        scenario_element.attributes['ID'] = 'Baseline'

        scenario_name_element = REXML::Element.new("#{@ns}:ScenarioName")
        scenario_name_element.text = 'Baseline'
        scenario_element.add_element(scenario_name_element)

        scenario_type_element = REXML::Element.new("#{@ns}:ScenarioType")
        package_of_measures_element = REXML::Element.new("#{@ns}:PackageOfMeasures")
        reference_case_element = REXML::Element.new("#{@ns}:ReferenceCase")
        reference_case_element.attributes['IDref'] = 'Baseline'
        package_of_measures_element.add_element(reference_case_element)
        scenario_type_element.add_element(package_of_measures_element)
        scenario_element.add_element(scenario_type_element)

        scenarios_element.add_element(scenario_element)
      end

      found_baseline = false
      @doc.elements.each("#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility/#{@ns}:Report/#{@ns}:Scenarios/#{@ns}:Scenario") do |scenario|
        scenario_name = scenario.elements["#{@ns}:ScenarioName"].text
        if scenario_name == 'Baseline'
          found_baseline = true
          break
        end
      end

      if !found_baseline
        puts 'Cannot find or create Baseline scenario'
        exit
      end

      # write an osw for each scenario
      @doc.elements.each("#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility/#{@ns}:Report/#{@ns}:Scenarios/#{@ns}:Scenario") do |scenario|
        # get information about the scenario
        scenario_name = scenario.elements["#{@ns}:ScenarioName"].text
        next if defined?(BuildingSync::Extension::SIMULATE_BASELINE_ONLY) && BuildingSync::Extension::SIMULATE_BASELINE_ONLY && (scenario_name != 'Baseline')

        # deep clone
        osw = JSON.load(JSON.generate(@workflow))

        # configure the workflow based on measures in this scenario
        begin
          configure_for_scenario(osw, scenario)

          # dir for the osw
          osw_dir = File.join(dir, scenario_name)
          FileUtils.mkdir_p(osw_dir)

          # write the osw
          path = File.join(osw_dir, 'in.osw')
          File.open(path, 'w') do |file|
            file << JSON.generate(osw)
          end
        rescue StandardError => e
          puts "Could not configure for scenario #{scenario_name}"
          puts e.backtrace.join("\n\t")
        end
      end
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

    def gather_results(dir)
      super

      results = {}

      # write an osw for each scenario
      @doc.elements.each("#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility/#{@ns}:Report/#{@ns}:Scenarios/#{@ns}:Scenario") do |scenario|
        # get information about the scenario
        scenario_name = scenario.elements["#{@ns}:ScenarioName"].text
        next if defined?(BuildingSync::Extension::SIMULATE_BASELINE_ONLY) && BuildingSync::Extension::SIMULATE_BASELINE_ONLY && (scenario_name != 'Baseline')

        # dir for the osw
        osw_dir = File.join(dir, scenario_name)

        # cleanup large files
        path = File.join(osw_dir, 'eplusout.sql')
        FileUtils.rm_f(path) if File.exist?(path)

        path = File.join(osw_dir, 'data_point.zip')
        FileUtils.rm_f(path) if File.exist?(path)

        path = File.join(osw_dir, 'eplusout.eso')
        FileUtils.rm_f(path) if File.exist?(path)

        # find the osw
        path = File.join(osw_dir, 'out.osw')
        if !File.exist?(path)
          puts "Cannot load results for scenario #{scenario_name}"
          next
        end

        workflow = nil
        File.open(path, 'r') do |file|
          results[scenario_name] = JSON.parse(file.read, symbolize_names: true)
        end
      end

      @doc.elements.each("#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility/#{@ns}:Report/#{@ns}:Scenarios/#{@ns}:Scenario") do |scenario|
        # get information about the scenario
        scenario_name = scenario.elements["#{@ns}:ScenarioName"].text
        next if defined?(BuildingSync::Extension::SIMULATE_BASELINE_ONLY) && BuildingSync::Extension::SIMULATE_BASELINE_ONLY && (scenario_name != 'Baseline')

        package_of_measures = scenario.elements["#{@ns}:ScenarioType"].elements["#{@ns}:PackageOfMeasures"]

        # delete previous results
        package_of_measures.elements.delete("#{@ns}:AnnualSavingsSiteEnergy")
        package_of_measures.elements.delete("#{@ns}:AnnualSavingsCost")

        result = results[scenario_name]
        baseline = results['Baseline']

        if result.nil?
          puts "Cannot load results for scenario #{scenario_name}"
          @failed_scenarios << scenario_name
          next
        elsif baseline.nil?
          puts "Cannot load baseline results for scenario #{scenario_name}"
          @failed_scenarios << scenario_name
          next
        end

        if result['completed_status'] == 'Success' || result[:completed_status] == 'Success'
          # success
        else
          @failed_scenarios << scenario_name
        end

        # preserve existing user defined fields if they exist
        user_defined_fields = scenario.elements["#{@ns}:UserDefinedFields"]
        if user_defined_fields.nil?
          user_defined_fields = REXML::Element.new("#{@ns}:UserDefinedFields")
        end

        # delete previous results
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

        user_defined_field = REXML::Element.new("#{@ns}:UserDefinedField")
        field_name = REXML::Element.new("#{@ns}:FieldName")
        field_name.text = 'OpenStudioCompletedStatus'
        field_value = REXML::Element.new("#{@ns}:FieldValue")
        field_value.text = result[:completed_status]
        user_defined_field.add_element(field_name)
        user_defined_field.add_element(field_value)
        user_defined_fields.add_element(user_defined_field)

        user_defined_field = REXML::Element.new("#{@ns}:UserDefinedField")
        field_name = REXML::Element.new("#{@ns}:FieldName")
        field_name.text = 'OpenStudioBaselineCompletedStatus'
        field_value = REXML::Element.new("#{@ns}:FieldValue")
        field_value.text = baseline[:completed_status]
        user_defined_field.add_element(field_name)
        user_defined_field.add_element(field_value)
        user_defined_fields.add_element(user_defined_field)

        # Check out.osw "openstudio_results" for output variables
        total_site_energy = get_measure_result(result, 'openstudio_results', 'total_site_energy') # in kBtu/year
        total_site_energy /= 1000.0 if total_site_energy # kBtu/year -> MMBtu/year
        baseline_total_site_energy = get_measure_result(baseline, 'openstudio_results', 'total_site_energy') # in kBtu
        baseline_total_site_energy /= 1000.0 if baseline_total_site_energy # kBtu/year -> MMBtu/year
        fuel_electricity = get_measure_result(result, 'openstudio_results', 'fuel_electricity') # in kBtu/year
        # fuel_electricity = fuel_electricity * 0.2930710702 # kBtu/year -> kWh
        fuel_natural_gas = get_measure_result(result, 'openstudio_results', 'fuel_natural_gas') # in kBtu/year
        annual_utility_cost = get_measure_result(result, 'openstudio_results', 'annual_utility_cost') # in $
        baseline_annual_utility_cost = get_measure_result(baseline, 'openstudio_results', 'annual_utility_cost') # in $

        total_site_energy_savings = 0
        total_energy_cost_savings = 0
        if baseline_total_site_energy && total_site_energy
          total_site_energy_savings = baseline_total_site_energy - total_site_energy
          total_energy_cost_savings = baseline_annual_utility_cost - annual_utility_cost
        end

        annual_savings_site_energy = REXML::Element.new("#{@ns}:AnnualSavingsSiteEnergy")
        annual_savings_energy_cost = REXML::Element.new("#{@ns}:AnnualSavingsCost")

        # DLM: these are not valid BuildingSync fields
        # annual_site_energy = REXML::Element.new("#{@ns}:AnnualSiteEnergy")
        # annual_electricity = REXML::Element.new("#{@ns}:AnnualElectricity")
        # annual_natural_gas = REXML::Element.new("#{@ns}:AnnualNaturalGas")

        annual_savings_site_energy.text = total_site_energy_savings
        annual_savings_energy_cost.text = total_energy_cost_savings.to_i # BuildingSync wants an integer, might be a BuildingSync bug
        # annual_site_energy.text = total_site_energy
        # annual_electricity.text = fuel_electricity
        # annual_natural_gas.text = fuel_natural_gas

        user_defined_field = REXML::Element.new("#{@ns}:UserDefinedField")
        field_name = REXML::Element.new("#{@ns}:FieldName")
        field_name.text = 'OpenStudioAnnualSiteEnergy_MMBtu'
        field_value = REXML::Element.new("#{@ns}:FieldValue")
        field_value.text = total_site_energy.to_s
        user_defined_field.add_element(field_name)
        user_defined_field.add_element(field_value)
        user_defined_fields.add_element(user_defined_field)

        user_defined_field = REXML::Element.new("#{@ns}:UserDefinedField")
        field_name = REXML::Element.new("#{@ns}:FieldName")
        field_name.text = 'OpenStudioAnnualElectricity_kBtu'
        field_value = REXML::Element.new("#{@ns}:FieldValue")
        field_value.text = fuel_electricity.to_s
        user_defined_field.add_element(field_name)
        user_defined_field.add_element(field_value)
        user_defined_fields.add_element(user_defined_field)

        user_defined_field = REXML::Element.new("#{@ns}:UserDefinedField")
        field_name = REXML::Element.new("#{@ns}:FieldName")
        field_name.text = 'OpenStudioAnnualNaturalGas_kBtu'
        field_value = REXML::Element.new("#{@ns}:FieldValue")
        field_value.text = fuel_natural_gas.to_s
        user_defined_field.add_element(field_name)
        user_defined_field.add_element(field_value)
        user_defined_fields.add_element(user_defined_field)

        package_of_measures.add_element(annual_savings_site_energy)
        package_of_measures.add_element(annual_savings_energy_cost)
        # package_of_measures.add_element(annual_site_energy)
        # package_of_measures.add_element(annual_electricity)
        # package_of_measures.add_element(annual_natural_gas)

        scenario.elements.delete("#{@ns}:UserDefinedFields")
        scenario.add_element(user_defined_fields)
      end
    end

    def failed_scenarios
      return @failed_scenarios
    end
  end
end
