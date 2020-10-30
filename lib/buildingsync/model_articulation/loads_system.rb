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
require_relative 'building_system'
require_relative '../helpers/parametric_schedule_helper'
require_relative '../helpers/hours_of_operation'
require 'openstudio/extension/core/os_lib_schedules.rb'

module BuildingSync
  class LoadsSystem < BuildingSystem
    # initialize
    def initialize(system_element = '', ns = '')
      # code to initialize
    end

    # add internal loads from standard definitions
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

      model.getSpaceTypes.each do |space_type|
        # Don't add infiltration here; will be added later in the script
        test = standard.space_type_apply_internal_loads(space_type, true, true, true, true, true, false)
        if test == false
          OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.LoadsSystem.add_internal_loads', "Could not add loads for #{space_type.name}. Not expected for #{template}")
          next
        end

        # apply internal load schedules
        # the last bool test it to make thermostat schedules. They are now added in HVAC section instead of here
        standard.space_type_apply_internal_load_schedules(space_type, true, true, true, true, true, true, false)

        # here we adjust the people schedules according to user input of hours per week and weeks per year
        if !building_sections.empty?
          adjust_people_schedule(space_type, get_building_section(building_sections, space_type.standardsBuildingType, space_type.standardsSpaceType), model)
        end
        # extend space type name to include the template. Consider this as well for load defs
        space_type.setName("#{space_type.name} - #{template}")
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.LoadsSystem.add_internal_loads', "Adding loads to space type named #{space_type.name}")
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

    def get_building_section(building_sections, standard_building_type, standard_space_type)
      if building_sections.count == 1
        return building_sections[0]
      end
      building_sections.each do |section|
        if section.occupancy_type.to_s == standard_building_type.to_s
          return section if section.space_types
          section.space_types.each do |space_type_name, hash|
            if space_type_name == standard_space_type
              puts "space_type_name #{space_type_name}"
              return section
            end
          end
        end
      end
      return nil
    end

    ##
    # adjust people schedule
    ##
    # @param space_type [SpaceType]
    # @param building_section [BuildingSection]
    # @param model [OpenStudio::Model]
    # @return boolean
    def adjust_people_schedule(space_type, building_section, model)
      if !building_section.typical_occupant_usage_value_hours.nil?
        puts_string = "building_section.typical_occupant_usage_value_hours: #{building_section.typical_occupant_usage_value_hours}"

        if space_type.nil?
          puts_string +=  ' for all space types'
        else
          puts_string +=  " for space type: #{space_type.name}"
        end
        if !building_section.nil?
          puts_string +=  " in building section: #{building_section.id}"
        end
        puts puts_string

        hours_per_week = building_section.typical_occupant_usage_value_hours.to_f
        # setting default values
        hours_of_operation = HoursOfOperation.new(hours_per_week)
        return BuildingSync::ParametricScheduleHelper.process_schedules(model, space_type, hours_of_operation)
      end
      return false
    end

    def add_exterior_lights(model, standard, onsite_parking_fraction, exterior_lighting_zone, remove_objects)
      if remove_objects
        model.getExteriorLightss.each do |ext_light|
          next if ext_light.name.to_s.include?('Fuel equipment') # some prototype building types model exterior elevators by this name

          ext_light.remove
        end
      end

      exterior_lights = standard.model_add_typical_exterior_lights(model, exterior_lighting_zone.chars[0].to_i, onsite_parking_fraction)
      exterior_lights.each do |k, v|
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.LoadsSystem.add_exterior_lights', "Adding Exterior Lights named #{v.exteriorLightsDefinition.name} with design level of #{v.exteriorLightsDefinition.designLevel} * #{OpenStudio.toNeatString(v.multiplier, 0, true)}.")
      end
      return true
    end

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

    def add_day_lighting_controls(model, standard, template)
      # add daylight controls, need to perform a sizing run for 2010
      if template == '90.1-2010'
        if standard.model_run_sizing_run(model, "#{Dir.pwd}/SRvt") == false
          return false
        end
      end
      standard.model_add_daylighting_controls(model)
      return true
    end
  end
end
