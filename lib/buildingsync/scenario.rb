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
require 'rexml/element'
require 'securerandom'

require 'buildingsync/helpers/helper'
require 'buildingsync/helpers/xml_get_set'
require 'buildingsync/resource_use'
require 'buildingsync/all_resource_total'
require 'buildingsync/time_series'

module BuildingSync
  # Scenario class
  class Scenario
    include BuildingSync::Helper
    include BuildingSync::XmlGetSet

    def initialize(base_xml, ns)
      @base_xml = base_xml
      @ns = ns

      help_element_class_type_check(base_xml, 'Scenario')

      # Helpful
      @site_eui_xpath = "#{@ns}:AllResourceTotals/#{@ns}:AllResourceTotal/#{@ns}:SiteEnergyUseIntensity"
      @g = BuildingSync::Generator.new(@ns)

      # linked fields
      @resource_uses = [] # Array[<BuildingSync::ResourceUse>]
      @time_series_data = [] # Array[<BuildingSync::TimeSeries]
      @all_resource_totals = [] # Array[<REXML::Element>] of AllResourceTotal

      # Simulation relevant fields
      @main_output_dir = nil
      @osw_dir = nil
      @workflow = {} # Hash to hold the workflow, see set_workflow
      @results_file_name = 'results.json' # holds annual and monthly results
      @eplustbl_file_name = 'eplustbl.htm' # holds source energy results
      @out_osw_file_name = 'out.osw' # holds the completion status of the simulation
      @out_osw_json = nil # Hash to hold the read in of out.osw
      @results_json = nil # Hash to hold the read in of results.json

      # Define mappings for native units by Resource Use
      @native_units_map = {
        'Electricity' => 'kWh',
        'Natural gas' => 'kBtu'
      }

      # Define a mapping between BuildingSync concepts to openstudio concepts
      # available in the results.json file
      @bsync_openstudio_resources_map = {
        'IP' => {
          'ResourceUse' => [
            {
              'EnergyResource' => 'Electricity',
              'EndUse' => 'All end uses',
              'fields' => [
                {
                  # AnnualFuelUseConsistentUnits is in MMBtu/yr
                  'bsync_element_name' => 'AnnualFuelUseConsistentUnits',
                  'bsync_element_units' => 'MMBtu',
                  'os_results_key' => 'fuel_electricity',
                  'os_results_unit' => 'kBtu'
                },
                {
                  'bsync_element_name' => 'AnnualPeakConsistentUnits',
                  'bsync_element_units' => 'kW',
                  'os_results_key' => 'annual_peak_electric_demand',
                  'os_results_unit' => 'kW'
                }
              ],
              'monthly' => {
                # [bracket text] is replaced when processed
                'text' => 'electricity_ip_[month]',
                'os_results_unit' => 'kWh'
              }
            },
            {
              'EnergyResource' => 'Natural gas',
              'EndUse' => 'All end uses',
              'fields' => [
                {
                  # AnnualFuelUseConsistentUnits is in MMBtu/yr
                  'bsync_element_name' => 'AnnualFuelUseConsistentUnits',
                  'bsync_element_units' => 'MMBtu',
                  'os_results_key' => 'fuel_natural_gas',
                  'os_results_unit' => 'kBtu'
                }
              ],
              'monthly' => {
                # [bracket text] is replaced when processed
                'text' => 'natural_gas_ip_[month]',
                'os_results_unit' => 'MMBtu'
              }
            }
          ],
          'AllResourceTotal' => [
            {
              'EndUse' => 'All end uses',
              'fields' => [
                {
                  'bsync_element_name' => 'SiteEnergyUse',
                  'bsync_element_units' => 'kBtu',
                  'os_results_key' => 'total_site_energy',
                  'os_results_unit' => 'kBtu'
                },
                {
                  'bsync_element_name' => 'SiteEnergyUseIntensity',
                  'bsync_element_units' => 'kBtu/ft^2',
                  'os_results_key' => 'total_site_eui',
                  'os_results_unit' => 'kBtu/ft^2'
                }
              ]
            }
          ]
        }
      }

      read_xml

      # Removes data from POM and CB Modeled on import
      if !get_scenario_type_child_element.nil? && (pom? || cb_modeled?)
        delete_previous_results
      end
    end

    def read_xml
      # Read in data about ResourceUses, AllResourceTotals, and TimeSeriesData
      read_resource_uses
      read_all_resource_totals
      read_time_series_data
    end

    # @return [REXML::Element]
    def get_scenario_type_child_element
      scenario_type = xget_element('ScenarioType')
      if !scenario_type.nil?
        scenario_type.get_elements('*')[0]
      end
    end

    # @return [Array<String>]
    def get_measure_ids
      return xget_idrefs('MeasureID')
    end

    # @return [Array<BuildingSync::ResourceUse>]
    def get_resource_uses
      return @resource_uses
    end

    def get_all_end_use_resource_uses
      return @resource_uses.each.select { |ru| ru.xget_text('EndUse') == 'All end uses' }
    end

    # @return [Array<REXML::Element>]
    def get_all_resource_totals
      return @all_resource_totals
    end

    # @return [Array<BuildingSync::TimeSeries>]
    def get_time_series_data
      return @time_series_data
    end

    # @return [Hash]
    def get_workflow
      return @workflow
    end

    # @return [String]
    def get_main_output_dir
      return @main_output_dir
    end

    # get osw dir
    # @return [String] directory to the new osw_dir
    def get_osw_dir
      return @osw_dir
    end

    def get_benchmark_tool
      child = get_scenario_type_child_element
      return help_get_text_value(child.elements["#{@ns}:BenchmarkTool"])
    end

    # @param workflow [Hash] a hash of the openstudio workflow
    def set_workflow(workflow)
      if !workflow.is_a?(Hash)
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Scenario.set_workflow', "Scenario ID: #{xget_id}.  Cannot set_workflow, argument must be a Hash.")
        raise StandardError, "BuildingSync.Scenario.set_workflow Scenario ID: #{xget_id}.  Cannot set_workflow, argument must be a Hash, not a #{workflow.class}"
      else
        @workflow = workflow
      end
    end

    def set_main_output_dir(main_output_dir)
      @main_output_dir = main_output_dir
      return @main_output_dir
    end

    def set_osw_dir(main_output_dir = @main_output_dir)
      if !xget_name.nil?
        to_use = xget_name
      elsif !xget_id.nil?
        to_use = xget_id
      end
      @osw_dir = File.join(main_output_dir, to_use)
      return @osw_dir
    end

    # Create the @osw_dir
    def osw_mkdir_p
      if !@osw_dir.nil?
        FileUtils.mkdir_p(@osw_dir)
      else
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Scenario.osw_mkdir_p', "Scenario ID: #{xget_id}.  @osw_dir must be set first")
        raise StandardError, "BuildingSync.Scenario.osw_mkdir_p Scenario ID: #{xget_id}.  @osw_dir must be set first"
      end
    end

    # Use the @workflow definition to write a new ' in.osw ' file.
    # The main_output_dir and osw_dir are set and created if not existing.
    # @param main_output_dir [String] path to the main output directory to use
    def write_osw(main_output_dir = @main_output_dir)
      set_main_output_dir(main_output_dir)
      set_osw_dir(main_output_dir)
      osw_mkdir_p
      # write the osw
      path = File.join(@osw_dir, 'in.osw')
      File.open(path, 'w') do |file|
        file << JSON.pretty_generate(@workflow)
      end
    end

    # delete previous results from the Scenario.  This only affects POM or cb_modeled scenarios,
    # unless all = true is passed
    def delete_previous_results(all = false)
      if pom?
        get_scenario_type_child_element.elements.delete("#{@ns}:AnnualSavingsSiteEnergy")
        get_scenario_type_child_element.elements.delete("#{@ns}:AnnualSavingsCost")
        get_scenario_type_child_element.elements.delete("#{@ns}:CalculationMethod")
        get_scenario_type_child_element.elements.delete("#{@ns}AnnualSavingsByFuels")
      end

      # Delete elements from the xml and reset the attributes to empty
      if pom? || cb_modeled? || all
        get_scenario_type_child_element.elements.delete("#{@ns}AllResourceTotals")
        get_scenario_type_child_element.elements.delete("#{@ns}ResourceUses")
        @resource_uses = []
        @all_resource_totals = []
      end
    end

    # Check that the simulation was completed successfully.  We check:
    # - out.osw completed_status == 'Success'
    # - finished.job file exists
    # - failed.job file doesn't exist
    # - eplusout.end and eplusout.err files
    def simulation_success?
      success = true

      # Check out.osw
      out_osw_file = File.join(get_osw_dir, @out_osw_file_name)
      if !File.exist?(out_osw_file)
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Scenario.simulation_success?', "Scenario ID: #{xget_id}.  #{out_osw_file} does not exist.")
      else
        File.open(out_osw_file, 'r') do |file|
          @out_osw_json = JSON.parse(file.read)
        end
        if @out_osw_json['completed_status'] == 'Success'
          OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Scenario.simulation_success?', "Scenario ID: #{xget_id} successfully completed.")
        else
          success = false
          OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Scenario.simulation_success?', "Scenario ID: #{xget_id} unsuccessful.")
        end

      end

      # Check for finished.job
      finished_job = File.join(get_osw_dir, 'finished.job')
      if !File.exist?(finished_job)
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Scenario.simulation_success?', "Scenario ID: #{xget_id}: finished.job does not exist, simulation unsuccessful.")
        success = false
      end

      # Check for failed.job
      failed_job = File.join(get_osw_dir, 'failed.job')
      if File.exist?(failed_job)
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Scenario.simulation_success?', "Scenario ID: #{xget_id}: failed.job exists, simulation unsuccessful.")
        success = false
      end

      # Check eplusout.end and eplusout.err files
      end_file = File.join(get_osw_dir, 'eplusout.end')
      if File.exist?(end_file)
        # we open the .end file to determine if EnergyPlus was successful or not
        energy_plus_string = File.open(end_file, &:readline)
        if energy_plus_string.include? 'Fatal Error Detected'
          OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Scenario.simulation_success?', "Scenario ID: #{xget_id}: eplusout.end detected error, simulation unsuccessful: #{energy_plus_string}")
          success = false
          # if we found out that there was a fatal error we search the err file for the first error.
          File.open(File.join(scenario.get_osw_dir, 'eplusout.err')).each do |line|
            if line.include? '** Severe  **'
              OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Scenario.simulation_success?', "Scenario ID: #{xget_id}: Severe error occurred! #{line}")
            elsif line.include? '**  Fatal  **'
              OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Scenario.simulation_success?', "Scenario ID: #{xget_id}: Fatal error occurred! #{line}")
            end
          end
        end
      end

      return success
    end

    def results_available_and_correct_units?(results = @results_json)
      results_available = true

      if !results.nil?
        if @results_json['units'] == 'SI'
          OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Scenario.results_available_and_correct_units?', "Scenario ID: #{xget_id}. Only able to process IP results.")
          results_available = false
        end
      elsif !File.exist?(File.join(get_osw_dir, @results_file_name))
        results_available = false
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Scenario.results_available_and_correct_units?', "Scenario ID: #{xget_id}.  Unable to gather results: #{results_file} does not exist.")
      else
        results_file = File.join(get_osw_dir, @results_file_name)
        File.open(results_file, 'r') do |file|
          @results_json = JSON.parse(file.read)
        end
        if @results_json['units'] == 'SI'
          OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Scenario.results_available_and_correct_units?', "Scenario ID: #{xget_id}. Only able to process IP results.")
          results_available = false
        end
      end
      return results_available
    end

    def os_gather_results(year_val)
      if simulation_success? && results_available_and_correct_units?
        os_parse_annual_results
        os_parse_monthly_all_end_uses_results(year_val)
      elsif !simulation_success?
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Scenario.os_gather_results', "Scenario ID: #{xget_id}. Unable to gather results as simulation was unsuccessful.")
      elsif !results_available_and_correct_units?
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Scenario.os_gather_results', "Scenario ID: #{xget_id}. Unable to gather results as results are not available.")
      end
    end

    def os_parse_annual_results(results = @results_json)
      os_add_resource_uses(results)
      os_add_all_resource_totals(results)
    end

    def os_parse_monthly_all_end_uses_results(year_val = Date.today.year, results = @results_json)
      if results_available_and_correct_units?(results)
        time_series_data_xml = xget_or_create('TimeSeriesData')
        resource_use_map = @bsync_openstudio_resources_map['IP']['ResourceUse']
        os_results = results['OpenStudioResults']
        get_all_end_use_resource_uses.each do |resource_use|
          resource_use_hash = resource_use_map.each.find { |h| h['EnergyResource'] == resource_use.xget_text('EnergyResource') && h['EndUse'] == 'All end uses' }
          if resource_use_hash.nil?
            OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Scenario.os_parse_monthly_all_end_uses_results', "Scenario ID: #{xget_id}: Unable to find mapping for ResourceUse: #{resource_use.xget_id} and 'All end uses'. Cannot parse monthly results")
          else
            monthly_text = resource_use_hash['monthly']['text']
            monthly_units = resource_use_hash['monthly']['os_results_unit']
            native_units = @native_units_map[resource_use.xget_text('EnergyResource')]
            (1..12).each do |month|
              start_date_time = DateTime.new(year_val, month, 1)

              # substitues [month] with oct, for example, so we get electricity_ip_oct
              key_to_find = monthly_text.gsub('[month]', start_date_time.strftime('%b').downcase)
              if os_results.key?(key_to_find)
                # We always use the first day of the month as the start day
                time_series_xml = REXML::Element.new("#{@ns}:TimeSeries", time_series_data_xml)
                time_series_xml.add_attribute('ID', "TS-#{start_date_time.strftime('%b').upcase}-#{resource_use.xget_id}")

                # Convert value to correct units
                interval_reading_value = help_convert(os_results[key_to_find], monthly_units, native_units)

                # Create new TimeSeries element
                ts = BuildingSync::TimeSeries.new(time_series_xml, @ns)
                ts.set_monthly_energy_reading(start_date_time.dup, interval_reading_value, resource_use.xget_id)

              else
                OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Scenario.os_parse_monthly_all_end_uses_results', "Scenario ID: #{xget_id}: Key #{key_to_find} not found in results['OpenStudioResults'].  Make sure monthly data is being output by os_results measure")
              end
            end
          end
        end
      else
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.WorkflowMaker.get_timeseries_element', 'Cannot add monthly report values to the BldgSync file since it is missing.')
      end
    end

    # Use the bsync to openstudio resources map to add results from the openstudio
    # simulations as new ResourceUse elements and objects
    # @param results [Hash] a hash of the results as directly read in from a results.json file
    def os_add_resource_uses(results)
      @results_json = results
      ip_map = @bsync_openstudio_resources_map['IP']
      os_results = @results_json['OpenStudioResults']

      # Loop through ResourceUses in the resource_use_map
      ip_map['ResourceUse'].each do |resource_use_map|
        ru_type = resource_use_map['EnergyResource']
        end_use = resource_use_map['EndUse']
        native_units = @native_units_map[ru_type]

        # Check if a ResourceUse of the desired type already exists
        resource_use_element = @base_xml.get_elements("./#{@ns}:ResourceUses/#{@ns}:ResourceUse[#{@ns}:EnergyResource/text() = '#{ru_type}' and #{@ns}:EndUse/text() = '#{end_use}']")

        # Add a new ResourceUse xml to the Scenario.  This also adds ResourceUses if not defined
        if resource_use_element.nil? || resource_use_element.empty?
          ru_id = "#{xget_id}-ResourceUse-#{ru_type.split.map(&:capitalize).join('')}-#{end_use.split.map(&:capitalize).join('')}"
          resource_use_xml = @g.add_energy_resource_use_to_scenario(@base_xml, ru_type, end_use, ru_id, native_units)
        else
          OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Scenario.parse_annual_results', "Scenario ID: #{xget_id}.  Resource Use of type: #{ru_type} and end use: #{end_use} already exists")
          resource_use_xml = resource_use_element.first
        end

        # Map in the fields for each ResourceUse element into the xml
        add_fields_from_map(resource_use_map['fields'], os_results, resource_use_xml)

        # Add ResourceUse to array
        @resource_uses << BuildingSync::ResourceUse.new(resource_use_xml, @ns)
      end
    end

    def os_add_all_resource_totals(results)
      ip_map = @bsync_openstudio_resources_map['IP']
      os_results = results['OpenStudioResults']

      # Loop through ResourceUses in the resource_use_map
      ip_map['AllResourceTotal'].each do |map|
        end_use = map['EndUse']

        # Check if an AllResourceTotal of the desired type already exists
        element = @base_xml.get_elements("./#{@ns}:AllResourceTotals/#{@ns}:AllResourceTotal[#{@ns}:EndUse/text() = '#{end_use}']")

        # Add a new ResourceUse xml to the Scenario
        if element.nil? || element.empty?
          art_id = "#{xget_id}-AllResourceTotal-#{end_use.split.map(&:capitalize).join('')}"
          all_resource_total_xml = @g.add_all_resource_total_to_scenario(@base_xml, end_use, art_id)
        else
          OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Scenario.parse_annual_results', "Scenario ID: #{xget_id}.  Resource Use of type: #{ru_type} and end use: #{end_use} already exists")
          all_resource_total_xml = element.first
        end

        add_fields_from_map(map['fields'], os_results, all_resource_total_xml)
        # add_source_energy(all_resource_total_xml)

        @all_resource_totals << BuildingSync::AllResourceTotal.new(all_resource_total_xml, @ns)
      end
    end

    def add_source_energy(all_resource_total_xml)
      eplustbl_file = File.join(get_osw_dir, @eplustbl_file_name)
      if !File.exist?(eplustbl_file)
        OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Scenario.add_source_energy', "Scenario ID: #{xget_id}.  #{@eplustbl_file_name} does not exist, cannot add source energy results")
      else
        source_energy, source_eui = get_source_energy_array(eplustbl_file)
        source_energy_xml = REXML::Element.new("#{@ns}:SourceEnergyUse", all_resource_total_xml)
        source_energy_xml.text = source_energy
        source_eui_xml = REXML::Element.new("#{@ns}:SourceEnergyUseIntensity", all_resource_total_xml)
        source_eui_xml.text = source_eui
      end
    end

    # Get source energy and source EUI from
    # @param eplustbl_path [String]
    # @return [Array] [total_source_energy_kbtu, total_source_eui_kbtu_ft2]
    def get_source_energy_array(eplustbl_path)
      # DLM: total hack because these are not reported in the out.osw
      # output is array of [source_energy, source_eui] in kBtu and kBtu/ft2
      result = []
      File.open(eplustbl_path, 'r') do |f|
        while line = f.gets
          if /\<td align=\"right\"\>Total Source Energy\<\/td\>/.match?(line)
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

    def add_fields_from_map(fields, os_results, parent_xml)
      fields.each do |field|
        os_results_val = os_results[field['os_results_key']]
        if os_results_val.nil?
          OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Scenario.parse_annual_results', "Scenario ID: #{xget_id}.  Unable to find result for #{field['os_results_key']}")
        else
          if field['os_results_unit'] == field['bsync_element_units']
            # Parent element
            new_element = REXML::Element.new("#{@ns}:#{field['bsync_element_name']}", parent_xml)
            new_element.text = os_results_val
          else
            converted = help_convert(os_results_val, field['os_results_unit'], field['bsync_element_units'])
            if !converted.nil?
              new_element = REXML::Element.new("#{@ns}:#{field['bsync_element_name']}", parent_xml)
              new_element.text = converted
            end
          end
        end
      end
    end

    def read_resource_uses
      resource_use = @base_xml.get_elements("./#{@ns}:ResourceUses/#{@ns}:ResourceUse")
      if !resource_use.nil? && !resource_use.empty?
        resource_use.each do |ru|
          @resource_uses << BuildingSync::ResourceUse.new(ru, @ns)
        end
      end
    end

    def read_all_resource_totals
      all_resource_total = @base_xml.get_elements("./#{@ns}:AllResourceTotals/#{@ns}:AllResourceTotal")
      if !all_resource_total.nil? && !all_resource_total.empty?
        all_resource_total.each do |art|
          @all_resource_totals << BuildingSync::AllResourceTotal.new(art, @ns)
        end
      end
    end

    def read_time_series_data
      time_series = @base_xml.get_elements("./#{@ns}:TimeSeriesData/#{@ns}:TimeSeries")
      if !time_series.nil? && !time_series.empty?
        time_series.each do |ts|
          @time_series_data << BuildingSync::TimeSeries.new(ts, @ns)
        end
      end
    end

    def check_scenario_type(path)
      to_check = xget_element('ScenarioType').get_elements(path)
      if !to_check.nil? && !to_check.empty?
        return true
      else
        return false
      end
    end

    def cb_measured?
      if xget_element('ScenarioType').nil?
        return false
      end
      return check_scenario_type("./#{@ns}:CurrentBuilding/#{@ns}:CalculationMethod/#{@ns}:Measured")
    end

    def cb_modeled?
      if xget_element('ScenarioType').nil?
        return false
      end
      return check_scenario_type("./#{@ns}:CurrentBuilding/#{@ns}:CalculationMethod/#{@ns}:Modeled")
    end

    def pom?
      if xget_element('ScenarioType').nil?
        return false
      end
      return check_scenario_type("./#{@ns}:PackageOfMeasures")
    end

    def target?
      if xget_element('ScenarioType').nil?
        return false
      end
      return check_scenario_type("./#{@ns}:Target")
    end

    def benchmark?
      if xget_element('ScenarioType').nil?
        return false
      end
      return check_scenario_type("./#{@ns}:Benchmark")
    end
  end
end
