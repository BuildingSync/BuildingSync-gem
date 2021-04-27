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
require 'buildingsync/helpers/helper'
require 'buildingsync/helpers/xml_get_set'

module BuildingSync
  # HVACSystem class
  class HVACSystem < BuildingSystem
    include BuildingSync::Helper
    include BuildingSync::XmlGetSet
    # initialize
    # @param system_element [REXML::Element]
    # @param ns [String]
    def initialize(base_xml, ns = 'auc')
      @base_xml = base_xml
      @ns = ns

      help_element_class_type_check(base_xml, 'HVACSystem')

      # code to initialize
      read_xml
    end

    # read xml
    def read_xml; end

    def get_linked_ids; end

    # get principal hvac system type
    # @return [String]
    def get_principal_hvac_system_type
      return xget_text('PrincipalHVACSystemType')
    end

    # adding the principal hvac system type to the hvac systems, overwrite existing values or create new elements if none are present
    # @param id [String]
    # @param principal_hvac_type [String]
    def set_principal_hvac_system_type(principal_hvac_type)
      xset_or_create('PrincipalHVACSystemType', principal_hvac_type)
    end

    # add exhaust
    # @param model [OpenStudio::Model]
    # @param standard [Standard]
    # @param kitchen_makeup [String]
    # @param remove_objects [Boolean]
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

    # add thermostats
    # @param model [OpenStudio::Model]
    # @param standard [Standard]
    # @param remove_objects [Boolean]
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
          if !thermostat.coolingSetpointTemperatureSchedule.is_initialized
            OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.HVACSystem.add_thermostats', "#{thermostat.name} has no cooling setpoint.")
          end
          if !thermostat.heatingSetpointTemperatureSchedule.is_initialized
            OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.HVACSystem.add_thermostats', "#{thermostat.name} has no heating setpoint.")
          end

          OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.HVACSystem.add_thermostats', "Assigning #{thermostat.name} to thermal zones with #{space_type.name} assigned.")
          puts "BuildingSync.HVACSystem.add_thermostats - Assigning #{thermostat.name} to thermal zones with #{space_type.name} assigned."
          space_type.spaces.each do |space|
            next if !space.thermalZone.is_initialized

            space.thermalZone.get.setThermostatSetpointDualSetpoint(thermostat)
          end
        end
      end
      puts "ThermalZones: #{model.getThermalZones.size}"
      puts "ThermostatDSPs: #{model.getThermostatSetpointDualSetpoints.size}"
      add_setpoints_to_thermostats_if_none(model)
      return true
    end

    # @return [Boolean] true if ALL thermostats have heating and cooling setpoints
    def add_setpoints_to_thermostats_if_none(model)
      successful = true

      # seperate out thermostats that need heating vs. cooling schedules
      tstats_cooling = []
      tstats_heating = []
      model.getThermalZones.each do |tz|
        if tz.thermostatSetpointDualSetpoint.is_initialized
          tstat = tz.thermostatSetpointDualSetpoint.get
          tstats_cooling << tstat if !tstat.coolingSetpointTemperatureSchedule.is_initialized
          tstats_heating << tstat if !tstat.heatingSetpointTemperatureSchedule.is_initialized
        end
      end

      puts "BuildingSync.HVACSystem.add_setpoints_to_thermostats_if_none - (#{tstats_cooling.size}) thermostats needing cooling schedule"
      puts "BuildingSync.HVACSystem.add_setpoints_to_thermostats_if_none - (#{tstats_heating.size}) thermostats needing heating schedule"

      htg_setpoints = [
        # [Time.new(days, hours, mins seconds), temp_value_celsius]
        [OpenStudio::Time.new(0, 9, 0, 0), 17],
        [OpenStudio::Time.new(0, 17, 0, 0), 20],
        [OpenStudio::Time.new(0, 24, 0, 0), 17]
      ]
      clg_setpoints = [
        # [Time.new(days, hours, mins seconds), temp_value_celsius]
        [OpenStudio::Time.new(0, 9, 0, 0), 23],
        [OpenStudio::Time.new(0, 17, 0, 0), 20],
        [OpenStudio::Time.new(0, 24, 0, 0), 23]
      ]

      heating_sp_schedule = create_schedule_ruleset(model, htg_setpoints, 'Thermostat Heating SP')
      cooling_sp_schedule = create_schedule_ruleset(model, clg_setpoints, 'Thermostat Cooling SP')

      tstats_cooling.each do |thermostat|
        success = thermostat.setCoolingSetpointTemperatureSchedule(cooling_sp_schedule)
        if success
          OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.HVACSystem.add_setpoints_to_thermostats_if_none', "Cooling Schedule (#{cooling_sp_schedule.nameString}) added to Thermostat: #{thermostat.nameString}")
          puts "BuildingSync.HVACSystem.add_setpoints_to_thermostats_if_none - Cooling Schedule (#{cooling_sp_schedule.nameString}) added to Thermostat: #{thermostat.nameString}"
        else
          successful = false
          OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.HVACSystem.add_setpoints_to_thermostats_if_none', "No Cooling Schedule for Thermostat: #{thermostat.nameString}")
          puts "BuildingSync.HVACSystem.add_setpoints_to_thermostats_if_none - No Cooling Schedule for Thermostat: #{thermostat.nameString}"
        end
      end

      tstats_heating.each do |thermostat|
        success = thermostat.setHeatingSetpointTemperatureSchedule(heating_sp_schedule)
        if success
          OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.HVACSystem.add_setpoints_to_thermostats_if_none', "Heating Schedule (#{heating_sp_schedule.nameString}) added to Thermostat: #{thermostat.nameString}")
          puts "BuildingSync.HVACSystem.add_setpoints_to_thermostats_if_none - Heating Schedule (#{heating_sp_schedule.nameString}) added to Thermostat: #{thermostat.nameString}"
        else
          successful = false
          OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.HVACSystem.add_setpoints_to_thermostats_if_none', "No Heating Schedule for Thermostat: #{thermostat.nameString}")
          puts "BuildingSync.HVACSystem.add_setpoints_to_thermostats_if_none - No Heating Schedule for Thermostat: #{thermostat.nameString}"
        end
      end
      return successful
    end

    # @param model [OpenStudio::Model::Model]
    # @param values [Array<Array<OpenStudio::Time, Float>>] [[cutoff_time, value_until_cutoff]]
    # @return [OpenStudio::Model::ScheduleRuleset] a new schedule ruleset with values added to the default day
    def create_schedule_ruleset(model, values, name)
      ruleset = OpenStudio::Model::ScheduleRuleset.new(model)
      ruleset.setName(name)
      dd = ruleset.defaultDaySchedule
      values.each do |v|
        dd.addValue(v[0], v[1])
      end
      return ruleset
    end

    # map principal hvac system type to cbecs system type
    # @param principal_hvac_system_type [String]
    # @param fallback_system_type [String] the default system_type to use if the other is not found
    # @return [String]
    def map_to_cbecs(principal_hvac_system_type, fallback_system_type)
      case principal_hvac_system_type
      when 'Packaged Terminal Air Conditioner'
        return 'PTAC with hot water heat'
      when 'Packaged Terminal Heat Pump'
        return 'PTHP'
      when 'Packaged Rooftop Air Conditioner'
        return 'PSZ-AC with gas coil heat'
      when 'Packaged Rooftop Heat Pump'
        return 'PSZ-HP'
      when 'Packaged Rooftop VAV with Hot Water Reheat'
        return 'PVAV with reheat'
      when 'Packaged Rooftop VAV with Electric Reheat'
        return 'PVAV with PFP boxes'
      when 'VAV with Hot Water Reheat'
        return 'VAV with reheat'
      when 'VAV with Electric Reheat'
        return 'VAV with PFP boxes'
      else
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.HVACSystem.map_to_cbecs', "HVACSystem ID: #{xget_id}: No mapping for #{principal_hvac_system_type} to CBECS. Using the system type from standards: #{fallback_system_type}")
        return fallback_system_type
      end
    end

    # add hvac
    # @param model [OpenStudio::Model]
    # @param zone_hash [hash]
    # @param standard [Standard]
    # @param system_type [String]
    # @param hvac_delivery_type [String]
    # @param htg_src [String]
    # @param clg_src [String]
    # @param remove_objects [Boolean]
    # @return [Boolean]
    def add_hvac(model, zone_hash, standard, system_type, hvac_delivery_type = 'Forced Air', htg_src = 'NaturalGas', clg_src = 'Electricity', remove_objects = false)
      # remove HVAC objects
      if remove_objects
        standard.model_remove_prm_hvac(model)
      end

      puts "HVAC System ID: #{xget_id}. System_type derived from standards: #{system_type} and principal hvac system type override is: #{get_principal_hvac_system_type}"
      temp = get_principal_hvac_system_type
      if !temp.nil? && !temp.empty?
        previous_system_type = system_type
        system_type = map_to_cbecs(get_principal_hvac_system_type, previous_system_type)
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.HVACSystem.add_hvac', "HVAC System ID: #{xget_id}. System type derived from standards: #{previous_system_type}, overriden to #{system_type}")
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
          # Infer the principal system type
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
          puts "setting system: #{new_system_type} for zone names: #{help_get_zone_name_list(zones)}"
          model.add_cbecs_hvac_system(standard, new_system_type, zones)
        end
      end
      return true
    end

    # get system type from zone
    # @param zone_hash [hash]
    # @param zones [array<OpenStudio::Model::ThermalZone>]
    # @param system_type [String]
    # @return [String]
    def get_system_type_from_zone(zone_hash, zones, system_type)
      zone_hash&.each do |id, zone_list|
        zone_name_list = help_get_zone_name_list(zone_list)
        zones.each do |zone|
          if zone_name_list.include? zone.name.get
            return map_to_cbecs(get_principal_hvac_system_type, system_type)
          end
        end
      end
      return system_type
    end

    # apply sizing and assumptions
    # @param model [OpenStudio::Model]
    # @param output_path [String]
    # @param standard [Standard]
    # @param primary_bldg_type [String]
    # @param system_type [String]
    # @param climate_zone [String]
    # @return [Boolean]
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

    # principal hvac system type
    attr_reader :principal_hvac_system_type
  end
end
