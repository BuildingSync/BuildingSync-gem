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
module BuildingSync
  class HVACSystem < BuildingSystem
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

    def add_hvac(model, standard, system_type, hvac_delivery_type = 'Forced Air', htg_src = 'NaturalGas', clg_src = 'Electricity', remove_objects = false)
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
      return true
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
  end
end
