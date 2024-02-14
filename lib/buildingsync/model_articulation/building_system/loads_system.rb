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
require 'openstudio/extension/core/os_lib_schedules.rb'

require 'buildingsync/helpers/helper'
require_relative 'building_system'

module BuildingSync
  # LoadsSystem class that manages internal and external loads
  class LoadsSystem < BuildingSystem
    include BuildingSync::Helper
    # initialize
    # @param system_element [REXML::Element]
    # @param ns [String]
    def initialize(system_element = '', ns = '')
      # code to initialize
    end

    # add internal loads from standard definitions
    # @param model [OpenStudio::Model]
    # @param standard [Standard]
    # @param template [String]
    # @param building_sections [REXML:Element]
    # @param remove_objects [Boolean]
    # @return [Boolean]
    def add_internal_loads(model, standard, template, building_sections, remove_objects)
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

      OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.LoadsSystem.add_internal_loads', 'Adding internal loads')
      count_not_found = 0
      model.getSpaceTypes.each do |space_type|
        data = standard.space_type_get_standards_data(space_type)
        if data.empty?
          original_building_type = space_type.standardsBuildingType.get
          alternate_building_type = standard.model_get_lookup_name(original_building_type)
          if alternate_building_type != original_building_type
            space_type.setStandardsBuildingType(alternate_building_type)
            data = standard.space_type_get_standards_data(space_type)
            if data.empty?
              OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.LoadsSystem.add_internal_loads', "Unable to get standards data for Space Type: #{space_type.name}.  Tried standards building type: #{original_building_type} and #{alternate_building_type} with standards space type: #{space_type.standardsSpaceType.get}")
              count_not_found += 1
              next
            else
              OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.LoadsSystem.add_internal_loads', "Space Type: #{space_type.name}. Standards building type changed from #{original_building_type} to #{alternate_building_type} with standards space type: #{space_type.standardsSpaceType.get}")
            end
          else
            OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.LoadsSystem.add_internal_loads', "Unable to get standards data for Space Type: #{space_type.name}.  Standards building type: #{space_type.standardsBuildingType.get}, space type: #{space_type.standardsSpaceType.get}")
            count_not_found += 1
            next
          end
        end
        # Don't add infiltration here; will be added later in the script
        test = standard.space_type_apply_internal_loads(space_type, true, true, true, true, true, false)
        if test == false
          OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.LoadsSystem.add_internal_loads', "Could not add loads for #{space_type.name}. Not expected for #{template}")
          next
        end

        # apply internal load schedules
        # the last bool test it to make thermostat schedules. They are now added in HVAC section instead of here
        success = standard.space_type_apply_internal_load_schedules(space_type, true, true, true, true, true, true, false)
        if !success
          OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.LoadsSystem.add_internal_loads', "space_type_apply_internal_load_schedules unsuccessful for #{space_type.name}")
        end

        # here we adjust the people schedules according to user input of hours per week and weeks per year
        if !building_sections.empty?
          adjust_schedules(standard, space_type, get_building_occupancy_hours(building_sections), model)
        end
        # extend space type name to include the template. Consider this as well for load defs
        space_type.setName("#{space_type.name} - #{template}")
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.LoadsSystem.add_internal_loads', "Adding loads to space type named #{space_type.name}")
      end

      if count_not_found > 0
        OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.LoadsSystem.add_internal_loads', "#{count_not_found} of #{model.getSpaceTypes.size} Space Types have no internal loads")
      end

      # warn if spaces in model without space type
      spaces_without_space_types = []
      model.getSpaces.each do |space|
        next if space.spaceType.is_initialized

        spaces_without_space_types << space
      end
      if !spaces_without_space_types.empty?
        OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.LoadsSystem.add_internal_loads', "#{spaces_without_space_types.size} spaces do not have space types assigned, and wont' receive internal loads from standards space type lookups.")
      end
      return true
    end

    # add occupancy peak
    # @param model [OpenStudio::Model]
    # @param new_occupancy_peak [String]
    # @param area [String]
    # @param space_types [REXML:Element]
    def adjust_occupancy_peak(model, new_occupancy_peak, area, space_types)
      # we assume that the standard always generate people per area
      sum_of_people_per_area = 0.0
      count = 0
      if !space_types.nil?
        sorted_space_types = model.getSpaceTypes.sort
        sorted_space_types.each do |space_type|
          if space_types.include? space_type
            peoples = space_type.people
            peoples.each do |people|
              sum_of_people_per_area += people.peoplePerFloorArea.get
              count += 1
            end
          end
        end
        average_people_per_area = sum_of_people_per_area / count
        puts "existing occupancy: #{average_people_per_area} new target value: #{new_occupancy_peak.to_f / area.to_f}"
        new_sum_of_people_per_area = 0.0
        sorted_space_types.each do |space_type|
          if space_types.include? space_type
            peoples = space_type.people
            peoples.each do |people|
              ratio = people.peoplePerFloorArea.get.to_f / average_people_per_area.to_f
              new_value = ratio * new_occupancy_peak.to_f / area.to_f
              puts "adjusting occupancy per area value from: #{people.peoplePerFloorArea.get} by ratio #{ratio} to #{new_value}"
              people.peopleDefinition.setPeopleperSpaceFloorArea(new_value)
              new_sum_of_people_per_area += new_value
            end
          end
        end
        puts "resulting total absolute occupancy value: #{new_sum_of_people_per_area * area.to_f} occupancy per area value: #{new_sum_of_people_per_area / count}"
      else
        puts 'space types are empty'
      end
    end

    # get building occupancy hours
    # @param building_sections [array]
    # @return [Float]
    def get_building_occupancy_hours(building_sections)
      if building_sections.count == 1
        return building_sections[0].typical_occupant_usage_value_hours.to_f
      end
      occupancy_hours = nil
      count = 0.0
      building_sections.each do |section|
        occupancy_hours = 0.0 if occupancy_hours.nil?
        occupancy_hours += section.typical_occupant_usage_value_hours.to_f if section.typical_occupant_usage_value_hours.nil?
        count += 1 if section.typical_occupant_usage_value_hours.nil?
      end
      return nil if occupancy_hours.nil?
      return occupancy_hours / count
    end

    # adjust schedules
    # @param standard [Standard]
    # @param space_type [OpenStudio::Model::SpaceType]
    # @param building_occupant_hours_per_week [Float]
    # @param model [OpenStudio::Model]
    # @return boolean
    def adjust_schedules(standard, space_type, building_occupant_hours_per_week, model)
      # this uses code from https://github.com/NREL/openstudio-extension-gem/blob/6f8f7a46de496c3ab95ed9c72d4d543bd4b67740/lib/openstudio/extension/core/os_lib_model_generation.rb#L3007
      #
      # currently this works for all schedules in the model
      # in the future we would want to make this more flexible to adjusted based on space_types or building sections
      return unless !building_occupant_hours_per_week.nil?
      hours_per_week = building_occupant_hours_per_week

      default_schedule_set = help_get_default_schedule_set(model)
      existing_number_of_people_sched = help_get_schedule_rule_set_from_schedule(default_schedule_set.numberofPeopleSchedule)
      return false if existing_number_of_people_sched.nil?
      calc_hours_per_week = help_calculate_hours(existing_number_of_people_sched)
      ratio_hours_per_week = hours_per_week / calc_hours_per_week

      wkdy_start_time = help_get_start_time_weekday(existing_number_of_people_sched)
      wkdy_end_time = help_get_end_time_weekday(existing_number_of_people_sched)
      wkdy_hours = wkdy_end_time - wkdy_start_time

      sat_start_time = help_get_start_time_sat(existing_number_of_people_sched)
      sat_end_time = help_get_end_time_sat(existing_number_of_people_sched)
      sat_hours = sat_end_time - sat_start_time

      sun_start_time = help_get_start_time_sun(existing_number_of_people_sched)
      sun_end_time = help_get_end_time_sun(existing_number_of_people_sched)
      sun_hours = sun_end_time - sun_start_time

      # determine new end times via ratios
      wkdy_end_time = wkdy_start_time + OpenStudio::Time.new(ratio_hours_per_week * wkdy_hours.totalDays)
      sat_end_time = sat_start_time + OpenStudio::Time.new(ratio_hours_per_week * sat_hours.totalDays)
      sun_end_time = sun_start_time + OpenStudio::Time.new(ratio_hours_per_week * sun_hours.totalDays)

      # Infer the current hours of operation schedule for the building
      op_sch = standard.model_infer_hours_of_operation_building(model)
      default_schedule_set.setHoursofOperationSchedule(op_sch)

      # help_print_all_schedules("org_schedules-#{space_type.name}.csv", default_schedule_set)

      # Convert existing schedules in the model to parametric schedules based on current hours of operation
      standard.model_setup_parametric_schedules(model)

      # Modify hours of operation, using weekdays values for all weekdays and weekend values for Saturday and Sunday
      standard.schedule_ruleset_set_hours_of_operation(op_sch,
                                                       wkdy_start_time: wkdy_start_time,
                                                       wkdy_end_time: wkdy_end_time,
                                                       sat_start_time: sat_start_time,
                                                       sat_end_time: sat_end_time,
                                                       sun_start_time: sun_start_time,
                                                       sun_end_time: sun_end_time)

      # Apply new operating hours to parametric schedules to make schedules in model reflect modified hours of operation
      parametric_schedules = standard.model_apply_parametric_schedules(model, error_on_out_of_order: false)
      puts "Updated #{parametric_schedules.size} schedules with new hours of operation."
      return true
    end

    # add elevator
    # @param model [OpenStudio::Model]
    # @param standard [Standard]
    # @return boolean
    def add_elevator(model, standard)
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
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.LoadsSystem.add_elevator', 'No elevators added to the building.')
      else
        elevator_def = elevators.electricEquipmentDefinition
        design_level = elevator_def.designLevel.get
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.LoadsSystem.add_elevator', "Adding #{elevators.multiplier.round(1)} elevators each with power of #{OpenStudio.toNeatString(design_level, 0, true)} (W), plus lights and fans.")
      end
      return true
    end
  end
end
