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
module BuildingSync
  class HVACSystem < BuildingSystem
    def initialize(system_element = nil, ns = '')
      # code to initialize
      @principal_hvac_system_type = Hash.new
      @systems = system_element
      read_xml(system_element, ns) if system_element
    end

    def read_xml(system_element, ns)
      system_element.elements.each("#{ns}:HVACSystem") do |hvac_system|
        system_type = nil
        if hvac_system.elements["#{ns}:PrimaryHVACSystemType"]
          system_type = hvac_system.elements["#{ns}:PrimaryHVACSystemType"].text
        elsif hvac_system.elements["#{ns}:PrincipalHVACSystemType"]
          system_type = hvac_system.elements["#{ns}:PrincipalHVACSystemType"].text
        end
        if hvac_system.elements["#{ns}:LinkedPremises/#{ns}:Building/#{ns}:LinkedBuildingID"]
          linked_building = hvac_system.elements["#{ns}:LinkedPremises/#{ns}:Building/#{ns}:LinkedBuildingID"].attributes['IDref']
          puts "found primary system type: #{system_type} for linked building: #{linked_building}"
          @principal_hvac_system_type[linked_building] = system_type
        elsif hvac_system.elements["#{ns}:LinkedPremises/#{ns}:Section/#{ns}:LinkedSectionID"]
          linked_section = hvac_system.elements["#{ns}:LinkedPremises/#{ns}:Section/#{ns}:LinkedSectionID"].attributes['IDref']
          puts "found primary system type: #{system_type} for linked section: #{linked_section}"
          @principal_hvac_system_type[linked_section] = system_type
        elsif system_type
          puts "primary_hvac_system_type: #{system_type} is not linked to a building or section "
        end
      end
    end

    def get_primary_hvac_system_type
      if @principal_hvac_system_type
        return @principal_hvac_system_type.values[0]
      end
      return nil
    end

    # adding the principal hvac system type to the hvac systems, overwrite existing values or create new elements if none are present
    def add_principal_hvac_system_type(id, principal_hvac_type)
      if @systems.nil?
        @systems = REXML::Element.new("#{ns}:HVACSystems")
      end
      hvac_system = nil
      if @systems.elements["#{ns}:HVACSystem"].nil?
        hvac_system = REXML::Element.new("#{ns}:HVACSystem")
      else
        @systems.elements["#{ns}:HVACSystem"].each do |system|
          if system.elements["#{ns}:LinkedPremises/#{ns}:Building/#{ns}:LinkedBuildingID"]
            if system.elements["#{ns}:LinkedPremises/#{ns}:Building/#{ns}:LinkedBuildingID"].attributes['IDref'] = id
              hvac_system = system
              break
            end
          elsif system.elements["#{ns}:LinkedPremises/#{ns}:Section/#{ns}:LinkedSectionID"]
            if system.elements["#{ns}:LinkedPremises/#{ns}:Section/#{ns}:LinkedSectionID"].attributes['IDref'] = id
              hvac_system = system
              break
            end
          end
        end
        if hvac_system.nil? and @systems.elements["#{ns}:HVACSystem"].size = 1
          hvac_system = @systems.elements["#{ns}:HVACSystem"][0]
        end
      end

      if hvac_system.elements["#{ns}:PrincipalHVACSystemType"].nil?
        primary_hvac_system_type = REXML::Element.new("#{ns}:PrincipalHVACSystemType")
      else
        primary_hvac_system_type = hvac_system.elements["#{ns}:PrincipalHVACSystemType"]
      end
      primary_hvac_system_type.text = principal_hvac_type
    end

    def add_exhaust(model, standard, kitchen_makeup, remove_objects)
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
          OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.HVACSystem.add_exhaust', "Adding #{OpenStudio.toNeatString(max_flow_rate_ip, 0, true)} (cfm) of exhaust to #{k.thermalZone.get.name}, with #{OpenStudio.toNeatString(mixing_design_flow_rate_ip, 0, true)} (cfm) of makeup air from #{mixing_source_zone_name}")
        else
          OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.HVACSystem.add_exhaust', "Adding #{OpenStudio.toNeatString(max_flow_rate_ip, 0, true)} (cfm) of exhaust to #{k.thermalZone.get.name}")
        end
      end
      return true
    end

    def add_thermostats(model, standard, remove_objects)
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

          OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.HVACSystem.add_thermostats', "Assigning #{thermostat.name} to thermal zones with #{space_type.name} assigned.")
          space_type.spaces.each do |space|
            next if !space.thermalZone.is_initialized

            space.thermalZone.get.setThermostatSetpointDualSetpoint(thermostat)
          end
          next
        end
      end
      return true
    end

    def map_primary_hvac_system_type_to_cbecs_system_type(building_sync_primary_hvac_system_type, system_type)
      case building_sync_primary_hvac_system_type
      when "Packaged Terminal Air Conditioner"
        return "PTAC with hot water heat"
      when "Packaged Terminal Heat Pump"
        return "PTHP"
      when "Packaged Rooftop Air Conditioner"
        return "PSZ-AC with gas coil heat"
      when "Packaged Rooftop Heat Pump"
        return "PSZ-HP"
      when "Packaged Rooftop VAV with Hot Water Reheat"
        return "PVAV with reheat"
      when "Packaged Rooftop VAV with Electric Reheat"
        return "PVAV with PFP boxes"
      when "VAV with Hot Water Reheat"
        return "VAV with reheat"
      when "VAV with Electric Reheat"
        return "VAV with PFP boxes"
      else
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.HVACSystem.map_primary_hvac_system_type_to_cbecs_system_type', "building_sync_primary_hvac_system_type: #{building_sync_primary_hvac_system_type} does not have a mapping to the CBECS system type, using the system type from standards: #{system_type}")
        return system_type
      end
    end

    def add_hvac(model, zone_hash, standard, system_type, hvac_delivery_type = 'Forced Air', htg_src = 'NaturalGas', clg_src = 'Electricity', remove_objects = false)
      # remove HVAC objects
      if remove_objects
        standard.model_remove_prm_hvac(model)
      end

      puts "system_type derived from standards: #{system_type} and primary hvac system type override is: #{@principal_hvac_system_type}"
      if !@principal_hvac_system_type.empty?
        system_type = map_primary_hvac_system_type_to_cbecs_system_type(@principal_hvac_system_type.first.first, system_type)
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
          new_system_type = get_system_type_from_zone(zone_hash, zones, system_type)
          puts "setting system: #{new_system_type} for zone names: #{BuildingSync::Helper.get_zone_name_list(zones)}"
          model.add_cbecs_hvac_system(standard, new_system_type, zones)
        end
      end
      return true
    end

    def get_system_type_from_zone(zone_hash, zones, system_type)
      if zone_hash
        zone_hash.each do |id, zone_list|
          zone_name_list = BuildingSync::Helper.get_zone_name_list(zone_list)
          zones.each do |zone|
            if zone_name_list.include? zone.name.get
              return map_primary_hvac_system_type_to_cbecs_system_type(@principal_hvac_system_type[id], system_type)
            end
          end
        end
      end
      return system_type
    end

    def apply_sizing_and_assumptions(model, output_path, standard, primary_bldg_type, system_type, climate_zone)
      case system_type
      when 'Ideal Air Loads'

      else
        # Set the heating and cooling sizing parameters
        standard.model_apply_prm_sizing_parameters(model)

        # Perform a sizing run
        if standard.model_run_sizing_run(model, "#{output_path}/SR") == false
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
      return true
    end

    attr_reader :principal_hvac_system_type


  end
end
