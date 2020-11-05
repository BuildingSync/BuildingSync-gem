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
          adjust_schedules_new5(standard, space_type, get_building_section(building_sections, space_type.standardsBuildingType, space_type.standardsSpaceType), model)
        end
        # extend space type name to include the template. Consider this as well for load defs
        space_type.setName("#{space_type.name} - #{template}")
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.LoadsSystem.add_internal_loads', "Adding loads to space type named #{space_type.name}")
        return true
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

    def adjust_people_schedule_new(standard, space_type, building_section, model)
      # find and create hours of operation
      hours_of_operation = standard.model_infer_hours_of_operation_building(model, gen_occ_profile: true, fraction_of_daily_occ_range: 0.5)

      puts "Test: Created building hours of operation schedule named #{hours_of_operation.name}."

      # report back hours of operation
      hours_of_operation_hash = standard.space_hours_of_operation(model.getSpaces.first)
      puts "Test: Extracted hours of operation schedule from space."
      puts "Test: #{hours_of_operation_hash.keys.first}: #{hours_of_operation_hash.values.inspect}"

      # model_setup_parametric_schedules
      parametric_inputs = standard.model_setup_parametric_schedules(model,gather_data_only: false)
      puts "Test: Generated schedule profile formulas and saved as AdditionalProperties objects for #{parametric_inputs.size} schedules. Inspecting first entry returned."
      #puts "Test: #{parametric_inputs.keys.first.name}: #{parametric_inputs.values.first.inspect}"

      # store original areas as has, add to CSV for altered schedules
      orig_sch_hash = {}
      model.getScheduleRulesets.each do |schedule|
        orig_sch_hash[schedule] = standard.schedule_ruleset_annual_equivalent_full_load_hrs(schedule)
      end
      orig_sch_day_hash = {}
      model.getScheduleDays.each do |sch_day|
        orig_sch_day_hash[sch_day] = standard.day_schedule_equivalent_full_load_hrs(sch_day)
      end

      # model_build_parametric_schedules
      parametric_schedules = standard.model_apply_parametric_schedules(model)
      puts "Test: Updated #{parametric_schedules.size} parametric schedules"

      # save resulting model
      Dir.mkdir('output') unless Dir.exist?('output') # assuming test run from directory it is in
      #model.save("output/test_#{k}.osm", true)

      # loop through parametric schedules and add asserts to compare against orig
      parametric_schedules.each do |k2,v2|
        orig_hours = orig_sch_hash[k2]
        final_hours = standard.schedule_ruleset_annual_equivalent_full_load_hrs(k2)
        delta_hours = orig_hours - final_hours
        percent_change = 100 * delta_hours/orig_hours
        puts "result #{ [k, k2.name.get.to_s, orig_hours, final_hours,delta_hours,percent_change]}"
      end
      puts "Test: Saved schedule input analysis csv"
    end

    def adjust_schedules_new3(standard, space_type, building_section, model)
      parametric_inputs = {}

      space_type.spaces.each do |space|
        default_schedule_set = space.defaultScheduleSet
        if (default_schedule_set.nil? && default_schedule_set.is_a?(OpenStudio::Model::OptionalDefaultScheduleSet))

        else
          default_sch_type = OpenStudio::Model::DefaultScheduleType.new('HoursofOperationSchedule')
        end
      end

      # Go through model and create parametric formulas for all schedules
      parametric_inputs = standard.model_setup_parametric_schedules(model, gather_data_only: false)

      parametric_schedules = []
      model.getScheduleRulesets.sort.each do |sch|
        # here we setup the "simple" rules to get to a 40 hour week
        hours_of_operation = {}
        hours_of_operation[:hoo_hours] = 40
        hours_of_operation[:days_used] = Array(1..366)
        hours_of_operation[:hoo_start] = 9
        hours_of_operation[:hoo_end] = 17
        ruleset_hash = {}
        ruleset_hash[:hoo_inputs] = { :'-1' => hours_of_operation }
        parametric_inputs[sch] = ruleset_hash

        #    formula_string = OpenStudio::Model::OptionalString.new('hoo_start|val_flr|hoo_end|val_flr')

        sch.defaultDaySchedule.additionalProperties.setFeature("param_day_profile", '8:00~0|17:00~1|24:00~0')
        sch.additionalProperties.setFeature("param_sch_floor", 0.0)
        sch.additionalProperties.setFeature("param_sch_ceiling", 1.0)

        # here we attach the param_day_profile additional props so the code actually works
        sch.scheduleRules.each do |rule|
          # remove any use manually generated non parametric rules or any auto-generated rules from prior application of formulas and hoo
          sch_day = rule.daySchedule
          #formula_string = OpenStudio::Model::OptionalString.new('hoo_start|val_flr|hoo_end|val_flr')

          sch_day.additionalProperties.setFeature("param_day_profile", '8:00~0|17:00~1|24:00~0')
        end

        # apply parametric inputs
        standard.schedule_apply_parametric_inputs(sch, 6, false, true, parametric_inputs)

        # add schedule to array
        parametric_schedules << sch

      end

      return parametric_schedules
    end

    def adjust_schedules_new4(standard, this_space_type, building_section, model)
      if !building_section.typical_occupant_usage_value_hours.nil?
        puts_string = "building_section.typical_occupant_usage_value_hours: #{building_section.typical_occupant_usage_value_hours}"

        if this_space_type.nil?
          puts_string +=  ' for all space types'
        else
          puts_string +=  " for space type: #{this_space_type.name}"
        end
        if !building_section.nil?
          puts_string +=  " in building section: #{building_section.id}"
        end
        puts puts_string

        hours_per_week = building_section.typical_occupant_usage_value_hours.to_f

        # pre-process space types to identify which ones to alter
        space_types_to_alter = []
        # if space type is nil we get all space types in the model that are bnot
        if this_space_type.nil?
          model.getSpaceTypes.each do |space_type|
            next if space_type.spaces.empty?
            space_types_to_alter << space_type
          end
        end
        # otherwise we check for the space types we want to alter
        model.getSpaceTypes.each do |space_type|
          if !this_space_type.nil?
            next if space_type != this_space_type
          end
          next if space_type.spaces.empty?
          space_types_to_alter << space_type
        end

        # Convert existing schedules in the model to parametric schedules based on current hours of operation
        standard.model_setup_parametric_schedules(model, step_ramp_logic: nil, infer_hoo_for_non_assigned_objects: true,gather_data_only: false)

        space_types_to_alter.each do |space_type|
          default_schedule_set = space_type.defaultScheduleSet.get

          op_sch = default_schedule_set.hoursofOperationSchedule

          if op_sch.is_initialized
            op_sch = op_sch.get
          else
            op_sch = default_schedule_set.numberofPeopleSchedule.get
          end

          # Infer the current hours of operation schedule for the building
          #op_sch = standard.model_infer_hours_of_operation_building(model, fraction_of_daily_occ_range: 0.25, invert_res: true, gen_occ_profile: false)
          op_sch = op_sch.to_ScheduleRuleset.get
          default_schedule_set.setHoursofOperationSchedule(op_sch)

          # Create start and end times from start time and duration supplied
          wkdy_start_time = BuildingSync::Helper.get_start_time_weekday(op_sch)
          wkdy_end_time = BuildingSync::Helper.get_end_time_weekday(op_sch)
          sat_start_time = BuildingSync::Helper.get_start_time_sat(op_sch)
          sat_end_time = BuildingSync::Helper.get_end_time_sat(op_sch)
          sun_start_time = BuildingSync::Helper.get_start_time_sun(op_sch)
          sun_end_time = BuildingSync::Helper.get_end_time_sun(op_sch)

          current_op_hrs = (wkdy_end_time - wkdy_start_time) * 5 + sat_end_time - sat_start_time + sun_end_time - sun_start_time

          ratio = hours_per_week / current_op_hrs.totalHours

          wkdy_op_hrs_duration_hr = (wkdy_end_time - wkdy_start_time) * ratio
          sat_op_hrs_duration_hr = (sat_end_time - sat_start_time) * ratio
          sun_op_hrs_duration_hr = (sun_end_time - sun_start_time) * ratio
          # weekdays
          if wkdy_op_hrs_duration_hr
            wkdy_end_time = wkdy_start_time + wkdy_op_hrs_duration_hr
          end
          # saturday
          if sat_op_hrs_duration_hr
            sat_end_time = sat_start_time + sat_op_hrs_duration_hr
          end
          # saturday
          if sun_op_hrs_duration_hr
            sun_end_time = sun_start_time + sun_op_hrs_duration_hr
          end

          # Modify hours of operation, using weekdays values for all weekdays and weekend values for Saturday and Sunday
          standard.schedule_ruleset_set_hours_of_operation(op_sch,
                                                           wkdy_start_time: wkdy_start_time,
                                                           wkdy_end_time: wkdy_end_time,
                                                           sat_start_time: sat_start_time,
                                                           sat_end_time: sat_end_time,
                                                           sun_start_time: sun_start_time,
                                                           sun_end_time: sun_end_time)

          f = File.open('Test.csv', 'w')
          BuildingSync::Helper.print_schedule(f, op_sch)
          f.close
          # Apply new operating hours to parametric schedules to make schedules in model reflect modified hours of operation
          parametric_schedules = standard.model_apply_parametric_schedules(model, ramp_frequency: 30, infer_hoo_for_non_assigned_objects: true, error_on_out_of_order: true)
          return
          #BuildingSync::Helper.print_all_schedules("#{parametric_schedules.name}", parametric_schedules)
        end
      end
    end

    def adjust_schedules_new5(standard, space_type, building_section, model)
      # this uses code from https://github.com/NREL/openstudio-extension-gem/blob/6f8f7a46de496c3ab95ed9c72d4d543bd4b67740/lib/openstudio/extension/core/os_lib_model_generation.rb#L3007
      #
      # hours of operation
      if !building_section.typical_occupant_usage_value_hours.nil?
        puts_string = "building_section.typical_occupant_usage_value_hours: #{building_section.typical_occupant_usage_value_hours}"
        hours_per_week = building_section.typical_occupant_usage_value_hours.to_f

        default_schedule_set = BuildingSync::Helper.get_default_schedule_set(model)
        existing_number_of_people_sched = BuildingSync::Helper.get_schedule_rule_set_from_schedule(default_schedule_set.numberofPeopleSchedule)

        calc_hours_per_week = BuildingSync::Helper.calculate_hours(existing_number_of_people_sched)
        ratio_hours_per_week = hours_per_week / calc_hours_per_week

        wkdy_start_time = BuildingSync::Helper.get_start_time_weekday(existing_number_of_people_sched)
        wkdy_end_time = BuildingSync::Helper.get_end_time_weekday(existing_number_of_people_sched)
        wkdy_hours = wkdy_end_time - wkdy_start_time

        sat_start_time = BuildingSync::Helper.get_start_time_sat(existing_number_of_people_sched)
        sat_end_time = BuildingSync::Helper.get_end_time_sat(existing_number_of_people_sched)
        sat_hours = sat_end_time - sat_start_time

        sun_start_time = BuildingSync::Helper.get_start_time_sun(existing_number_of_people_sched)
        sun_end_time = BuildingSync::Helper.get_end_time_sun(existing_number_of_people_sched)
        sun_hours = sun_end_time - sun_start_time

        # determine new end times via ratios
        wkdy_end_time = wkdy_start_time + OpenStudio::Time.new(ratio_hours_per_week * wkdy_hours.totalDays)
        sat_end_time = sat_start_time + OpenStudio::Time.new(ratio_hours_per_week * sat_hours.totalDays)
        sun_end_time = sun_start_time + OpenStudio::Time.new(ratio_hours_per_week * sun_hours.totalDays)

        # Infer the current hours of operation schedule for the building
        op_sch = standard.model_infer_hours_of_operation_building(model)
        default_schedule_set.setHoursofOperationSchedule(op_sch)

        BuildingSync::Helper.print_all_schedules("org_schedules-#{space_type.name}.csv", default_schedule_set)

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
      end
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
