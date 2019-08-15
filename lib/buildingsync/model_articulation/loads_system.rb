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
require_relative 'building_system'
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
          OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Facility.create_building_system', "Could not add loads for #{space_type.name}. Not expected for #{template}")
          next
        end

        # apply internal load schedules
        # the last bool test it to make thermostat schedules. They are now added in HVAC section instead of here
        standard.space_type_apply_internal_load_schedules(space_type, true, true, true, true, true, true, false)

        # here we adjust the people schedules according to user input of hours per week and weeks per year
        adjust_people_schedule(space_type, get_building_section(building_sections, space_type.standardsBuildingType, space_type.standardsSpaceType), model)

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
      return true
    end

    def get_building_section(building_sections, standard_building_type, standard_space_type)
      puts "building_sections: #{building_sections}"
      puts "standard_building_type: #{standard_building_type}"
      puts "standard_space_type: #{standard_space_type}"
      if building_sections.count == 1
        return building_sections[0]
      end
      building_sections.each do |section|
        puts "section #{section}"
        puts "section.occupancy_type #{section.occupancy_type}"
        if section.occupancy_type == standard_building_type
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

    def adjust_people_schedule(space_type, building_section, model)
      default_sch_set = space_type.defaultScheduleSet.get
      if building_section && building_section.typical_occupant_usage_value_hours
        # should we just assume constant schedule for the number of hours per week/day or adjust the existing schedules?
        hours_per_day = building_section.typical_occupant_usage_value_hours.to_f / 7

        off_part = (24 - hours_per_day) / 2

        values = []
        off_part.to_i.times do
          values << 0
        end
        hours_per_day.to_i.times do
          values << 1
        end
        remainder = 24 - 2 * off_part.to_i - hours_per_day.to_i
        if remainder > 0
          values << 1
        end
        last_part = 24 - values.count
        last_part.to_i.times do
          values << 0
        end

        dates = []
        start_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(1), 1)
        end_date = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(12), 31)
        if building_section.typical_occupant_usage_value_weeks
          if building_section.typical_occupant_usage_value_weeks.to_i < 52
            # we assume one week on Christmas and the remainder during summer
            start_date_holiday = start_date + OpenStudio::Time.new(7 * building_section.typical_occupant_usage_value_weeks.to_i/2, 0)
            start_date_christmas = end_date - OpenStudio::Time.new(7, 0)
            end_date_holiday = start_date_christmas - OpenStudio::Time.new(7 * building_section.typical_occupant_usage_value_weeks.to_i/2, 0)
            dates << start_date
            dates << start_date_holiday
            dates << end_date_holiday
            dates << start_date_christmas
            dates << end_date
          end
        end
        default_sch_set.setNumberofPeopleSchedule(add_schedule(model, 'Number Of People', values, dates))
      end
    end

    def add_schedule(model, schedule_name, values, dates)
      # Make a schedule ruleset
      sch_ruleset = OpenStudio::Model::ScheduleRuleset.new(model)
      sch_ruleset.setName(schedule_name.to_s)
      day_sch = sch_ruleset.defaultDaySchedule
      day_sch.setName("#{schedule_name} Default")
      (0..23).each do |i|
        next if values[i] == values[i + 1]
        day_sch.addValue(OpenStudio::Time.new(0, i + 1, 0, 0), values[i])
      end

      if dates.count > 2
        # first we create an empty day schedule
        null_day_sch = OpenStudio::Model::ScheduleDay.new(model)
        null_day_sch.setName(schedule_name.to_s + ' null sched')
        null_day_sch.addValue(OpenStudio::Time.new(0, 24, 0, 0), 0)
        i = 1
        iIndex = 0
        while i < dates.count
          # if we have more than two dates we need to add more rules
          sch_rule = OpenStudio::Model::ScheduleRule.new(sch_ruleset, null_day_sch)
          sch_rule.setName(schedule_name.to_s)
          sch_rule.setStartDate(dates[i])
          i += 1
          sch_rule.setEndDate(dates[i])
          i += 1
          iIndex += 1
        end
      end
      return sch_ruleset
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
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.create_building_system', "Adding Exterior Lights named #{v.exteriorLightsDefinition.name} with design level of #{v.exteriorLightsDefinition.designLevel} * #{OpenStudio.toNeatString(v.multiplier, 0, true)}.")
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
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.create_building_system', 'No elevators added to the building.')
      else
        elevator_def = elevators.electricEquipmentDefinition
        design_level = elevator_def.designLevel.get
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.create_building_system', "Adding #{elevators.multiplier.round(1)} elevators each with power of #{OpenStudio.toNeatString(design_level, 0, true)} (W), plus lights and fans.")
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
