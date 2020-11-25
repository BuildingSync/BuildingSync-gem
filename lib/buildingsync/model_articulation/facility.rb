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
require 'openstudio/extension/core/os_lib_geometry'

require 'buildingsync/helpers/helper'
require 'buildingsync/helpers/xml_get_set'
require 'buildingsync/helpers/Model.hvac'
require 'buildingsync/helpers/metered_energy'

require_relative 'site'
require_relative 'loads_system'
require_relative 'envelope_system'
require_relative 'hvac_system'
require_relative 'service_hot_water_system'
require_relative 'measure'

module BuildingSync
  # Facility class
  class Facility
    include OsLib_Geometry
    include BuildingSync::Helper
    include BuildingSync::XmlGetSet
    # initialize
    # @param base_xml [REXML:Element]
    # @param ns [String]
    def initialize(base_xml, ns)
      @base_xml = base_xml
      @ns = ns
      @g = BuildingSync::Generator.new(ns)

      help_element_class_type_check(base_xml, 'Facility')

      @report_xml = nil
      @site_xml = nil

      @site = nil
      @scenarios = []
      @measures = []
      @cb_modeled = nil
      @cb_measured = []
      @poms = []
      @systems = {}
      # @hvac_systems = []
      # @loads_systems = []
      # @lighting_systems = []
      @contacts = []
      
      @auditor_contact_id = nil
      @audit_date_level_1 = nil
      @audit_date_level_2 = nil
      @audit_date_level_3 = nil
      @contact_auditor_name = nil
      @contact_owner_name = nil
      @utility_name = nil
      @utility_meter_numbers = []
      @metering_configuration = nil
      @rate_schedules_xml = []
      @interval_reading_monthly = []
      @interval_reading_yearly = []
      @spaces_excluded_from_gross_floor_area = nil
      @premises_notes_for_not_applicable = nil

      # parameter to read and write.
      @energy_resource = nil
      @benchmark_tool = nil
      @building_eui = nil
      @building_eui_benchmark = nil
      @energy_cost = nil
      @annual_fuel_use_native_units = nil

      @load_system = nil
      @hvac_system = nil

      # reading the xml
      read_xml
    end

    # read xml
    def read_xml

      # Site - checks
      site_xml_temp = @base_xml.get_elements("#{@ns}:Sites/#{@ns}:Site")
      if site_xml_temp.nil? || site_xml_temp.empty?
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Facility.read_xml', "Facility ID: #{xget_id} has no Site elements.  Cannot initialize Facility.")
        raise StandardError, "Facility with ID: #{xget_id} has no Site elements.  Cannot initialize Facility."
      elsif site_xml_temp.size > 1
        @site_xml = site_xml_temp.first()
        OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Facility.read_xml', "Facility ID: #{xget_id}. There is more than one (#{site_xml_temp.size}) Site elements. Only the first Site will be considered (ID: #{@site_xml.attributes['ID']}")
      else
        @site_xml = site_xml_temp.first()
      end
      # Create new Site
      @site = BuildingSync::Site.new(@site_xml, @ns)

      # Report - checks
      report_xml_temp = @base_xml.get_elements("#{@ns}:Reports/#{@ns}:Report")
      if report_xml_temp.nil? || report_xml_temp.empty?
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Facility.read_xml', "Facility with ID: #{xget_id} has no Report elements.  Cannot initialize Facility.")
        raise StandardError, "Facility with ID: #{xget_id} has no Report elements.  Cannot initialize Facility."
      elsif report_xml_temp.size > 1
        @report_xml = report_xml_temp.first()
        OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Facility.read_xml', "There are more than one (#{report_xml_temp.size}) Report elements in your BuildingSync file. Only the first Report will be considered (ID: #{@report_xml.attributes['ID']}")
      else
        @report_xml = report_xml_temp.first()
      end

      scenarios_xml_temp = @report_xml.get_elements("#{@ns}:Scenarios/#{@ns}:Scenario")
      measures_xml_temp = @base_xml.get_elements("#{@ns}:Measures/#{@ns}:Measure")

      # Scenarios - create and checks
      cb_modeled = []
      if !scenarios_xml_temp.nil?
        scenarios_xml_temp.each do |scenario_xml|
          if scenario_xml.is_a? REXML::Element
            sc = BuildingSync::Scenario.new(scenario_xml, @ns)
            @scenarios.push(sc)
            cb_modeled << sc if sc.cb_modeled?
            @cb_measured << sc if sc.cb_measured?
            @poms << sc if sc.pom?
          end
        end
      end

      # Measures - create
      if !measures_xml_temp.nil?
        measures_xml_temp.each do |measure_xml|
          if measure_xml.is_a? REXML::Element
            @measures.push(BuildingSync::Measure.new(measure_xml, @ns))
          end
        end
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.read_xml', "Facility with ID: #{xget_id} has #{@measures.size} Measure Objects")
      end

      # -- Issue warnings for undesirable situations
      if @scenarios.empty?
        OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Facility.read_xml', "No Scenario elements found")
      end

      # -- Logging for Scenarios
      if cb_modeled.size == 0
        OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Facility.read_xml', "A Current Building Modeled Scenario is required.")
      elsif cb_modeled.size > 1
        @cb_modeled = cb_modeled[0]
        OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Facility.read_xml', "Only 1 Current Building Modeled Scenario is supported.  Using Scenario with ID: #{@cb_modeled.xget_id}")
      else
        @cb_modeled = cb_modeled[0]
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.read_xml', "Current Building Modeled Scenario has ID: #{@cb_modeled.xget_id}")
      end

      read_other_details
      read_interval_reading
      read_systems
    end

    # set_all wrapper for Site
    def set_all
      @site.set_all
    end

    # determine open studio standard
    # @param standard_to_be_used [String]
    # @return [Standard]
    def determine_open_studio_standard(standard_to_be_used)
      return @site.determine_open_studio_standard(standard_to_be_used)
    end

    # generating the OpenStudio model based on the imported BuildingSync Data
    # @param epw_file_path [String]
    # @param output_path [String]
    # @param standard_to_be_used [String]
    # @param ddy_file [String]
    # @return [Boolean]
    def generate_baseline_osm(epw_file_path, output_path, standard_to_be_used, ddy_file = nil)

      @site.generate_baseline_osm(epw_file_path, standard_to_be_used, ddy_file)

      @epw_file_path = @site.get_epw_file_path
      zone_hash = build_zone_hash(@site)
      create_building_systems(output_path, zone_hash)
      return true
    end

    # build zone hash
    # @param site [BuildingSync::Site]
    # @return [Hash]
    def build_zone_hash(site)
      return site.build_zone_hash
    end

    # get sites
    # return [BuildingSync::Site]
    def get_site
      return @site
    end

    # get space types
    # @return [Array<OpenStudio::Model::SpaceType>]
    def get_space_types
      return @site.get_space_types
    end

    # get epw_file_path
    # @return [String]
    def get_epw_file_path
      @site.get_epw_file_path
    end

    def get_measure_given_id(measure_id)
      @measures.each do |measure|

      end
    end

    # determine OpenStudio system standard
    # @return [Standard]
    def determine_open_studio_system_standard
      return @site.determine_open_studio_system_standard
    end

    # read interval reading
    def read_interval_reading
      interval_frequency = ''
      reading_type = ''
      interval_reading = ''
      if @base_xml.elements["#{@ns}:Reports/#{@ns}:Report/#{@ns}:Scenarios/#{@ns}:Scenario/#{@ns}:ResourceUses/#{@ns}:ResourceUse/#{@ns}:EnergyResource"]
        @energy_resource = @base_xml.elements["#{@ns}:Reports/#{@ns}:Report/#{@ns}:Scenarios/#{@ns}:Scenario/#{@ns}:ResourceUses/#{@ns}:ResourceUse/#{@ns}:EnergyResource"].text
      else
        @energy_resource = nil
      end

      if @base_xml.elements["#{@ns}:Reports/#{@ns}:Report/#{@ns}:Scenarios/#{@ns}:Scenario/#{@ns}:TimeSeriesData/#{@ns}:TimeSeriesType/#{@ns}:IntervalFrequency"]
        interval_frequency = @base_xml.elements["#{@ns}:Reports/#{@ns}:Report/#{@ns}:Scenarios/#{@ns}:Scenario/#{@ns}:TimeSeriesData/#{@ns}:TimeSeriesType/#{@ns}:IntervalFrequency"].text
      end

      if @base_xml.elements["#{@ns}:Reports/#{@ns}:Report/#{@ns}:Scenarios/#{@ns}:Scenario/#{@ns}:TimeSeriesData/#{@ns}:TimeSeriesType/#{@ns}:ReadingType"]
        reading_type = @base_xml.elements["#{@ns}:Reports/#{@ns}:Report/#{@ns}:Scenarios/#{@ns}:Scenario/#{@ns}:TimeSeriesData/#{@ns}:TimeSeriesType/#{@ns}:ReadingType"].text
      end

      if @base_xml.elements["#{@ns}:Reports/#{@ns}:Report/#{@ns}:Scenarios/#{@ns}:Scenario/#{@ns}:TimeSeriesData/#{@ns}:TimeSeriesType/#{@ns}:IntervalReading"]
        interval_reading = @base_xml.elements["#{@ns}:Reports/#{@ns}:Report/#{@ns}:Scenarios/#{@ns}:Scenario/#{@ns}:TimeSeriesData/#{@ns}:TimeSeriesType/#{@ns}:IntervalReading"].text
      end

      if interval_frequency == 'Month'
        @interval_reading_monthly.push(MeteredEnergy.new(@energy_resource, interval_frequency, reading_type, interval_reading))
      elsif interval_frequency == 'Year'
        @interval_reading_yearly.push(MeteredEnergy.new(@energy_resource, interval_frequency, reading_type, interval_reading))
      end
    end

    # read systems
    def read_systems
      systems_xml = @base_xml.elements["#{@ns}:Systems"]
      if !systems_xml.nil? && !systems_xml.empty?
        systems_xml.elements.each do |system_type|
          @systems[system_type.name] = []
          system_type.elements.each do |system|
            @systems[system_type.name] << system
          end
        end
        # @load_system = LoadsSystem.new(systems_xml.elements["#{@ns}:PlugLoads"], @ns)
        # @hvac_system = HVACSystem.new(systems_xml.elements["#{@ns}:HVACSystems"], @ns)
      else
        @load_system = LoadsSystem.new
        hvac_xml = @g.add_hvac_system_to_facility(@base_xml)
        @hvac_system = HVACSystem.new(hvac_xml, @ns)
      end
    end

    # read other details from the xml
    # - contact information
    # - audit levels and dates
    # - Utility information
    # - UDFs
    def read_other_details

      # Get Contact information
      @base_xml.elements.each("#{@ns}:Contacts/#{@ns}:Contact") do |contact|
        contact.elements.each("#{@ns}:ContactRoles/#{@ns}:ContactRole") do |role|
          if role.text == 'Energy Auditor'
            @contact_auditor_name = contact.elements["#{@ns}:ContactName"].text
          elsif role.text == 'Owner'
            @contact_owner_name = contact.elements["#{@ns}:ContactName"].text
          end
        end
      end
      auditor_contact_id_element = @report_xml.elements["#{@ns}:AuditorContactID"]

      # Audit Level
      audit_level = @report_xml.elements["#{@ns}:ASHRAEAuditLevel"]
      if !audit_level.nil?
        @audit_level = help_get_text_value(audit_level)
      end
      if !auditor_contact_id_element.nil?
        @auditor_contact_id = help_get_attribute_value(auditor_contact_id_element, 'IDref')
      end

      # Audit dates
      audit_dates = @report_xml.get_elements("#{@ns}:AuditDates/#{@ns}:AuditDate")
      if !audit_dates.nil? && !@audit_level.nil?
        audit_dates.each do |audit_date|
          if @audit_level == 'Level 1: Walk-through'
            @audit_date_level_1 = help_get_text_value_as_date(audit_date.elements["#{@ns}:Date"])
            @audit_date = @audit_date_level_1
          elsif @audit_level == 'Level 2: Energy Survey and Analysis'
            @audit_date_level_2 = help_get_text_value_as_date(audit_date.elements["#{@ns}:Date"])
            @audit_date = @audit_date_level_2
          elsif @audit_level == 'Level 3: Detailed Survey and Analysis'
            @audit_date_level_3 = help_get_text_value_as_date(audit_date.elements["#{@ns}:Date"])
            @audit_date = @audit_date_level_3
          end
        end
      end

      # Read Utility Information
      utilities = @report_xml.elements["#{@ns}:Utilities"]
      if utilities
        utilities.elements.each("#{@ns}:Utility") do |utility|
          @utility_name = help_get_text_value(utility.elements["#{@ns}:UtilityName"])
          @metering_configuration = help_get_text_value(utility.elements["#{@ns}:MeteringConfiguration"])
          meter_numbers = utility.get_elements("#{@ns}:UtilityMeterNumbers/#{@ns}:UtilityMeterNumber")
          rate_schedules = utility.get_elements("#{@ns}:RateSchedules/#{@ns}:RateSchedule")
          if meter_numbers
            meter_numbers.each do |mn|
              @utility_meter_numbers << help_get_text_value(mn)
            end
          end
          if rate_schedules
            rate_schedules.each do |rs|
              @rate_schedules_xml << rs
            end
          end
        end
      end

      # Read UDFs
      @report_xml.elements.each("#{@ns}:UserDefinedFields/#{@ns}:UserDefinedField") do |user_defined_field|
        if user_defined_field.elements["#{@ns}:FieldName"].text == 'Audit Notes'
          @audit_notes = user_defined_field.elements["#{@ns}:FieldValue"].text
        elsif user_defined_field.elements["#{@ns}:FieldName"].text == 'Audit Team Notes'
          @audit_team_notes = user_defined_field.elements["#{@ns}:FieldValue"].text
        elsif user_defined_field.elements["#{@ns}:FieldName"].text == 'Auditor Years Of Experience'
          @auditor_years_experience = user_defined_field.elements["#{@ns}:FieldValue"].text
        elsif user_defined_field.elements["#{@ns}:FieldName"].text == 'Spaces Excluded From Gross Floor Area'
          @spaces_excluded_from_gross_floor_area = user_defined_field.elements["#{@ns}:FieldValue"].text
        elsif user_defined_field.elements["#{@ns}:FieldName"].text == 'Premises Notes For Not Applicable'
          @premises_notes_for_not_applicable = user_defined_field.elements["#{@ns}:FieldValue"].text
        end
      end

    end

    # create building systems
    # @param output_path [String]
    # @param zone_hash [Hash]
    # @param hvac_delivery_type [String]
    # @param htg_src [String]
    # @param clg_src [String]
    # @param add_space_type_loads [Boolean]
    # @param add_constructions [Boolean]
    # @param add_elevators [Boolean]
    # @param add_exterior_lights [Boolean]
    # @param add_exhaust [Boolean]
    # @param add_swh [Boolean]
    # @param add_hvac [Boolean]
    # @param add_thermostat [Boolean]
    # @param remove_objects [Boolean]
    def create_building_systems(output_path, zone_hash = nil, hvac_delivery_type = 'Forced Air', htg_src = 'NaturalGas', clg_src = 'Electricity',
                                add_space_type_loads = true, add_constructions = true, add_elevators = false, add_exterior_lights = false,
                                add_exhaust = true, add_swh = true, add_hvac = true, add_thermostat = true, remove_objects = false)
      model = @site.get_model
      template = @site.get_building_template
      system_type = @site.get_system_type
      climate_zone = @site.get_climate_zone

      onsite_parking_fraction = 1.0
      exterior_lighting_zone = '3 - All Other Areas'

      initial_objects = model.getModelObjects.size

      OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.create_building_system', "The building started with #{initial_objects} objects.")

      # TODO: systems_xml.elements["#{@ns}:LightingSystems"]
      # Make the open_studio_system_standard applier
      open_studio_system_standard = determine_open_studio_system_standard
      OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.create_building_system', "Building Standard with template: #{template}.")

      # add internal loads to space types
      if add_space_type_loads
        @load_system.add_internal_loads(model, open_studio_system_standard, template, @site.get_building_sections, remove_objects)
        new_occupancy_peak = @site.get_peak_occupancy
        new_occupancy_peak.each do |id, occupancy_peak|
          floor_area = @site.get_floor_area[id]
          if occupancy_peak && floor_area && floor_area > 0.0
            puts "new peak occupancy value found: absolute occupancy: #{occupancy_peak} occupancy per area: #{occupancy_peak.to_f / floor_area.to_f} and area: #{floor_area} m2"
            @load_system.adjust_occupancy_peak(model, occupancy_peak, floor_area, @site.get_space_types_from_hash(id))
          end
        end
      end

      # identify primary building type (used for construction, and ideally HVAC as well)
      building_types = {}
      model.getSpaceTypes.each do |space_type|
        # populate hash of building types
        if space_type.standardsBuildingType.is_initialized
          bldg_type = space_type.standardsBuildingType.get
          if !building_types.key?(bldg_type)
            building_types[bldg_type] = space_type.floorArea
          else
            building_types[bldg_type] += space_type.floorArea
          end
        else
          OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Facility.create_building_system', "Can't identify building type for #{space_type.name}")
        end
      end
      primary_bldg_type = building_types.key(building_types.values.max) # TODO: - this fails if no space types, or maybe just no space types with standards
      lookup_building_type = open_studio_system_standard.model_get_lookup_name(primary_bldg_type) # Used for some lookups in the standards gem
      model.getBuilding.setStandardsBuildingType(primary_bldg_type)

      envelope_system = nil
      # make construction set and apply to building
      if add_constructions
        envelope_system = EnvelopeSystem.new
        envelope_system.create(model, open_studio_system_standard, primary_bldg_type, lookup_building_type, remove_objects)
      end

      # add elevators (returns ElectricEquipment object)
      if add_elevators
        @load_system.add_elevator(model, open_studio_system_standard)
      end

      # add exterior lights (returns a hash where key is lighting type and value is exteriorLights object)
      if add_exterior_lights
        @load_system.add_exterior_lights(model, open_studio_system_standard, onsite_parking_fraction, exterior_lighting_zone, remove_objects)
      end

      # add_exhaust
      if add_exhaust
        @hvac_system.add_exhaust(model, open_studio_system_standard, 'Adjacent', remove_objects)
      end

      # add service water heating demand and supply
      if add_swh
        service_hot_water_system = ServiceHotWaterSystem.new
        service_hot_water_system.add(model, open_studio_system_standard, remove_objects)
      end

      @load_system.add_daylighting_controls(model, open_studio_system_standard, template)

      # TODO: - add internal mass
      # TODO: - add slab modeling and slab insulation
      # TODO: - fuel customization for cooking and laundry
      # TODO: - add refrigeration
      # remove refrigeration equipment
      if remove_objects
        model.getRefrigerationSystems.each(&:remove)
      end

      # works by switching some fraction of electric loads to gas if requested (assuming base load is electric)
      # add thermostats
      if add_thermostat
        @hvac_system.add_thermostats(model, open_studio_system_standard, remove_objects)
      end

      # add hvac system
      if add_hvac
        @hvac_system.add_hvac(model, zone_hash, open_studio_system_standard, system_type, hvac_delivery_type, htg_src, clg_src, remove_objects)
      end

      # set hvac controls and efficiencies (this should be last model articulation element)
      if add_hvac
        @hvac_system.apply_sizing_and_assumptions(model, output_path, open_studio_system_standard, primary_bldg_type, system_type, climate_zone)
      end

      # remove everything but spaces, zones, and stub space types (extend as needed for additional objects, may make bool arg for this)
      if remove_objects
        model.purgeUnusedResourceObjects
        objects_after_cleanup = initial_objects - model.getModelObjects.size
        if objects_after_cleanup > 0
          OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.create_building_system', "Removing #{objects_after_cleanup} objects from model")
        end
      end

      # report final condition of model
      OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.create_building_system', "The building finished with #{model.getModelObjects.size} objects.")
    end

    # write osm
    # @param dir [String]
    # @return [Array]
    def write_osm(dir)
      scenario_types = @site.determine_standard_perform_sizing_write_osm(dir)
      return scenario_types
    end

    # write parameters to xml
    def prepare_final_xml
      report = @base_xml.elements["#{@ns}:Reports/#{@ns}:Report"]
      report.elements.each("#{@ns}:Scenarios/#{@ns}:Scenario") do |scenario|
        scenario.elements["#{@ns}:ResourceUses/#{@ns}:ResourceUse/#{@ns}:EnergyResource"].text = @energy_resource if !@energy_resource.nil?
        scenario.elements["#{@ns}:ScenarioType/#{@ns}:Benchmark/#{@ns}:BenchmarkType/#{@ns}:Other"].text = @benchmark_tool if !@benchmark_tool.nil?
        scenario.elements["#{@ns}:AllResourceTotals/#{@ns}:AllResourceTotal/#{@ns}:SiteEnergyUseIntensity"].text = @building_eui if !@building_eui.nil?
        scenario.elements["#{@ns}:AllResourceTotals/#{@ns}:AllResourceTotal/#{@ns}:SiteEnergyUseIntensity"].text = @building_eui_benchmark if !@building_eui_benchmark.nil?
        scenario.elements["#{@ns}:AllResourceTotals/#{@ns}:AllResourceTotal/#{@ns}:EnergyCost"].text = @energy_cost if !@energy_cost.nil?
        scenario.elements["#{@ns}:ResourceUses/#{@ns}:ResourceUse/#{@ns}:AnnualFuelUseNativeUnits"].text = @annual_fuel_use_native_units if !@annual_fuel_use_native_units.nil?
      end
      @site.prepare_final_xml
    end

    # get OpenStudio model
    # @return [OpenStudio::Model]
    def get_model
      return @site.get_model
    end

    attr_reader :building_eui_benchmark, :building_eui, :auditor_contact_id, :annual_fuel_use_native_units, :audit_date, :benchmark_tool, :contact_auditor_name, :energy_cost, :energy_resource,
                :rate_schedules_xml, :utility_meter_numbers, :utility_name, :metering_configuration, :scenarios, :poms, :cb_modeled, :cb_measured, :measures
  end
end
