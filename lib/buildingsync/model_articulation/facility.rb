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
require_relative '../helpers/os_lib_model_generation_bricr'
require 'openstudio/extension/core/os_lib_geometry'
require_relative '../helpers/Model.hvac'

module BuildingSync
  class Facility
    include OsLib_ModelGenerationBRICR
    include OsLib_Geometry

    # initialize
    def initialize(facility_xml, ns)
      # code to initialize
      # an array that contains all the sites
      @sites = []

      # reading the xml
      read_xml(facility_xml, ns)
    end

    # adding a site to the facility
    def read_xml(facility_xml, ns)
      # puts facility_xml.to_a
      facility_xml.elements.each("#{ns}:Sites/#{ns}:Site") do |site_element|
        @sites.push(Site.new(site_element, ns))
      end
    end

    # generating the OpenStudio model based on the imported BuildingSync Data
    def generate_baseline_osm
      if @sites.count == 0
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Facility.generate_baseline_osm', 'There are no sites attached to this facility in your BuildingSync file.')
        raise 'There are no sites attached to this facility in your BuildingSync file.'
      else if @sites.count > 1
             OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Facility.generate_baseline_osm', "There are more than one (#{@sites.count}) sites attached to this facility in your BuildingSync file.")
             raise "There are more than one (#{@sites.count}) sites attached to this facility in your BuildingSync file."
           else
             OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.generate_baseline_osm', "Info: There is/are #{@sites.count} sites in this facility.")
           end
      end
      @sites.each(&:generate_baseline_osm)

      create_building_systems(@sites[0].get_model, @sites[0].get_building_template, @sites[0].get_system_type, "Forced Air")
    end

    def create_building_systems(model, template, system_type, hvac_delivery_type)
      add_space_type_loads = true
      add_constructions = true
      add_elevators = false
      add_exterior_lights = false
      onsite_parking_fraction = 1.0
      kitchen_makeup = "Adjacent"
      exterior_lighting_zone = "3 - All Other Areas"
      add_exhaust = true
      add_swh = true
      add_hvac = true
      htg_src = "NaturalGas"
      clg_src = "Electricity"
      remove_objects = false
      add_thermostat = true

      initial_objects = model.getModelObjects.size

      OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.create_building_system', "The building started with #{initial_objects} objects.")

      # Make the standard applier
      standard = Standard.build(template)

      # add internal loads to space types
      if add_space_type_loads

        # remove internal loads
        if remove_objects
          model.getSpaceLoads.each do |instance|
            next if instance.name.to_s.include?('Elevator') # most prototype building types model exterior elevators with name Elevator
            next if instance.to_InternalMass.is_initialized
            next if instance.to_WaterUseEquipment.is_initialized
            instance.remove
          end
          model.getDesignSpecificationOutdoorAirs.each(&:remove)
          model.getDefaultScheduleSets.each(&:remove)
        end

        model.getSpaceTypes.each do |space_type|
          # Don't add infiltration here; will be added later in the script
          test = standard.space_type_apply_internal_loads(space_type, true, true, true, true, true, false)
          if test == false
            OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Facility.create_building_system', "Could not add loads for #{space_type.name}. Not expected for #{template}")
            next
          end

          # apply internal load schedules
          # the last bool test it to make thermostat schedules. They are now added in HVAC section instead of here
          standard.space_type_apply_internal_load_schedules(space_type, true, true, true, true, true, true, false)

          # extend space type name to include the template. Consider this as well for load defs
          space_type.setName("#{space_type.name} - #{template}")
          OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.create_building_system', "Adding loads to space type named #{space_type.name}")
        end

        # warn if spaces in model without space type
        spaces_without_space_types = []
        model.getSpaces.each do |space|
          next if space.spaceType.is_initialized
          spaces_without_space_types << space
        end
        if !spaces_without_space_types.empty?
          OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Facility.create_building_system', "#{spaces_without_space_types.size} spaces do not have space types assigned, and wont' receive internal loads from standards space type lookups.")
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
      lookup_building_type = standard.model_get_lookup_name(primary_bldg_type) # Used for some lookups in the standards gem
      model.getBuilding.setStandardsBuildingType(primary_bldg_type)

      # make construction set and apply to building
      if add_constructions

        # remove default construction sets
        if remove_objects
          model.getDefaultConstructionSets.each(&:remove)
        end

        # TODO: - allow building type and space type specific constructions set selection.
        if ['SmallHotel', 'LargeHotel', 'MidriseApartment', 'HighriseApartment'].include?(primary_bldg_type)
          is_residential = 'Yes'
        else
          is_residential = 'No'
        end
        climate_zone = standard.model_get_building_climate_zone_and_building_type(model)['climate_zone']
        bldg_def_const_set = standard.model_add_construction_set(model, climate_zone, lookup_building_type, nil, is_residential)
        if bldg_def_const_set.is_initialized
          bldg_def_const_set = bldg_def_const_set.get
          if is_residential then bldg_def_const_set.setName("Res #{bldg_def_const_set.name}") end
          model.getBuilding.setDefaultConstructionSet(bldg_def_const_set)
          OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.create_building_system', "Adding default construction set named #{bldg_def_const_set.name}")
        else
          OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Facility.create_building_system', "Could not create default construction set for the building type #{lookup_building_type} in climate zone #{climate_zone}.")
          return false
        end

        # address any adiabatic surfaces that don't have hard assigned constructions
        model.getSurfaces.each do |surface|
          next if surface.outsideBoundaryCondition != 'Adiabatic'
          next if surface.construction.is_initialized
          surface.setAdjacentSurface(surface)
          surface.setConstruction(surface.construction.get)
          surface.setOutsideBoundaryCondition('Adiabatic')
        end

        # Modify the infiltration rates
        if remove_objects
          model.getSpaceInfiltrationDesignFlowRates.each(&:remove)
        end
        standard.model_apply_infiltration_standard(model)
        standard.model_modify_infiltration_coefficients(model, primary_bldg_type, climate_zone)

        # set ground temperatures from DOE prototype buildings
        standard.model_add_ground_temperatures(model, primary_bldg_type, climate_zone)

      end

      # add elevators (returns ElectricEquipment object)
      if add_elevators

        # remove elevators as spaceLoads or exteriorLights
        model.getSpaceLoads.each do |instance|
          next if !instance.name.to_s.include?('Elevator') # most prototype building types model exterior elevators with name Elevator
          instance.remove
        end
        model.getExteriorLightss.each do |ext_light|
          next if !ext_light.name.to_s.include?('Fuel equipment') # some prototype building types model exterior elevators by this name
          ext_light.remove
        end

        elevators = standard.model_add_elevators(model)
        if elevators.nil?
          OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.create_building_system', 'No elevators added to the building.')
        else
          elevator_def = elevators.electricEquipmentDefinition
          design_level = elevator_def.designLevel.get
          OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.create_building_system', "Adding #{elevators.multiplier.round(1)} elevators each with power of #{OpenStudio.toNeatString(design_level, 0, true)} (W), plus lights and fans.")
        end
      end

      # add exterior lights (returns a hash where key is lighting type and value is exteriorLights object)
      if add_exterior_lights

        if remove_objects
          model.getExteriorLightss.each do |ext_light|
            next if ext_light.name.to_s.include?('Fuel equipment') # some prototype building types model exterior elevators by this name
            ext_light.remove
          end
        end

        exterior_lights = standard.model_add_typical_exterior_lights(model, exterior_lighting_zone.chars[0].to_i, onsite_parking_fraction)
        exterior_lights.each do |k, v|
          OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.create_building_system', "Adding Exterior Lights named #{v.exteriorLightsDefinition.name} with design level of #{v.exteriorLightsDefinition.designLevel} * #{OpenStudio.toNeatString(v.multiplier, 0, true)}.")
        end
      end

      # add_exhaust
      if add_exhaust

        # remove exhaust objects
        if remove_objects
          model.getFanZoneExhausts.each(&:remove)
        end

        zone_exhaust_fans = standard.model_add_exhaust(model, kitchen_makeup) # second argument is strategy for finding makeup zones for exhaust zones
        zone_exhaust_fans.each do |k, v|
          max_flow_rate_ip = OpenStudio.convert(k.maximumFlowRate.get, 'm^3/s', 'cfm').get
          if v.key?(:zone_mixing)
            zone_mixing = v[:zone_mixing]
            mixing_source_zone_name = zone_mixing.sourceZone.get.name
            mixing_design_flow_rate_ip = OpenStudio.convert(zone_mixing.designFlowRate.get, 'm^3/s', 'cfm').get
            OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.create_building_system', "Adding #{OpenStudio.toNeatString(max_flow_rate_ip, 0, true)} (cfm) of exhaust to #{k.thermalZone.get.name}, with #{OpenStudio.toNeatString(mixing_design_flow_rate_ip, 0, true)} (cfm) of makeup air from #{mixing_source_zone_name}")
          else
            OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.create_building_system', "Adding #{OpenStudio.toNeatString(max_flow_rate_ip, 0, true)} (cfm) of exhaust to #{k.thermalZone.get.name}")
          end
        end
      end

      # add service water heating demand and supply
      if add_swh

        # remove water use equipment and water use connections
        if remove_objects
          # TODO: - remove plant loops used for service water heating
          model.getWaterUseEquipments.each(&:remove)
          model.getWaterUseConnectionss.each(&:remove)
        end

        typical_swh = standard.model_add_typical_swh(model)
        midrise_swh_loops = []
        stripmall_swh_loops = []
        typical_swh.each do |loop|
          if loop.name.get.include?('MidriseApartment')
            midrise_swh_loops << loop
          elsif loop.name.get.include?('RetailStripmall')
            stripmall_swh_loops << loop
          else
            water_use_connections = []
            loop.demandComponents.each do |component|
              next if !component.to_WaterUseConnections.is_initialized
              water_use_connections << component
            end
            OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.create_building_system', "Adding #{loop.name} to the building. It has #{water_use_connections.size} water use connections.")
          end
        end
        if !midrise_swh_loops.empty?
          OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.create_building_system', "Adding #{midrise_swh_loops.size} MidriseApartment service water heating loops.")
        end
        if !stripmall_swh_loops.empty?
          OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.create_building_system', "Adding #{stripmall_swh_loops.size} RetailStripmall service water heating loops.")
        end
      end

      # TODO: - when add methods below add bool to enable/disable them with default value to true

      # add daylight controls, need to perform a sizing run for 2010
      if template == '90.1-2010'
        if standard.model_run_sizing_run(model, "#{Dir.pwd}/SRvt") == false
          return false
        end
      end
      standard.model_add_daylighting_controls(model)

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

        # remove thermostats
        if remove_objects
          model.getThermostatSetpointDualSetpoints.each(&:remove)
        end

        model.getSpaceTypes.each do |space_type|
          # create thermostat schedules
          # apply internal load schedules
          # the last bool test it to make thermostat schedules. They are added to the model but not assigned
          standard.space_type_apply_internal_load_schedules(space_type, false, false, false, false, false, false, true)

          # identify thermal thermostat and apply to zones (apply_internal_load_schedules names )
          model.getThermostatSetpointDualSetpoints.each do |thermostat|
            next if !thermostat.name.to_s.include?(space_type.name.to_s)
            OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.create_building_system', "Assigning #{thermostat.name} to thermal zones with #{space_type.name} assigned.")
            space_type.spaces.each do |space|
              next if !space.thermalZone.is_initialized
              space.thermalZone.get.setThermostatSetpointDualSetpoint(thermostat)
            end
            next
          end
        end
      end

      # add hvac system
      if add_hvac

        # remove HVAC objects
        if remove_objects
          standard.model_remove_prm_hvac(model)
        end

        case system_type
        when 'Inferred'

          # Get the hvac delivery type enum
          hvac_delivery = case hvac_delivery_type
                          when 'Forced Air'
                            'air'
                          when 'Hydronic'
                            'hydronic'
                          end

          # Group the zones by occupancy type.  Only split out
          # non-dominant groups if their total area exceeds the limit.
          sys_groups = standard.model_group_zones_by_type(model, OpenStudio.convert(20_000, 'ft^2', 'm^2').get)

          # For each group, infer the HVAC system type.
          sys_groups.each do |sys_group|
            # Infer the primary system type
            # OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.create_building_system', "template = #{template}, climate_zone = #{climate_zone}, occ_type = #{sys_group['type']}, hvac_delivery = #{hvac_delivery}, htg_src = #{htg_src}, clg_src = #{clg_src}, area_ft2 = #{sys_group['area_ft2']}, num_stories = #{sys_group['stories']}")
            sys_type, central_htg_fuel, zone_htg_fuel, clg_fuel = standard.model_typical_hvac_system_type(model,
                                                                                                          climate_zone,
                                                                                                          sys_group['type'],
                                                                                                          hvac_delivery,
                                                                                                          htg_src,
                                                                                                          clg_src,
                                                                                                          OpenStudio.convert(sys_group['area_ft2'], 'ft^2', 'm^2').get,
                                                                                                          sys_group['stories'])

            # Infer the secondary system type for multizone systems
            sec_sys_type = case sys_type
                           when 'PVAV Reheat', 'VAV Reheat'
                             'PSZ-AC'
                           when 'PVAV PFP Boxes', 'VAV PFP Boxes'
                             'PSZ-HP'
                           else
                             sys_type # same as primary system type
                           end

            # Group zones by story
            story_zone_lists = standard.model_group_zones_by_story(model, sys_group['zones'])

            # On each story, add the primary system to the primary zones
            # and add the secondary system to any zones that are different.
            story_zone_lists.each do |story_group|
              # Differentiate primary and secondary zones, based on
              # operating hours and internal loads (same as 90.1 PRM)
              pri_sec_zone_lists = standard.model_differentiate_primary_secondary_thermal_zones(model, story_group)
              # Add the primary system to the primary zones
              standard.model_add_hvac_system(model, sys_type, central_htg_fuel, zone_htg_fuel, clg_fuel, pri_sec_zone_lists['primary'])
              # Add the secondary system to the secondary zones (if any)
              if !pri_sec_zone_lists['secondary'].empty?
                standard.model_add_hvac_system(model, sec_sys_type, central_htg_fuel, zone_htg_fuel, clg_fuel, pri_sec_zone_lists['secondary'])
              end
            end
          end

        else

          # Group the zones by story
          story_groups = standard.model_group_zones_by_story(model, model.getThermalZones)

          # Add the user specified HVAC system for each story.
          # Single-zone systems will get one per zone.
          story_groups.each do |zones|
            model.add_cbecs_hvac_system(standard, system_type, zones)
          end

        end
      end

      # TODO: - hours of operation customization (initially using existing measure downstream of this one)
      # not clear yet if this is altering existing schedules, or additional inputs when schedules first requested

      # set hvac controls and efficiencies (this should be last model articulation element)
      if add_hvac
        case system_type
        when 'Ideal Air Loads'

        else
          # Set the heating and cooling sizing parameters
          standard.model_apply_prm_sizing_parameters(model)

          # Perform a sizing run
          if standard.model_run_sizing_run(model, "#{Dir.pwd}/SR1") == false
            return false
          end

          # If there are any multizone systems, reset damper positions
          # to achieve a 60% ventilation effectiveness minimum for the system
          # following the ventilation rate procedure from 62.1
          standard.model_apply_multizone_vav_outdoor_air_sizing(model)

          # Apply the prototype HVAC assumptions
          standard.model_apply_prototype_hvac_assumptions(model, primary_bldg_type, climate_zone)

          # Apply the HVAC efficiency standard
          standard.model_apply_hvac_efficiency_standard(model, climate_zone)
        end
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
      @sites.each do |site|
        site.write_osm(dir)
      end
    end
  end
end
