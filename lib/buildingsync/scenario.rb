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
require 'rexml/element'
require 'securerandom'

require 'buildingsync/helpers/helper'
require 'buildingsync/helpers/xml_get_set'
require 'buildingsync/resource_use'
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
      @g = BuildingSync::Generator.new(version = '2.2.0', ns = @ns)

      # linked fields
      @resource_uses = [] # Array[<BuildingSync::ResourceUse>]
      @time_series_data = [] # Array[<BuildingSync::TimeSeries]
      @all_resource_totals = [] # Array[<REXML::Element>] of AllResourceTotal

      # Simulation relevant fields
      @main_output_dir = nil
      @osw_dir = nil
      @workflow = {} # Hash to hold the workflow, see set_workflow
      @results_file_name = 'results.json' # holds annual and monthly results
      @out_osw_file_name = 'out.osw' # holds the completion status of the simulation
      @out_osw_json = nil # Hash to hold the read in of out.osw
      @results_json = nil # Hash to hold the read in of results.json
      @simulation_success = false # Set by check_simulation_success

      # Define a mapping between BuildingSync concepts to openstudio concepts
      # available in the results.json file
      @bsync_openstudio_resources_map = {
          "IP" => {
              "ResourceUse" => [
                  {
                      "EnergyResource" => "Electricity",
                      "EndUse" => "All end uses",
                      "fields" => [
                          {
                              # AnnualFuelUseConsistentUnits is in MMBtu/yr
                              "bsync_element_name" => "AnnualFuelUseConsistentUnits",
                              "bsync_element_units" => "MMBtu",
                              "os_results_key" => "fuel_electricity",
                              "os_results_unit" => "kBtu"
                          }
                      ]
                  },
                  {
                      "EnergyResource" => "Natural gas",
                      "EndUse" => "All end uses",
                      "fields" => [
                          {
                              # AnnualFuelUseConsistentUnits is in MMBtu/yr
                              "bsync_element_name" => "AnnualFuelUseConsistentUnits",
                              "bsync_element_units" => "MMBtu",
                              "os_results_key" => "fuel_natural_gas",
                              "os_results_unit" => "kBtu"
                          }
                      ]
                  }
              ],
              "AllResourceTotal" => [
                  {
                      "EndUse" => "All end uses",
                      "fields" => [
                          {
                              "bsync_element_name" => "SiteEnergyUse",
                              "bsync_element_units" => "kBtu",
                              "os_results_key" => "total_site_energy",
                              "os_results_unit" => "kBtu"
                          },
                          {
                              "bsync_element_name" => "SiteEnergyUseIntensity",
                              "bsync_element_units" => "kBtu/ft^2",
                              "os_results_key" => "total_site_eui",
                              "os_results_unit" => "kBtu/ft^2"
                          }
                      ]
                  }
              ]
          }
      }
      # ' Electricity ': {
      #     ' annual ': ' electricity_ip ',
      #     ' monthly ': %w(electricity_ip_jan electricity_ip_feb electricity_ip_mar electricity_ip_apr electricity_ip_may electricity_ip_jun electricity_ip_jul electricity_ip_aug electricity_ip_sep electricity_ip_oct electricity_ip_nov electricity_ip_dec)
      # },
      # ' Natural Gas ': {
      #     ' AnnualFuelUseConsistentUnits ': ' natural_gas_ip ',
      #     ' monthly ': %w(natural_gas_ip_jan natural_gas_ip_feb natural_gas_ip_mar natural_gas_ip_apr natural_gas_ip_may natural_gas_ip_jun natural_gas_ip_jul natural_gas_ip_aug natural_gas_ip_sep natural_gas_ip_oct natural_gas_ip_nov natural_gas_ip_dec)
      # }

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

    # @param workflow [Hash] a hash of the workflow
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

    # Check that the simulation was completed successfully.  Three things are checked:
    # - Existence of finished.job file
    # - Non-existence of failed.job file
    # - out.osw completed_status == ' Success '
    def check_simulation_success
      out_osw_file = File.join(@osw_dir, @out_osw_file_name)
      finished_job = File.join(@osw_dir, 'finished.job')
      failed_job = File.join(@osw_dir, 'failed.job')
      if !File.exist?(out_osw_file)
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Scenario.check_simulation_status', "Scenario ID: #{xget_id}.  #{out_osw_file} does not exist.")
      end

      File.open(out_osw_file, ' r ') do |file|
        @out_osw_json << JSON.parse(file)
      end

      if File.exist?(finished_job) && !File.exist?(failed_job) && @out_osw_json['completed_status'] == 'Success'
        @simulation_success = true
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Scenario.check_simulation_success', "Scenario ID: #{xget_id} successfully completed.")
      else
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Scenario.check_simulation_success', "Scenario ID: #{xget_id} unsuccessful.")
      end

    end

    def gather_openstudio_results
      check_simulation_success
      if !@simulation_success
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Scenario.gather_openstudio_results', "Scenario ID: #{xget_id}. Unable to gather results as simulation was unsuccessful.")
      else
        results_file = File.join(@osw_dir, @results_file_name)
        if !File.exist?(results_file)
          OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Scenario.gather_openstudio_results', "Scenario ID: #{xget_id}.  Unable to gather results: #{results_file} does not exist.")
        end

        File.open(results_file, 'r') do |file|
          @results_json << JSON.parse(file)
        end
        if @results_json['units'] == 'SI'
          OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Scenario.gather_openstudio_results', "Scenario ID: #{xget_id}. Only able to process IP results.")
          raise StandardError, "BuildingSync.Scenario.gather_openstudio_results. Scenario ID: #{xget_id}. Only able to process IP results."
        else
          parse_annual_results
          parse_monthly_results
        end
      end

    end

    def parse_annual_results(results = @results_json)
      ip_map = @bsync_openstudio_resources_map['IP']
      os_results = results["OpenStudio Results"]

      # Loop through ResourceUses in the resource_use_map
      ip_map['ResourceUse'].each do |resource_use_map|
        ru_type = resource_use_map['EnergyResource']
        end_use = resource_use_map['EndUse']

        # Check if a ResourceUse of the desired type already exists
        resource_use_element = @base_xml.get_elements("./#{@ns}:ResourceUses/#{@ns}:ResourceUse[#{@ns}:EnergyResource/text() = '#{ru_type}' and #{@ns}:EndUse/text() = '#{end_use}']")

        # Add a new ResourceUse xml to the Scenario
        if resource_use_element.nil? || resource_use_element.empty?
          resource_use_xml = @g.add_energy_resource_use_to_scenario(@base_xml, ru_type, end_use, "ResourceUse-#{ru_type.split.map(&:capitalize).join('')}-#{end_use.split.map(&:capitalize).join('')}")
        else
          OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Scenario.parse_annual_results', "Scenario ID: #{xget_id}.  Resource Use of type: #{ru_type} and end use: #{end_use} already exists")
          resource_use_xml = resource_use_element.first()
        end
        resource_use_map['fields'].each do |field|
          os_results_val = os_results[field['os_results_key']]
          if os_results_val.nil?
            OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Scenario.parse_annual_results', "Scenario ID: #{xget_id}.  Unable to find result for #{field['os_results_key']}")
          else
            if field['os_results_unit'] == field['bsync_element_units']
              new_element = REXML::Element.new("#{@ns}:#{field['bsync_element_name']}", resource_use_xml)
              new_element.text = os_results_val
            else
              converted = help_convert(os_results_val, field['os_results_unit'], field['bsync_element_units'])
              if !converted.nil?
                new_element = REXML::Element.new("#{@ns}:#{field['bsync_element_name']}", resource_use_xml)
                new_element.text = converted
              end
            end

            # Add ResourceUse
            @resource_uses << BuildingSync::ResourceUse.new(resource_use_xml, @ns)
          end
        end
      end
    end

    def parse_monthly_results(results = @results_json)

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
        all_resource_total.each do |a|
          @all_resource_totals << a
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
