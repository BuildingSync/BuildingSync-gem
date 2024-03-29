# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2022, Alliance for Sustainable Energy, LLC.
# BuildingSync(R), Copyright (c) 2015-2022, Alliance for Sustainable Energy, LLC.
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
require 'builder/xmlmarkup'
require 'rexml/document'

require 'buildingsync/helpers/helper'

module BuildingSync
  # Generator class that generates basic data that is used mostly for testing
  class Generator
    include BuildingSync::Helper
    # @param version [String] version of BuildingSync
    def initialize(ns = 'auc', version = '2.4.0')
      supported_versions = ['2.0', '2.2.0', '2.4.0']
      if !supported_versions.include? version
        @version = nil
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Generator.initialize', "The version: #{version} is not one of the supported versions: #{supported_versions}")
      else
        @version = version
      end
      @ns = ns
    end

    # Starts from scratch and creates all necessary elements up to and including an
    #  - Sites/Site/Buildings/Building/Sections/Section
    #  - Reports/Report/Scenarios/Scenario
    # @return [String] string formatted XML document
    def create_bsync_root_to_building
      xml = Builder::XmlMarkup.new(indent: 2)
      auc_ns = 'http://buildingsync.net/schemas/bedes-auc/2019'
      location = "https://raw.githubusercontent.com/BuildingSync/schema/v#{@version}/BuildingSync.xsd"
      xml.instruct! :xml
      xml.tag!("#{@ns}:BuildingSync",
               :"xmlns:#{@ns}" => auc_ns,
               :"xsi:schemaLocation" => "#{auc_ns} #{location}",
               :"xmlns:xsi" => 'http://www.w3.org/2001/XMLSchema-instance',
               :version => @version.to_s) do |buildsync|

        buildsync.tag!("#{@ns}:Facilities") do |faclts|
          faclts.tag!("#{@ns}:Facility", ID: 'Facility1') do |faclt|
            faclt.tag!("#{@ns}:Sites") do |sites|
              sites.tag!("#{@ns}:Site", ID: 'Site1') do |site|
                site.tag!("#{@ns}:Buildings") do |builds|
                  builds.tag!("#{@ns}:Building", ID: 'Building1') do |build|
                  end
                end
              end
            end
          end
        end
      end
    end

    def get_or_create_linked_premises(element_xml)
      linked_premises_xml = help_get_or_create(element_xml, "#{@ns}:LinkedPremises")
      return linked_premises_xml
    end

    def add_linked_premise_of_type(premise_type_xml, premise_type, id)
      linked_xml = REXML::Element.new("#{@ns}:Linked#{premise_type}ID", premise_type_xml)
      linked_xml.add_attribute('IDref', id)
      return linked_xml
    end

    def get_or_create_premise_of_type(premise_xml, premise_type)
      premise_type_xml = help_get_or_create(premise_xml, "#{@ns}:#{premise_type}")
      return premise_type_xml
    end

    def add_linked_premise(base_xml, id, premise_type)
      linked_premises_xml = get_or_create_linked_premises(base_xml)
      premise_type_xml = get_or_create_premise_of_type(linked_premises_xml, premise_type)
      add_linked_premise_of_type(premise_type_xml, premise_type, id)
      return linked_premises_xml
    end

    def add_linked_building(base_xml, id)
      add_linked_premise(base_xml, id, 'Building')
    end

    def add_linked_section(base_xml, id)
      add_linked_premise(base_xml, id, 'Section')
    end

    # @see add_hvac_system_to_facility
    def add_hvac_system_to_first_facility(doc, id = 'HVACSystem-1', principal_hvac_system_type = nil)
      facility_xml = get_first_facility_element(doc)
      return add_hvac_system_to_facility(facility_xml, id, principal_hvac_system_type)
    end

    # @see add_lighting_system_to_facility
    def add_lighting_system_to_first_facility(doc, id = 'LightingSystem-1')
      facility_xml = get_first_facility_element(doc)
      return add_lighting_system_to_facility(facility_xml, id)
    end

    # @see add_plug_load_to_facility
    def add_plug_load_to_first_facility(doc, id = 'PlugLoad-1')
      facility_xml = get_first_facility_element(doc)
      return add_plug_load_to_facility(facility_xml, id)
    end

    # Adds hvac system with id.  also adds principal hvac element if specified
    # @see get_or_create_system_of_type
    # @param facility_xml [REXML::Element]
    # @param id [String]
    def add_hvac_system_to_facility(facility_xml, id = 'HVACSystem-1', principal_hvac_system_type = nil)
      systems_xml = get_or_create_systems(facility_xml)
      hvac_system_xml = get_or_create_system_of_type(systems_xml, 'HVACSystem')

      hvac_system_xml.add_attribute('ID', id)
      if !principal_hvac_system_type.nil?
        principal_xml = REXML::Element.new("#{@ns}:PrincipalHVACSystemType", hvac_system_xml)
        principal_xml.text = principal_hvac_system_type
      end
      return hvac_system_xml
    end

    # Adds lighting system with id.  wrapper around:
    # @see get_or_create_system_of_type
    # @param facility_xml [REXML::Element]
    # @param id [String]
    def add_lighting_system_to_facility(facility_xml, id = 'LightingSystem-1')
      systems_xml = get_or_create_systems(facility_xml)
      lighting_system_xml = get_or_create_system_of_type(systems_xml, 'LightingSystem')
      lighting_system_xml.add_attribute('ID', id)
      return lighting_system_xml
    end

    # Adds plug load with id.  wrapper around:
    # @see get_or_create_system_of_type
    # @param facility_xml [REXML::Element]
    # @param id [String]
    def add_plug_load_to_facility(facility_xml, id = 'PlugLoad-1')
      systems_xml = get_or_create_systems(facility_xml)
      new_system_xml = get_or_create_system_of_type(systems_xml, 'PlugLoad')
      new_system_xml.add_attribute('ID', id)
      return new_system_xml
    end

    # Create new system without id. Will check for pluralized version and create if not there,
    # else gets existing pluralized version and adds new singular as child.
    # @example:
    #   systems_xml = <auc:Systems/>
    #   system_type = HVACSystem
    #   returns <auc:Systems><auc:HVACSystems><auc:HVACSystem/></..></..>
    # @example:
    #   systems_xml = <auc:Systems><auc:HVACSystems/></..>
    #   system_type = HVACSystem
    #   returns <auc:System><auc:HVACSystems><auc:HVACSystem/></..></..>
    # @param systems_xml [REXML::Element] pass the auc:Systems element
    # @param system_type [String] a valid BSync system type: HVACSystem, LightingSystem, etc.
    def get_or_create_system_of_type(systems_xml, system_type)
      new_systems_xml = help_get_or_create(systems_xml, "#{@ns}:#{system_type}s")
      new_system_xml = REXML::Element.new("#{@ns}:#{system_type}", new_systems_xml)
      return new_system_xml
    end

    # Get or create <auc:Systems/> from <auc:Facility>...</..>
    def get_or_create_systems(facility_xml)
      return help_get_or_create(facility_xml, "#{@ns}:Systems")
    end

    def add_section_to_first_building(doc, id = 'Section-1')
      building_xml = get_first_building_element(doc)
      sections_xml = help_get_or_create(building_xml, "#{@ns}:Sections")
      section = REXML::Element.new("#{@ns}:Section", sections_xml)
      section.add_attribute('ID', id)
      return section
    end

    def add_energy_resource_use_to_scenario(scenario_xml, energy_resource_type = 'Electricity', end_use = 'All end uses', id = 'ResourceUse-1', native_units = nil)
      resource_uses = help_get_or_create(scenario_xml, "#{@ns}:ResourceUses")

      # Define ResourceUse and add ID
      resource_use = REXML::Element.new("#{@ns}:ResourceUse", resource_uses)
      resource_use.add_attribute('ID', id)

      # Add ResourceUnits
      if !native_units.nil?
        nu = REXML::Element.new("#{@ns}:ResourceUnits", resource_use)
        nu.text = native_units
      end

      # Add EnergyResource
      energy_resource = REXML::Element.new("#{@ns}:EnergyResource", resource_use)
      energy_resource.text = energy_resource_type

      # Add EndUse
      eu = REXML::Element.new("#{@ns}:EndUse", resource_use)
      eu.text = end_use
      return resource_use
    end

    def add_all_resource_total_to_scenario(scenario_xml, end_use = 'All end uses', id = 'AllResourceTotal-1')
      all_resource_totals = help_get_or_create(scenario_xml, "#{@ns}:AllResourceTotals")

      all_resource_total = REXML::Element.new("#{@ns}:AllResourceTotal", all_resource_totals)
      all_resource_total.add_attribute('ID', id)
      eu = REXML::Element.new("#{@ns}:EndUse", all_resource_total)
      eu.text = end_use

      return all_resource_total
    end

    def add_time_series_to_scenario(scenario_xml, id = 'TimeSeries-1')
      time_series_data = help_get_or_create(scenario_xml, "#{@ns}:TimeSeriesData")
      time_series = REXML::Element.new("#{@ns}:TimeSeries", time_series_data)
      time_series.add_attribute('ID', id)
      return time_series
    end

    # @param doc [REXML::Document]
    # @param scenario_type [String] see add_scenario_type_to_scenario
    # @param id [String] id for the new scenario
    # @return [REXML::Element] newly added scenario
    def add_scenario_to_first_report(doc, scenario_type = nil, id = 'Scenario-1')
      report = doc.get_elements(".//#{@ns}:Reports/#{@ns}:Report").first
      return add_scenario_to_report(report, scenario_type, id)
    end

    # Add a Scenario element to the Report XML element provided.
    # If auc:Scenarios does not exist, this is added as well
    # @param report_xml [REXML::Element] an XML element of auc:Report
    # @param scenario_type [String] see add_scenario_type_to_scenario
    # @param id [String] id of the Scenario element to add
    # @return [REXML::Element] the newly created Scenario element
    def add_scenario_to_report(report_xml, scenario_type = nil, id = 'Scenario-1')
      scenarios = report_xml.get_elements("./#{@ns}:Scenarios").first
      if scenarios.nil?
        scenarios = REXML::Element.new("#{@ns}:Scenarios", report_xml)
      end
      scenario = REXML::Element.new("#{@ns}:Scenario", scenarios)
      scenario.add_attribute('ID', id)
      return add_scenario_type_to_scenario(scenario, scenario_type)
    end

    # Add a Report element to the first Facility in the doc.
    # If auc:Reports does not exist, this is added as well
    # @param doc [REXML::Document] a buildingsync document with atleast an auc:Facility
    # @param id [String] id of the Report element to add
    # @return [REXML::Element] the newly created Report element
    def add_report_to_first_facility(doc, id = 'Report-1')
      facility_xml = doc.get_elements(".//#{@ns}:Facilities/#{@ns}:Facility").first
      reports = help_get_or_create(facility_xml, "#{@ns}:Reports")
      report = REXML::Element.new("#{@ns}:Report", reports)
      report.add_attribute('ID', id)
      return report
    end

    # Add a specific scenario type to the provided scenario element
    # @param scenario_element [REXML::Element]
    # @param scenario_type [String] one of: ['CBMeasured', 'CBModeled', 'POM', 'Benchmark', 'Target']
    # @return [REXML::Element] Scenario element
    def add_scenario_type_to_scenario(scenario_element, scenario_type)
      scenario_type_element = REXML::Element.new("#{@ns}:ScenarioType", scenario_element)
      if scenario_type.nil?
        return scenario_element
      elsif scenario_type == 'CBMeasured'
        cb_element = REXML::Element.new("#{@ns}:CurrentBuilding", scenario_type_element)
        cm_element = REXML::Element.new("#{@ns}:CalculationMethod", cb_element)
        measured = REXML::Element.new("#{@ns}:Measured", cm_element)
      elsif scenario_type == 'CBModeled'
        cb_element = REXML::Element.new("#{@ns}:CurrentBuilding", scenario_type_element)
        cm_element = REXML::Element.new("#{@ns}:CalculationMethod", cb_element)
        modeled = REXML::Element.new("#{@ns}:Modeled", cm_element)
      elsif scenario_type == 'POM'
        pom = REXML::Element.new("#{@ns}:PackageOfMeasures", scenario_type_element)
      elsif scenario_type == 'Benchmark'
        benchmark = REXML::Element.new("#{@ns}:Benchmark", scenario_type_element)
      elsif scenario_type == 'Target'
        target = REXML::Element.new("#{@ns}:Target", scenario_type_element)
      end
      return scenario_element
    end

    # creates a minimum building sync snippet
    # @param occupancy_classification [String]
    # @param year_of_const [Integer]
    # @param floor_area_type [String]
    # @param floor_area_value [Float]
    # @param ns [String]
    # @return REXML::Document
    def create_minimum_snippet(occupancy_classification, year_of_const = 2000, floor_area_type = 'Gross', floor_area_value = 1000, floors_above_grade = 1)
      doc_string = create_bsync_root_to_building
      doc = REXML::Document.new(doc_string)

      facility_element = doc.elements["/#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility"]
      site_element = facility_element.elements["#{@ns}:Sites/#{@ns}:Site"]
      building_element = site_element.elements["#{@ns}:Buildings/#{@ns}:Building"]

      # Add Facility info
      report_element = add_report_to_first_facility(doc)
      junk = add_scenario_to_report(report_element, 'CBModeled')

      # Add Site info
      occupancy_classification_element = REXML::Element.new("#{@ns}:OccupancyClassification", site_element)
      occupancy_classification_element.text = occupancy_classification

      # Add Building info
      year_of_construction_element = REXML::Element.new("#{@ns}:YearOfConstruction", building_element)
      year_of_construction_element.text = year_of_const
      floor_areas_element = REXML::Element.new("#{@ns}:FloorAreas", building_element)
      floor_area_element = REXML::Element.new("#{@ns}:FloorArea", floor_areas_element)
      floor_area_type_element = REXML::Element.new("#{@ns}:FloorAreaType", floor_area_element)
      floor_area_type_element.text = floor_area_type
      floor_area_value_element = REXML::Element.new("#{@ns}:FloorAreaValue", floor_area_element)
      floor_area_value_element.text = floor_area_value
      floors_above_grade_element = REXML::Element.new("#{@ns}:FloorsAboveGrade", building_element)
      floors_above_grade_element.text = floors_above_grade
      occupancy_classification_element = REXML::Element.new("#{@ns}:OccupancyClassification", building_element)
      occupancy_classification_element.text = occupancy_classification

      return doc
    end

    # creates a minimum facility
    # @param occupancy_classification [String]
    # @param year_of_const [Integer]
    # @param floor_area_type [String]
    # @param floor_area_value [Float]
    # @return BuildingSync::Facility
    def create_minimum_facility(occupancy_classification, year_of_const, floor_area_type, floor_area_value, floors_above_grade = 1)
      xml_snippet = create_minimum_snippet(occupancy_classification, year_of_const, floor_area_type, floor_area_value, floors_above_grade)
      facility_element = xml_snippet.elements["/#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility"]
      if !facility_element.nil?
        return BuildingSync::Facility.new(facility_element, @ns)
      else
        expect(facility_element.nil?).to be false
      end
    end

    # create minimum site
    # @param occupancy_classification [String]
    # @param year_of_const [Integer]
    # @param floor_area_type [String]
    # @param floor_area_value [Float]
    # @return [BuildingSync::Site]
    def create_minimum_site(occupancy_classification, year_of_const, floor_area_type, floor_area_value)
      xml_snippet = create_minimum_snippet(occupancy_classification, year_of_const, floor_area_type, floor_area_value)
      site_element = xml_snippet.elements["/#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility/#{@ns}:Sites/#{@ns}:Site"]
      if !site_element.nil?
        return BuildingSync::Site.new(site_element, @ns)
      else
        expect(site_element.nil?).to be false
      end
    end

    def create_minimum_building(occupancy_classification, year_of_const, floor_area_type, floor_area_value)
      xml_snippet = create_minimum_snippet(occupancy_classification, year_of_const, floor_area_type, floor_area_value)

      building_element = xml_snippet.elements["/#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility/#{@ns}:Sites/#{@ns}:Site/#{@ns}:Buildings/#{@ns}:Building"]
      if !building_element.nil?
        return BuildingSync::Building.new(building_element, '', '', @ns)
      else
        expect(building_element.nil?).to be false
      end
    end

    def create_minimum_section_xml(typical_usage_hours = 40)
      section = REXML::Element.new("#{@ns}:Section")
      # adding the XML elements for the typical hourly usage per week
      typical_usages = REXML::Element.new("#{@ns}:TypicalOccupantUsages")
      section.add_element(typical_usages)
      typical_usage = REXML::Element.new("#{@ns}:TypicalOccupantUsage")
      typical_usages.add_element(typical_usage)
      typical_usage_unit = REXML::Element.new("#{@ns}:TypicalOccupantUsageUnits")
      typical_usage_unit.text = 'Hours per week'
      typical_usage.add_element(typical_usage_unit)
      typical_usage_value = REXML::Element.new("#{@ns}:TypicalOccupantUsageValue")
      typical_usage_value.text = typical_usage_hours
      typical_usage.add_element(typical_usage_value)
      return section
    end

    # -- Generate Baseline functions
    def generate_baseline_facilities(xml_path)
      facilities = []
      doc = help_load_doc(xml_path)

      doc.elements.each("#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility") do |facility_element|
        facilities.push(BuildingSync::Facility.new(facility_element, @ns))
      end
      return facilities
    end

    def generate_baseline_sites(xml_path)
      sites = []
      doc = help_load_doc(xml_path)
      facility_xml = get_first_facility_element(doc)

      facility_xml.elements.each("#{@ns}:Sites/#{@ns}:Site") do |site_element|
        sites.push(BuildingSync::Site.new(site_element, @ns))
      end
      return sites
    end

    def generate_baseline_buildings(xml_path, occupancy_classification, total_floor_area)
      buildings = []

      doc = help_load_doc(xml_path)
      site_xml = get_first_site_element(doc)

      site_xml.elements.each("#{@ns}:Buildings/#{@ns}:Building") do |building_element|
        buildings.push(BuildingSync::Building.new(building_element, occupancy_classification, total_floor_area, @ns))
      end
      return buildings
    end

    def generate_baseline_building_sections(xml_path, occupancy_classification, total_floor_area)
      building_sections = []

      doc = help_load_doc(xml_path)
      building_xml = get_first_building_element(doc)

      building_xml.elements.each("#{@ns}:Sections/#{@ns}:Section") do |building_element|
        building_sections.push(BuildingSync::BuildingSection.new(building_element, occupancy_classification, total_floor_area, 1, @ns))
      end
      return building_sections
    end

    def get_first_facility_element(doc)
      facility = doc.get_elements("#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility").first
      return facility
    end

    def get_first_site_element(doc)
      site = doc.get_elements("/#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility/#{@ns}:Sites/#{@ns}:Site").first
      return site
    end

    def get_first_building_element(doc)
      building = doc.get_elements("/#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility/#{@ns}:Sites/#{@ns}:Site/#{@ns}:Buildings/#{@ns}:Building").first
      return building
    end

    def get_first_building_section_element(doc)
      section = doc.get_elements("/#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility/#{@ns}:Sites/#{@ns}:Site/#{@ns}:Buildings/#{@ns}:Building/#{@ns}:Sections/#{@ns}:Section").first
      return section
    end

    def get_first_report_element(doc)
      report = doc.get_elements("/#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility/#{@ns}:Reports/#{@ns}:Report").first
      return report
    end

    def get_first_scenario_element(doc)
      scenario = doc.get_elements("/#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility/#{@ns}:Reports/#{@ns}:Report/#{@ns}:Scenarios/#{@ns}:Scenario").first
      return scenario
    end

    def get_first_utility_element(doc)
      scenario = doc.get_elements("/#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility/#{@ns}:Reports/#{@ns}:Report/#{@ns}:Utilities/#{@ns}:Utility").first
      return scenario
    end

    def get_first_hvac_system_element(doc)
      scenario = doc.get_elements("/#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility/#{@ns}:Systems/#{@ns}:HVACSystems/#{@ns}:HVACSystem").first
      return scenario
    end

    def get_utility_from_file(xml_file_path)
      doc = nil
      File.open(xml_file_path, 'r') do |file|
        doc = REXML::Document.new(file)
      end
      report = get_first_utility_element(doc)
      return BuildingSync::Utility.new(report, @ns)
    end

    def get_report_from_file(xml_file_path)
      doc = nil
      File.open(xml_file_path, 'r') do |file|
        doc = REXML::Document.new(file)
      end
      report = get_first_report_element(doc)
      return BuildingSync::Report.new(report, @ns)
    end

    def get_facility_from_file(xml_file_path)
      doc = nil
      File.open(xml_file_path, 'r') do |file|
        doc = REXML::Document.new(file)
      end
      facility = get_first_facility_element(doc)
      return BuildingSync::Facility.new(facility, @ns)
    end

    def get_building_from_file(xml_file_path)
      doc = nil
      File.open(xml_file_path, 'r') do |file|
        doc = REXML::Document.new(file)
      end
      building = get_first_building_element(doc)
      return BuildingSync::Building.new(building, 'Office', '20000', @ns)
    end

    def get_building_section_from_file(xml_file_path)
      doc = nil
      File.open(xml_file_path, 'r') do |file|
        doc = REXML::Document.new(file)
      end
      section = get_first_building_section_element(doc)
      return BuildingSync::BuildingSection.new(section, 'Office', '20000', 1, @ns)
    end

    # get hvac system from xml file
    # @param xml_file_name [String]
    # @param standard_to_be_used [String]
    # @return [BuildingSync::HVACSystem]
    def get_hvac_system_from_file(xml_file_path)
      doc = nil
      File.open(xml_file_path, 'r') do |file|
        doc = REXML::Document.new(file)
      end
      hvac_system = get_first_hvac_system_element(doc)
      return BuildingSync::HVACSystem.new(hvac_system, @ns)
    end

    # create and return the set of elements:
    #   auc:CalculationMethod/auc:Modeled/
    #     auc:SoftwareProgramUsed = OpenStudio
    #     auc:SoftwareProgramVersion = ...
    #     auc:WeatherDataType = TMY
    #     auc:SimulationCompletionStatus = Success or Failed, depending on result[:completion_status]
    # @param result [hash] must have key: result[:completed_status]
    # @return [REXML::Element]
    def create_calculation_method_element(result)
      calc_method = REXML::Element.new("#{@ns}:CalculationMethod")
      modeled = REXML::Element.new("#{@ns}:Modeled", calc_method)
      software_program_used = REXML::Element.new("#{@ns}:SoftwareProgramUsed", modeled)
      software_program_used.text = 'OpenStudio'

      software_program_version = REXML::Element.new("#{@ns}:SoftwareProgramVersion", modeled)
      software_program_version.text = OpenStudio.openStudioLongVersion.to_s

      weather_data_type = REXML::Element.new("#{@ns}:WeatherDataType", modeled)
      weather_data_type.text = 'TMY3'

      sim_completion_status = REXML::Element.new("#{@ns}:SimulationCompletionStatus", modeled)
      sim_completion_status.text = result[:completed_status] == 'Success' ? 'Finished' : 'Failed'

      return calc_method
    end

    attr_reader :version
  end
end
