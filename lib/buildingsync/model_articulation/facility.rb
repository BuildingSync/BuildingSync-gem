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
require_relative 'site'
require_relative 'loads_system'
require_relative 'envelope_system'
require_relative 'hvac_system'
require_relative 'service_hot_water_system'
require 'openstudio/model_articulation/os_lib_model_generation_bricr'
require 'openstudio/extension/core/os_lib_geometry'
require_relative '../helpers/Model.hvac'
require_relative 'metered_energy'

module BuildingSync
  class Facility
    include OsLib_ModelGenerationBRICR
    include OsLib_Geometry

    # initialize
    def initialize(facility_xml, ns)
      # code to initialize
      # an array that contains all the sites
      @sites = []
      @auditor_contact_id = nil
      @audit_date = nil
      @contact_name = nil
      @utility_name = nil
      @utility_meter_number = nil
      @metering_configuration = nil
      @rate_schedules = nil
      @interval_reading_monthly = []
      @interval_reading_yearly = []
      @energy_resource = nil
      @benchmark_source = nil
      @energy_cost = nil
      @annual_fuel_use_native_units = 0

      # reading the xml
      read_xml(facility_xml, ns)
    end

    # adding a site to the facility
    def read_xml(facility_xml, ns)
      facility_xml.elements.each("#{ns}:Sites/#{ns}:Site") do |site_element|
        @sites.push(Site.new(site_element, ns))
      end

      read_other_details(facility_xml, ns)
      read_interval_reading(facility_xml, ns)
    end

    def determine_open_studio_standard(standard_to_be_used)
      return @sites[0].determine_open_studio_standard(standard_to_be_used)
    end

    # generating the OpenStudio model based on the imported BuildingSync Data
    def generate_baseline_osm(epw_file_path, output_path, standard_to_be_used)
      if @sites.count == 0
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Facility.generate_baseline_osm', 'There are no sites attached to this facility in your BuildingSync file.')
        raise 'There are no sites attached to this facility in your BuildingSync file.'
      elsif @sites.count > 1
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Facility.generate_baseline_osm', "There are more than one (#{@sites.count}) sites attached to this facility in your BuildingSync file.")
        raise "There are more than one (#{@sites.count}) sites attached to this facility in your BuildingSync file."
      else
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.generate_baseline_osm', "Info: There is/are #{@sites.count} sites in this facility.")
      end
      @sites[0].generate_baseline_osm(epw_file_path, standard_to_be_used)

      create_building_systems(output_path)
      return true
    end

    def get_sites
      return @sites
    end

    def determine_open_studio_system_standard
      return @sites[0].determine_open_studio_system_standard
    end

    def read_interval_reading(facility_xml, ns)
      interval_frequency = ''
      reading_type = ''
      interval_reading = ''
      if facility_xml.elements["#{ns}:Reports/#{ns}:Report/#{ns}:Scenarios/#{ns}:Scenario/#{ns}:ResourceUses/#{ns}:ResourceUse/#{ns}:EnergyResource"]
        @energy_resource = facility_xml.elements["#{ns}:Reports/#{ns}:Report/#{ns}:Scenarios/#{ns}:Scenario/#{ns}:ResourceUses/#{ns}:ResourceUse/#{ns}:EnergyResource"].text
      else
        @energy_resource = nil
      end

      if facility_xml.elements["#{ns}:Reports/#{ns}:Report/#{ns}:Scenarios/#{ns}:Scenario/#{ns}:TimeSeriesData/#{ns}:TimeSeriesType/#{ns}:IntervalFrequency"]
        interval_frequency = facility_xml.elements["#{ns}:Reports/#{ns}:Report/#{ns}:Scenarios/#{ns}:Scenario/#{ns}:TimeSeriesData/#{ns}:TimeSeriesType/#{ns}:IntervalFrequency"].text
      end

      if facility_xml.elements["#{ns}:Reports/#{ns}:Report/#{ns}:Scenarios/#{ns}:Scenario/#{ns}:TimeSeriesData/#{ns}:TimeSeriesType/#{ns}:ReadingType"]
        reading_type = facility_xml.elements["#{ns}:Reports/#{ns}:Report/#{ns}:Scenarios/#{ns}:Scenario/#{ns}:TimeSeriesData/#{ns}:TimeSeriesType/#{ns}:ReadingType"].text
      end

      if facility_xml.elements["#{ns}:Reports/#{ns}:Report/#{ns}:Scenarios/#{ns}:Scenario/#{ns}:TimeSeriesData/#{ns}:TimeSeriesType/#{ns}:IntervalReading"]
        interval_reading = facility_xml.elements["#{ns}:Reports/#{ns}:Report/#{ns}:Scenarios/#{ns}:Scenario/#{ns}:TimeSeriesData/#{ns}:TimeSeriesType/#{ns}:IntervalReading"].text
      end

      if interval_frequency == 'Month'
      @interval_reading_monthly.push(MeteredEnergy.new(@energy_resource, interval_frequency, reading_type, interval_reading))
      elsif interval_frequency == 'Year'
        @interval_reading_yearly.push(MeteredEnergy.new(@energy_resource, interval_frequency, reading_type, interval_reading))
      end

    end

    def read_other_details(facility_xml, ns)
      if facility_xml.elements["#{ns}:Report/#{ns}:AuditorContactID"]
        @auditor_contact_id = facility_xml.elements["#{ns}:Report/#{ns}:AuditorContactID"].text
      else
        @auditor_contact_id = nil
      end

      if facility_xml.elements["#{ns}:Reports/#{ns}:Report/#{ns}:Scenarios/#{ns}:Scenario/#{ns}:ScenarioType/#{ns}:Benchmark/#{ns}:BenchmarkType/#{ns}:Other"]
        @benchmark_source = facility_xml.elements["#{ns}:Reports/#{ns}:Report/#{ns}:Scenarios/#{ns}:Scenario/#{ns}:ScenarioType/#{ns}:Benchmark/#{ns}:BenchmarkType/#{ns}:Other"].text
      else
        @benchmark_source = nil
      end

      if facility_xml.elements["#{ns}:Reports/#{ns}:Report/#{ns}:Scenarios/#{ns}:Scenario/#{ns}:ResourceUses/#{ns}:ResourceUse/#{ns}:AnnualFuelUseNativeUnits"]
        @annual_fuel_use_native_units = facility_xml.elements["#{ns}:Reports/#{ns}:Report/#{ns}:Scenarios/#{ns}:Scenario/#{ns}:ResourceUses/#{ns}:ResourceUse/#{ns}:AnnualFuelUseNativeUnits"].text
      else
        @annual_fuel_use_native_units = nil
      end

      if facility_xml.elements["#{ns}:Reports/#{ns}:Report/#{ns}:Scenarios/#{ns}:Scenario/#{ns}:AllResourceTotals/#{ns}:AllResourceTotal/#{ns}:EnergyCost"]
        @energy_cost = facility_xml.elements["#{ns}:Reports/#{ns}:Report/#{ns}:Scenarios/#{ns}:Scenario/#{ns}:AllResourceTotals/#{ns}:AllResourceTotal/#{ns}:EnergyCost"].text
      else
        @energy_cost = nil
      end

      if facility_xml.elements["#{ns}:Report/#{ns}:AuditDate"]
        @auditor_contact_id = Date.parse(facility_xml.elements["#{ns}:Report/#{ns}:AuditDate"].text)
      else
        @auditor_contact_id = nil
      end

      if facility_xml.elements["#{ns}:Contacts/#{ns}:Contact/#{ns}:ContactName"]
        @contact_name = facility_xml.elements["#{ns}:Contacts/#{ns}:Contact/#{ns}:ContactName"].text
      else
        @contact_name = nil
      end

      if facility_xml.elements["#{ns}:Utilities/#{ns}:Utility/#{ns}:UtilityName"]
        @utility_name = facility_xml.elements["#{ns}:Utilities/#{ns}:Utility/#{ns}:UtilityName"].text
      else
        @utility_name = nil
      end

      if facility_xml.elements["#{ns}:Utilities/#{ns}:Utility/#{ns}:MeteringConfiguration"]
        @metering_configuration = facility_xml.elements["#{ns}:Utilities/#{ns}:Utility/#{ns}:MeteringConfiguration"].text
      else
        @metering_configuration = nil
      end

      if facility_xml.elements["#{ns}:Utilities/#{ns}:Utility/#{ns}:RateSchedules"]
        @rate_schedules = facility_xml.elements["#{ns}:Utilities/#{ns}:Utility/#{ns}:RateSchedules"].text
      else
        @rate_schedules = nil
      end

      if facility_xml.elements["#{ns}:Utilities/#{ns}:UtilityMeterNumbers/#{ns}:UtilityMeterNumber"]
        @utility_meter_number = facility_xml.elements["#{ns}:Utilities/#{ns}:UtilityMeterNumbers/#{ns}:UtilityMeterNumber"].text
      else
        @utility_meter_number = nil
      end
    end

    def create_building_systems(output_path, hvac_delivery_type = 'Forced Air', htg_src = 'NaturalGas', clg_src = 'Electricity',
                                add_space_type_loads = true, add_constructions = true, add_elevators = false, add_exterior_lights = false,
                                add_exhaust = true, add_swh = true, add_hvac = true, add_thermostat = true, remove_objects = false)
      model = @sites[0].get_model
      template = @sites[0].get_building_template
      system_type = @sites[0].get_system_type
      climate_zone = @sites[0].get_climate_zone

      onsite_parking_fraction = 1.0
      exterior_lighting_zone = '3 - All Other Areas'

      initial_objects = model.getModelObjects.size

      OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.create_building_system', "The building started with #{initial_objects} objects.")

      load_system = LoadsSystem.new
      hvac_system = HVACSystem.new

      # Make the open_studio_system_standard applier
      open_studio_system_standard = determine_open_studio_system_standard
      OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.create_building_system', "Building Standard with template: #{template}.")

      # add internal loads to space types
      if add_space_type_loads
        load_system.add_internal_loads(model, open_studio_system_standard, template, remove_objects)
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

      envelopeSystem = nil
      # make construction set and apply to building
      if add_constructions
        envelopeSystem = EnvelopeSystem.new
        envelopeSystem.create(model, open_studio_system_standard, primary_bldg_type, lookup_building_type, remove_objects)
      end

      # add elevators (returns ElectricEquipment object)
      if add_elevators
        load_system.add_elevator(model, open_studio_system_standard)
      end

      # add exterior lights (returns a hash where key is lighting type and value is exteriorLights object)
      if add_exterior_lights
        load_system.add_exterior_lights(model, open_studio_system_standard, onsite_parking_fraction, exterior_lighting_zone, remove_objects)
      end

      # add_exhaust
      if add_exhaust
        hvac_system.add_exhaust(model, open_studio_system_standard, 'Adjacent', remove_objects)
      end

      # add service water heating demand and supply
      if add_swh
        serviceHotWaterSystem = ServiceHotWaterSystem.new
        serviceHotWaterSystem.add(model, open_studio_system_standard, remove_objects)
      end

      load_system.add_day_lighting_controls(model, open_studio_system_standard, template)

      # TODO: - add refrigeration
      # remove refrigeration equipment
      if remove_objects
        model.getRefrigerationSystems.each(&:remove)
      end

      # TODO: - add internal mass
      # remove internal mass
      # if remove_objects
      #  model.getSpaceLoads.each do |instance|
      #    next if not instance.to_InternalMass.is_initialized
      #    instance.remove
      #  end
      # end

      # TODO: - add slab modeling and slab insulation

      # TODO: - fuel customization for cooking and laundry
      # works by switching some fraction of electric loads to gas if requested (assuming base load is electric)
      # add thermostats
      if add_thermostat
        hvac_system.add_thermostats(model, open_studio_system_standard, remove_objects)
      end

      # add hvac system
      if add_hvac
        hvac_system.add_hvac(model, open_studio_system_standard, system_type, hvac_delivery_type, htg_src, clg_src, remove_objects)
      end

      # TODO: - hours of operation customization (initially using existing measure downstream of this one)
      # not clear yet if this is altering existing schedules, or additional inputs when schedules first requested

      # set hvac controls and efficiencies (this should be last model articulation element)
      if add_hvac
        hvac_system.apply_sizing_and_assumptions(model, output_path, open_studio_system_standard, primary_bldg_type, system_type, climate_zone)
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

    def write_osm(dir)
      scenario_types = {}
      @sites.each do |site|
        scenario_types = site.write_osm(dir)
      end
      return scenario_types
    end
  end
end
