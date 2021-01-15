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
require 'openstudio/extension/core/os_lib_geometry'

require 'buildingsync/report'
require 'buildingsync/contact'
require 'buildingsync/helpers/helper'
require 'buildingsync/helpers/xml_get_set'
require 'buildingsync/helpers/Model.hvac'

require_relative 'site'
require_relative 'loads_system'
require_relative 'envelope_system'
require_relative 'hvac_system'
require_relative 'lighting_system'
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
      @report = nil

      @measures = []
      @contacts = []
      @systems_map = {}

      # TODO: Go under Report
      @utility_name = nil
      @utility_meter_numbers = []
      @metering_configuration = nil
      @spaces_excluded_from_gross_floor_area = nil

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
        @site_xml = site_xml_temp.first
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Facility.read_xml', "Facility ID: #{xget_id}. There is more than one (#{site_xml_temp.size}) Site elements. Only the first Site will be considered (ID: #{@site_xml.attributes['ID']}")
      else
        @site_xml = site_xml_temp.first
      end
      # Create new Site
      @site = BuildingSync::Site.new(@site_xml, @ns)

      # Report - checks
      report_xml_temp = @base_xml.get_elements("#{@ns}:Reports/#{@ns}:Report")
      if report_xml_temp.nil? || report_xml_temp.empty?
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Facility.read_xml', "Facility with ID: #{xget_id} has no Report elements.  Cannot initialize Facility.")
        raise StandardError, "Facility with ID: #{xget_id} has no Report elements.  Cannot initialize Facility."
      elsif report_xml_temp.size > 1
        @report_xml = report_xml_temp.first
        OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Facility.read_xml', "There are more than one (#{report_xml_temp.size}) Report elements in your BuildingSync file. Only the first Report will be considered (ID: #{@report_xml.attributes['ID']}")
      else
        @report_xml = report_xml_temp.first
      end
      # Create new Report
      @report = BuildingSync::Report.new(@report_xml, @ns)

      measures_xml_temp = @base_xml.get_elements("#{@ns}:Measures/#{@ns}:Measure")

      # Measures - create
      if !measures_xml_temp.nil?
        measures_xml_temp.each do |measure_xml|
          if measure_xml.is_a? REXML::Element
            @measures.push(BuildingSync::Measure.new(measure_xml, @ns))
          end
        end
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.read_xml', "Facility with ID: #{xget_id} has #{@measures.size} Measure Objects")
      end

      read_other_details
      read_and_create_initial_systems
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
      create_building_systems(main_output_dir: output_path, zone_hash: zone_hash, remove_objects: true)
      return true
    end

    # build zone hash
    # @param site [BuildingSync::Site]
    # @return [Hash]
    def build_zone_hash(site)
      return site.build_zone_hash
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

    # Get the ContactName specified by the AuditorContactID/@IDref
    # @return [String] if exists
    # @return [nil] if not
    def get_auditor_contact_name
      auditor_id = @report.get_auditor_contact_id
      if !auditor_id.nil?
        contact = @contacts.find { |contact| contact.xget_id == auditor_id}
        return contact.xget_text('ContactName')
      end
      return nil
    end

    # get OpenStudio model
    # @return [OpenStudio::Model]
    def get_model
      return @site.get_model
    end

    # determine OpenStudio system standard
    # @return [Standard]
    def determine_open_studio_system_standard
      return @site.determine_open_studio_system_standard
    end

    # read systems
    def read_and_create_initial_systems
      systems_xml = xget_or_create('Systems')
      if !systems_xml.elements.empty?
        systems_xml.elements.each do |system_type|
          @systems_map[system_type.name] = []
          system_type.elements.each do |system_xml|
            if system_xml.name == 'HVACSystem'
              @systems_map[system_type.name] << BuildingSync::HVACSystem.new(system_xml, @ns)
            elsif system_xml.name == 'LightingSystem'
              @systems_map[system_type.name] << BuildingSync::LightingSystemType.new(system_xml, @ns)
            else
              @systems_map[system_type.name] << system_xml
            end
          end
        end
      else
        hvac_xml = @g.add_hvac_system_to_facility(@base_xml)
        lighting_xml = @g.add_lighting_system_to_facility(@base_xml)
        @hvac_system = HVACSystem.new(hvac_xml, @ns)
        @lighting_system = LightingSystemType.new(lighting_xml, @ns)
        @load_system = LoadsSystem.new
      end
    end

    # @see BuildingSync::Report.add_cb_modeled
    def add_cb_modeled(id = "Scenario-#{BuildingSync::BASELINE}")
      @report.add_cb_modeled(id)
    end

    # Add a minimal lighting system in the doc and as an object
    # @param premise_id [String] id of the premise which the system will be linked to
    # @param premise_type [String] type of premise, i.e. Building, Section, etc.
    # @param lighting_system_id [String] id for new lighting system
    # @return [BuildingSync::LightingSystemType] new lighting system object
    def add_blank_lighting_system(premise_id, premise_type, lighting_system_id = 'LightingSystem-1')
      # Create new lighting system and link it
      lighting_system_xml = @g.add_lighting_system_to_facility(@base_xml, lighting_system_id)
      @g.add_linked_premise(lighting_system_xml, premise_id, premise_type)

      # Create a new array if doesn't yet exist
      if !@systems_map.key?('LightingSystems')
        @systems_map['LightingSystems'] = []
      end

      # Create new lighting system and add to array
      new_system = BuildingSync::LightingSystemType.new(lighting_system_xml, @ns)
      @systems_map['LightingSystems'] << new_system
      return new_system
    end

    # read other details from the xml
    # - contact information
    # - audit levels and dates
    # - Utility information
    # - UDFs
    def read_other_details
      # Get Contact information
      @base_xml.elements.each("#{@ns}:Contacts/#{@ns}:Contact") do |contact|
        @contacts << BuildingSync::Contact.new(contact, @ns)
      end
    end

    # create building systems
    # @param main_output_dir [String] main output path, not scenario specific. i.e. SR should be a subdirectory
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
    def create_building_systems(main_output_dir:, zone_hash: nil, hvac_delivery_type: 'Forced Air', htg_src: 'NaturalGas', clg_src: 'Electricity',
                                add_space_type_loads: true, add_constructions: true, add_elevators: false, add_exterior_lights: false,
                                add_exhaust: true, add_swh: true, add_hvac: true, add_thermostat: true, remove_objects: false)
      model = @site.get_model
      template = @site.get_standard_template
      system_type = @site.get_system_type
      climate_zone = @site.get_climate_zone

      onsite_parking_fraction = 1.0
      exterior_lighting_zone = '3 - All Other Areas'

      initial_objects = model.getModelObjects.size

      OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.create_building_system', "The building started with #{initial_objects} objects.")
      puts "BuildingSync.Facility.create_building_system - The building started with #{initial_objects} objects."

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
        if !@systems_map['LightingSystems'].nil?
          @systems_map['LightingSystems'].each do |lighting_system|
            lighting_system.add_exterior_lights(model, open_studio_system_standard, onsite_parking_fraction, exterior_lighting_zone, remove_objects)
          end
        else
          new_lighting_system = add_blank_lighting_system(@site.get_building.xget_id, 'Building')
          new_lighting_system.add_exterior_lights(model, open_studio_system_standard, onsite_parking_fraction, exterior_lighting_zone, remove_objects)
        end
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

      # TODO: Make this better
      @lighting_system.add_daylighting_controls(model, open_studio_system_standard, template, main_output_dir)

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
        if remove_objects
          model.purgeUnusedResourceObjects
          objects_after_cleanup = initial_objects - model.getModelObjects.size
          OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Facility.create_building_system', "Removing #{objects_after_cleanup} objects from model")
        end
        @hvac_system.apply_sizing_and_assumptions(model, main_output_dir, open_studio_system_standard, primary_bldg_type, system_type, climate_zone)
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
      puts "BuildingSync.Facility.create_building_system - The building finished with #{model.getModelObjects.size} objects."
    end

    # write osm
    # @param dir [String]
    # @return [Array]
    def write_osm(dir)
      scenario_types = @site.write_osm(dir)
      return scenario_types
    end

    # TODO: I don't think we want any of this.
    # write parameters to xml
    def prepare_final_xml
      @site.prepare_final_xml
    end

    attr_reader :systems_map, :site, :report, :measures, :contacts
  end
end
