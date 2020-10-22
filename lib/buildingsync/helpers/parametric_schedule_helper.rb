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
  class ParametricScheduleHelper
    def self.process_schedules(model, this_space_type, hours_of_operation, htg_setpoint = 67.0, clg_setpoint = 75.0, setback_delta = 4)
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
      # this is the new way of integrating the parametric schedule feature
      # add in logic for hours per week override
      # add to this for day types that should use weekday instead of user entered profile
      profile_override, hours_of_operation = get_profile_override(hours_of_operation)

      # get the profiles
      profiles = get_profiles

      space_types_to_alter.each do |space_type|
        default_schedule_set = space_type.defaultScheduleSet.get
        default_schedule_set.setName(default_schedule_set.name.get + " parameterised")
        # alter all objects
        thermostats_to_alter, air_loops_to_alter, water_use_equipment_to_alter = remove_old_schedules(model, space_type)
        # schedules of the default schedule set
        default_schedule_set.setHoursofOperationSchedule(create_schedule_hours_of_operations(model, hours_of_operation))
        default_schedule_set.setPeopleActivityLevelSchedule(create_schedule_activity(model))
        default_schedule_set.setLightingSchedule(create_schedule_lighting(model, profiles['lighting'], profile_override, hours_of_operation))
        default_schedule_set.setElectricEquipmentSchedule(create_schedule_electric_equipment(model, profiles['electric_equipment'], profile_override, hours_of_operation))
        default_schedule_set.setGasEquipmentSchedule(create_schedule_gas_equipment(model, profiles['gas_equipment'], profile_override, hours_of_operation))
        default_schedule_set.setNumberofPeopleSchedule(create_schedule_occupancy(model, profiles['occupancy'], profile_override, hours_of_operation))
        default_schedule_set.setInfiltrationSchedule(create_schedule_infiltration(model, profiles['infiltration'], profile_override, hours_of_operation))

        # apply HVAC schedules
        hvac_availability_sch = create_schedule_hvac_availability(model, profiles['hvac_availability'], profile_override, hours_of_operation)
        air_loops_to_alter.each do |air_loop|
          air_loop.setAvailabilitySchedule(hvac_availability_sch)
        end

        # apply heating and cooling setpoint schedules
        setpoint_sch = create_schedule_heating_cooling(model, profiles['thermostat_setback'], htg_setpoint, clg_setpoint, setback_delta, profile_override, hours_of_operation)
        thermostats_to_alter.each do |thermostat|
          thermostat.setHeatingSchedule(setpoint_sch[0])
          thermostat.setCoolingSchedule(setpoint_sch[1])
        end

        # SHW schedule
        swh_sch = create_schedule_SHW(model, profiles['swh'], profile_override, hours_of_operation)
        water_use_equipment_to_alter.each do |water_use_equipment|
          water_use_equipment.setFlowRateFractionSchedule(swh_sch)
        end
      end

      # if there are no space types in the model we create the default schedule set at the building level
      if space_types_to_alter.length == 0
        default_schedule_set = OpenStudio::Model::DefaultScheduleSet.new(model)
        default_schedule_set.setName('Parametric Hours of Operation Schedule Set')

        default_schedule_set.setHoursofOperationSchedule(create_schedule_hours_of_operations(model, hours_of_operation))
        default_schedule_set.setPeopleActivityLevelSchedule(create_schedule_activity(model))
        default_schedule_set.setLightingSchedule(create_schedule_lighting(model, profiles['lighting'], profile_override, hours_of_operation))
        default_schedule_set.setElectricEquipmentSchedule(create_schedule_electric_equipment(model, profiles['electric_equipment'], profile_override, hours_of_operation))
        default_schedule_set.setGasEquipmentSchedule(create_schedule_gas_equipment(model, profiles['gas_equipment'], profile_override, hours_of_operation))
        default_schedule_set.setNumberofPeopleSchedule(create_schedule_occupancy(model, profiles['occupancy'], profile_override, hours_of_operation))
        default_schedule_set.setInfiltrationSchedule(create_schedule_infiltration(model, profiles['infiltration'], profile_override, hours_of_operation))
        model.getBuilding.setDefaultScheduleSet(default_schedule_set)
      end
      return true
    end

    def self.get_profiles(profiles = nil)
      if profiles.nil?
        profiles = {}
      end
      # set the default profiles
      if profiles['lighting'].nil?
        string = []
        string << ':default => [[start-2,0.1],[start-1,0.3],[start,0.75],[end,0.75],[end+2,0.3],[end+vac*0.5,0.1]]'
        string << ':saturday => [[start-1,0.1],[start,0.3],[end,0.3],[end+1,0.1]]'
        string << ':sunday => [[start,0.1],[end,0.1]]'
        profiles['lighting'] = string.join(', ')
      end
      if profiles['electric_equipment'].nil?
        string = []
        string << ':default => [[start-1,0.3],[start,0.85],[start+0.5*occ-0.5,0.85],[start+0.5*occ-0.5,0.75],[start+0.5*occ+0.5,0.75],[start+0.5*occ+0.5,0.85],[end,0.85],[end+1,0.45],[end+2,0.3]]'
        string << ':saturday => [[start-2,0.2],[start,0.35],[end,0.35],[end+6,0.2]]'
        string << ':sunday => [[start,0.2],[end,0.2]]'
      profiles['electric_equipment'] = string.join(', ')
      end
      if profiles['gas_equipment'].nil?
        string = []
        string << ':default => [[start-1,0.3],[start,0.85],[start+0.5*occ-0.5,0.85],[start+0.5*occ-0.5,0.75],[start+0.5*occ+0.5,0.75],[start+0.5*occ+0.5,0.85],[end,0.85],[end+1,0.45],[end+2,0.3]]'
        string << ':saturday => [[start-2,0.2],[start,0.35],[end,0.35],[end+6,0.2]]'
        string << ':sunday => [[start,0.2],[end,0.2]]'
      profiles['gas_equipment'] = string.join(', ')
      end
      if profiles['occupancy'].nil?
        string = []
        string << ':default => [[start-3,0],[start-1,0.2],[start,0.95],[start+0.5*occ-0.5,0.95],[start+0.5*occ-0.5,0.5],[start+0.5*occ+0.5,0.5],[start+0.5*occ+0.5,0.95],[end,0.95],[end+1,0.3],[end+vac*0.4,0]]'
        string << ':saturday => [[start-3,0],[start,0.3],[end,0.3],[end+1,0.1],[end+vac*0.3,0]]'
        string << ':sunday => [[start,0],[start,0.05],[end,0.05],[end,0]]'
      profiles['occupancy'] = string.join(', ')
      end
      if profiles['infiltration'].nil?
        string = []
        string << ':default => [[start,1],[start,0.25],[end+vac*0.35,0.25],[end+vac*0.35,1]]'
        string << ':saturday => [[start,1],[start,0.25],[end+vac*0.25,0.25],[end+vac*0.25,1]]'
        string << ':sunday => [[start,1],[start,0.25],[end+vac*0.25,0.25],[end+vac*0.25,1]]'
      profiles['infiltration'] = string.join(', ')
      end
      if profiles['hvac_availability'].nil?
        string = []
        string << ':default => [[start,0],[start,1],[end+vac*0.35,1],[end+vac*0.35,0]]'
        string << ':saturday => [[start,0],[start,1],[end+vac*0.25,1],[end+vac*0.25,0]]'
        string << ':sunday => [[start,0],[start,1],[end+vac*0.25,1],[end+vac*0.25,0]]'
      profiles['hvac_availability'] = string.join(', ')
      end
      if profiles['swh'].nil?
        string = []
        string << ':default => [[start-2,0],[start-2,0.07],[start+0.5*occ,0.57],[vac-2,0.33],[vac,0.44],[end+vac*0.35,0.05],[end+vac*0.35,0]]'
        string << ':saturday => [[start-2,0],[start-2,0.07],[start+0.5*occ,0.23],[end+vac*0.25,0.05],[end+vac*0.25,0]]'
        string << ':sunday => [[start-2,0],[start-2,0.04],[start+0.5*occ,0.09],[end+vac*0.25,0.04],[end+vac*0.25,0]]'
      profiles['swh'] = string.join(', ')
      end
      if profiles['thermostat_setback'].nil?
        string = []
        string << ':default => [[start-2,floor],[start-2,ceiling],[end+vac*0.35,ceiling],[end+vac*0.35,floor]]'
        string << ':saturday => [[start-2,floor],[start-2,ceiling],[end+vac*0.25,ceiling],[end+vac*0.25,floor]]'
        string << ':sunday => [[start-2,floor],[start-2,ceiling],[end+vac*0.25,ceiling],[end+vac*0.25,floor]]'
      profiles['thermostat_setback'] = string.join(', ')
      end

      return profiles
    end

    def self.get_profile_override(hoo)
      profile_override = []
      if hoo.hours_per_week > 0.0
        if hoo.hours_per_week > 84
          max_hoo = [hoo.hours_per_week / 7.0, 24.0].min
        else
          max_hoo = 12.0
        end

        # for 60 horus per week or less only alter weekday. If longer then use weekday profiles for saturday for 12 hours and then sunday
        typical_weekday_input_hours = hoo.end_wkdy - hoo.start_wkdy
        target_weekday_hours = [hoo.hours_per_week / 5.0, max_hoo].min
        delta_hours_per_day = target_weekday_hours - typical_weekday_input_hours

        # shift hours as needed
        hoo.start_wkdy -= delta_hours_per_day / 2.0
        hoo.end_wkdy += delta_hours_per_day / 2.0

        # add logic if more than 60 hours
        if hoo.hours_per_week > 60.0
          # for 60-72 horus per week or less only alter saturday.
          typical_weekday_input_hours = hoo.end_sat - hoo.start_sat
          target_weekday_hours = [(hoo.hours_per_week - 60.0), max_hoo].min
          delta_hours_per_day = target_weekday_hours - typical_weekday_input_hours

          # code in process_hash method will alter saturday to use default profile formula

          # shift hours as needed
          hoo.start_sat -= delta_hours_per_day / 2.0
          hoo.end_sat += delta_hours_per_day / 2.0
          # set flag to override typical profile
          profile_override << 'saturday'
        end

        # add logic if more than 72 hours
        if hoo.hours_per_week > 72.0
          # for 60-72 horus per week or less only alter sunday.
          typical_weekday_input_hours = hoo.end_sun - hoo.start_sun
          target_weekday_hours = [(hoo.hours_per_week - 72.0), max_hoo].min
          delta_hours_per_day = target_weekday_hours - typical_weekday_input_hours

          # code in process_hash method will alter sunday to use default profile formula

          # shift hours as needed
          hoo.start_sun -= delta_hours_per_day / 2.0
          hoo.end_sun += delta_hours_per_day / 2.0
          # set flag to override typical profile
          profile_override << 'sunday'
        end
      end
      return profile_override, hoo
    end

    def self.remove_old_schedules(model, space_type)
      thermostats_to_alter = []
      air_loops_to_alter = []
      water_use_equipment_to_alter = []
        # remove schedule sets for load instances
        space_type.electricEquipment.each(&:resetSchedule)
        space_type.gasEquipment.each(&:resetSchedule)
        space_type.spaceInfiltrationDesignFlowRates.each(&:resetSchedule)
        space_type.people.each(&:resetNumberofPeopleSchedule)
        # don't have to remove HVAC and setpoint schedules, they will be replaced individually

        # loop through spaces to populate thermostats and airloops
        space_type.spaces.each do |space|
          thermal_zone = space.thermalZone
          if thermal_zone.is_initialized
            thermal_zone = thermal_zone.get

            # get thermostat
            thermostat = thermal_zone.thermostatSetpointDualSetpoint
            if thermostat.is_initialized
              thermostats_to_alter << thermostat.get
            end

            # get air loop
            air_loop = thermal_zone.airLoopHVAC
            if air_loop.is_initialized
              air_loops_to_alter << air_loop.get
            end
          end

          # get water use equipment
          space.waterUseEquipment.each do |water_use_equipment|
            water_use_equipment_to_alter << water_use_equipment
          end
        end
      return thermostats_to_alter, air_loops_to_alter, water_use_equipment_to_alter
    end

    def self.create_schedule_hours_of_operations(model, hoo)
      # populate hours of operation schedule for schedule set (this schedule isn't used but in future could be used to dynamically generate schedules)
      ruleset_name = 'Parametric Hours of Operation Schedule'
      winter_design_day = nil
      summer_design_day = nil
      rules = []
      if hoo.end_wkdy == hoo.start_wkdy
        default_day = ['Weekday', [hoo.start_wkdy, 0], [hoo.end_wkdy, 0], [24, 0]]
      elsif hoo.end_wkdy > hoo.start_wkdy
        default_day = ['Weekday', [hoo.start_wkdy, 0], [hoo.end_wkdy, 1], [24, 0]]
      else
        default_day = ['Weekday', [hoo.end_wkdy, 1], [hoo.start_wkdy, 0], [24, 1]]
      end
      if hoo.end_sat == hoo.start_sat
        rules << ['Saturday', '1/1-12/31', 'Sat', [hoo.start_sat, 0], [hoo.end_sat, 0], [24, 0]]
      elsif hoo.end_sat > hoo.start_sat
        rules << ['Saturday', '1/1-12/31', 'Sat', [hoo.start_sat, 0], [hoo.end_sat, 1], [24, 0]]
      else
        rules << ['Saturday', '1/1-12/31', 'Sat', [hoo.end_sat, 1], [hoo.start_sat, 0], [24, 1]]
      end
      if hoo.end_sun == hoo.start_sun
        rules << ['Sunday', '1/1-12/31', 'Sun', [hoo.start_sun, 0], [hoo.end_sun, 0], [24, 0]]
      elsif hoo.end_sun > hoo.start_sun
        rules << ['Sunday', '1/1-12/31', 'Sun', [hoo.start_sun, 0], [hoo.end_sun, 1], [24, 0]]
      else
        rules << ['Sunday', '1/1-12/31', 'Sun', [hoo.end_sun, 1], [hoo.start_sun, 0], [24, 1]]
      end
      options = {'name' => ruleset_name,
                 'winter_design_day' => winter_design_day,
                 'summer_design_day' => summer_design_day,
                 'default_day' => default_day,
                 'rules' => rules}
      return OsLib_Schedules.createComplexSchedule(model, options)
    end

    def self.create_schedule_activity(model)
      # create activity schedule
      # todo - save this from model or add user argument
      ruleset_name = 'Parametric Activity Schedule'
      winter_design_day = [[24, 120]]
      summer_design_day = [[24, 120]]
      default_day = ['Weekday', [24, 120]]
      rules = []
      options = { 'name' => ruleset_name,
                  'winter_design_day' => winter_design_day,
                  'summer_design_day' => summer_design_day,
                  'default_day' => default_day,
                  'rules' => rules }
      return OsLib_Schedules.createComplexSchedule(model, options)
    end

    def self.create_schedule_lighting(model, lighting_profiles, profile_override, hoo)
      # generate and apply lighting schedule using hours of operation schedule and parametric inputs
      ruleset_name = 'Parametric Lighting Schedule'
      hash = process_hash(lighting_profiles, profile_override, ruleset_name, hoo)
      if !hash then OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.LoadsSystem.create_schedue', "Failed to generate #{ruleset_name}"); return false end
      winter_design_day = [[24, 0]]
      summer_design_day = [[24, 1]]
      default_day = hash[:default]
      rules = []
      rules << ['Saturday', '1/1-12/31', 'Sat'] + hash[:saturday].to_a
      rules << ['Sunday', '1/1-12/31', 'Sun'] + hash[:sunday].to_a
      options = { 'name' => ruleset_name,
                  'winter_design_day' => winter_design_day,
                  'summer_design_day' => summer_design_day,
                  'default_day' => default_day,
                  'rules' => rules }

      lighting_sch = OsLib_Schedules.createComplexSchedule(model, options)
      lighting_sch.setComment(lighting_profiles)
      return lighting_sch
    end

    def self.create_schedule_electric_equipment(model, electric_equipment_profiles, profile_override, hoo)
      # generate and apply electric_equipment schedule using hours of operation schedule and parametric inputs
      ruleset_name = 'Parametric Electric Equipment Schedule'
      hash = process_hash(electric_equipment_profiles, profile_override, ruleset_name, hoo)
      if !hash then OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.LoadsSystem.create_schedue', "Failed to generate #{ruleset_name}"); return false end
      winter_design_day = [[24, 0]]
      summer_design_day = [[24, 1]]
      default_day = hash[:default]
      rules = []
      rules << ['Saturday', '1/1-12/31', 'Sat'] + hash[:saturday].to_a
      rules << ['Sunday', '1/1-12/31', 'Sun'] + hash[:sunday].to_a
      options = { 'name' => ruleset_name,
                  'winter_design_day' => winter_design_day,
                  'summer_design_day' => summer_design_day,
                  'default_day' => default_day,
                  'rules' => rules }
      electric_equipment_sch = OsLib_Schedules.createComplexSchedule(model, options)
      electric_equipment_sch.setComment(electric_equipment_profiles)
      return electric_equipment_sch
    end

    def self.create_schedule_gas_equipment(model, gas_equipment_profiles, profile_override, hoo)
      # generate and apply gas_equipment schedule using hours of operation schedule and parametric inputs
      ruleset_name = 'Parametric Gas Equipment Schedule'
      hash = process_hash(gas_equipment_profiles, profile_override, ruleset_name, hoo)
      if !hash then OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.LoadsSystem.create_schedue', "Failed to generate #{ruleset_name}"); return false end
      winter_design_day = [[24, 0]]
      summer_design_day = [[24, 1]]
      default_day = hash[:default]
      rules = []
      rules << ['Saturday', '1/1-12/31', 'Sat'] + hash[:saturday].to_a
      rules << ['Sunday', '1/1-12/31', 'Sun'] + hash[:sunday].to_a
      options = { 'name' => ruleset_name,
                  'winter_design_day' => winter_design_day,
                  'summer_design_day' => summer_design_day,
                  'default_day' => default_day,
                  'rules' => rules }
      gas_equipment_sch = OsLib_Schedules.createComplexSchedule(model, options)
      gas_equipment_sch.setComment(gas_equipment_profiles)
      return gas_equipment_sch
    end

    def self.create_schedule_occupancy(model, occupancy_profiles, profile_override, hoo)
      # generate and apply occupancy schedule using hours of operation schedule and parametric inputs
      ruleset_name = 'Parametric Occupancy Schedule'
      hash = process_hash(occupancy_profiles, profile_override, ruleset_name, hoo)
      if !hash then OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.LoadsSystem.create_schedue', "Failed to generate #{ruleset_name}"); return nil end
      winter_design_day = [[24, 0]] # if DCV would we want this at 1, prototype uses 0
      summer_design_day = [[24, 1]]
      default_day = hash[:default]
      rules = []
      rules << ['Saturday', '1/1-12/31', 'Sat'] + hash[:saturday].to_a
      rules << ['Sunday', '1/1-12/31', 'Sun'] + hash[:sunday].to_a
      options = { 'name' => ruleset_name,
                  'winter_design_day' => winter_design_day,
                  'summer_design_day' => summer_design_day,
                  'default_day' => default_day,
                  'rules' => rules }
      occupancy_sch = OsLib_Schedules.createComplexSchedule(model, options)
      occupancy_sch.setComment(occupancy_profiles)
      return occupancy_sch
    end

    def self.create_schedule_infiltration(model, infiltration_profiles, profile_override, hoo)
      # generate and apply infiltration schedule using hours of operation schedule and parametric inputs
      ruleset_name = 'Parametric Infiltration Schedule'
      hash = process_hash(infiltration_profiles, profile_override, ruleset_name, hoo)
      if !hash then OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.LoadsSystem.create_schedue', "Failed to generate #{ruleset_name}"); return nil end
      winter_design_day = [[24, 1]] # TODO: - should it be 1 for both summer and winter
      summer_design_day = [[24, 1]]
      default_day = hash[:default]
      rules = []
      rules << ['Saturday', '1/1-12/31', 'Sat'] + hash[:saturday].to_a
      rules << ['Sunday', '1/1-12/31', 'Sun'] + hash[:sunday].to_a
      options = { 'name' => ruleset_name,
                  'winter_design_day' => winter_design_day,
                  'summer_design_day' => summer_design_day,
                  'default_day' => default_day,
                  'rules' => rules }
      infiltration_sch = OsLib_Schedules.createComplexSchedule(model, options)
      infiltration_sch.setComment(infiltration_profiles)
      return infiltration_sch
    end

    def self.create_schedule_hvac_availability(model, hvac_availability_profiles, profile_override, hoo)
      # generate and apply hvac_availability schedule using hours of operation schedule and parametric inputs
      ruleset_name = 'Parametric HVAC Availability Schedule'
      hash = process_hash(hvac_availability_profiles, profile_override, ruleset_name, hoo)
      if !hash then OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.LoadsSystem.create_schedue', "Failed to generate #{ruleset_name}"); return nil end
      winter_design_day = [[24, 1]] # TODO: - confirm proper value
      summer_design_day = [[24, 1]] # todo - confirm proper value
      default_day = hash[:default]
      rules = []
      rules << ['Saturday', '1/1-12/31', 'Sat'] + hash[:saturday].to_a
      rules << ['Sunday', '1/1-12/31', 'Sun'] + hash[:sunday].to_a
      options = { 'name' => ruleset_name,
                  'winter_design_day' => winter_design_day,
                  'summer_design_day' => summer_design_day,
                  'default_day' => default_day,
                  'rules' => rules }
      hvac_availability_sch = OsLib_Schedules.createComplexSchedule(model, options)
      hvac_availability_sch.setComment(hvac_availability_profiles)
      return hvac_availability_sch
    end

    def self.create_schedule_heating_cooling(model, thermostat_setback_profiles, htg_setpoint, clg_setpoint, setback_delta, profile_override, hoo)
      # generate and apply heating_setpoint schedule using hours of operation schedule and parametric inputs
      ruleset_name = 'Parametric Heating Setpoint Schedule'

      # htg setpoints
      htg_occ = OpenStudio.convert(htg_setpoint, 'F', 'C').get
      htg_vac = OpenStudio.convert(htg_setpoint - setback_delta, 'F', 'C').get

      # replace floor and ceiling with user specified values
      htg_setpoint_profiles = thermostat_setback_profiles.gsub('ceiling', htg_occ.to_s)
      htg_setpoint_profiles = htg_setpoint_profiles.gsub('floor', htg_vac.to_s)

      # process hash
      hash = process_hash(htg_setpoint_profiles, profile_override, ruleset_name, hoo)
      if !hash then OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.LoadsSystem.create_schedule', "Failed to generate #{ruleset_name}"); return nil end

      winter_design_day = hash[:default].drop(1) # [[24,htg_occ]]
      summer_design_day = hash[:default].drop(1) # [[24,htg_occ]]
      default_day = hash[:default]
      rules = []
      rules << ['Saturday', '1/1-12/31', 'Sat'] + hash[:saturday].to_a
      rules << ['Sunday', '1/1-12/31', 'Sun'] + hash[:sunday].to_a
      options = { 'name' => ruleset_name,
                  'winter_design_day' => winter_design_day,
                  'summer_design_day' => summer_design_day,
                  'default_day' => default_day,
                  'rules' => rules }
      heating_setpoint_sch = OsLib_Schedules.createComplexSchedule(model, options)

      # generate and apply cooling_setpoint schedule using hours of operation schedule and parametric inputs
      ruleset_name = 'Parametric Cooling Setpoint Schedule'

      # clg setpoints
      clg_occ = OpenStudio.convert(clg_setpoint, 'F', 'C').get
      clg_vac = OpenStudio.convert(clg_setpoint + setback_delta, 'F', 'C').get

      # replace floor and celing with user specified values
      clg_setpoint_profiles = thermostat_setback_profiles.gsub('ceiling', clg_occ.to_s)
      clg_setpoint_profiles = clg_setpoint_profiles.gsub('floor', clg_vac.to_s)

      # process hash
      hash = process_hash(clg_setpoint_profiles, profile_override, ruleset_name, hoo)
      if !hash then OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.LoadsSystem.create_schedue', "Failed to generate #{ruleset_name}"); return nil end

      winter_design_day = hash[:default].drop(1) # [[24,clg_occ]]
      summer_design_day = hash[:default].drop(1) # [[24,clg_occ]]
      default_day = hash[:default]
      rules = []
      rules << ['Saturday', '1/1-12/31', 'Sat'] + hash[:saturday].to_a
      rules << ['Sunday', '1/1-12/31', 'Sun'] + hash[:sunday].to_a
      options = { 'name' => ruleset_name,
                  'winter_design_day' => winter_design_day,
                  'summer_design_day' => summer_design_day,
                  'default_day' => default_day,
                  'rules' => rules }
      cooling_setpoint_sch = OsLib_Schedules.createComplexSchedule(model, options)
      return heating_setpoint_sch, cooling_setpoint_sch
    end

    def self.create_schedule_SHW(model, swh_profiles, profile_override, hoo)
      # generate and apply water use equipment schedule using hours of operation schedule and parametric inputs
      ruleset_name = 'Parametric SWH Schedule'
      hash = process_hash(swh_profiles, profile_override, ruleset_name, hoo)
      if !hash then OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.LoadsSystem.create_schedue', "Failed to generate #{ruleset_name}"); return nil end
      winter_design_day = hash[:default].drop(1)
      summer_design_day = hash[:default].drop(1)
      default_day = hash[:default]
      rules = []
      rules << ['Saturday', '1/1-12/31', 'Sat'] + hash[:saturday].to_a
      rules << ['Sunday', '1/1-12/31', 'Sun'] + hash[:sunday].to_a
      options = { 'name' => ruleset_name,
                  'winter_design_day' => winter_design_day,
                  'summer_design_day' => summer_design_day,
                  'default_day' => default_day,
                  'rules' => rules }
      swh_sch = OsLib_Schedules.createComplexSchedule(model, options)
      swh_sch.setComment(swh_profiles)
      return swh_sch
    end

    # make hash of out string argument in eval. Rescue if can't be made into hash
    def self.process_hash(string, profile_override, ruleset_name, hoo)
      begin
        # temp code to make profile_hash from original commit work with updated process hash method that doesn't expose quotes or escape characters
        string = string.delete('{').delete('}')
        string = string.gsub('"weekday":"', ':default => ').gsub('"saturday":"', ':saturday => ').gsub('"sunday":"', ':sunday => ')
        string = string.gsub('\\"', '').delete('"')

        # remove any spaces
        string = string.delete(' ')

        # break up by day type
        temp_array = string.split(']],:')

        # if saturday or sunday don't exist or if over if hours per week over 60 or 72 hour threshold then copy default profile
        saturday = false
        sunday = false
        temp_array.each do |i|
          if i.include?('saturday') then saturday = true end
          if i.include?('sunday') then sunday = true end
        end
        if !(saturday && sunday)
          temp_array[0] = temp_array[0].gsub(']]', '')
        end

        if !saturday
          temp_array << temp_array[0].gsub(':default', 'saturday').gsub(']]', '')
        end
        if !sunday
          temp_array << "#{temp_array[0].gsub(':default', 'sunday').gsub(']]', '')}]]"
        end

        if profile_override.include?('saturday')
          temp_array[1] = temp_array[0].gsub(':default', 'saturday').gsub(']]', '')
        end
        if profile_override.include?('sunday')
          temp_array[2] = "#{temp_array[0].gsub(':default', 'sunday').gsub(']]', '')}]]"
        end

        # day_type specific gsub
        temp_array.each_with_index do |string, i|
          day_type = string.split('=>').first.delete(':')
          if day_type == 'default'
            hoo_start = hoo.start_wkdy
            hoo_end = hoo.end_wkdy
          elsif day_type == 'saturday'
            hoo_start = hoo.start_sat
            hoo_end = hoo.end_sat
          elsif day_type == 'sunday'
            hoo_start = hoo.start_sun
            hoo_end = hoo.end_sun
          end

          if hoo_end >= hoo_start
            occ = hoo_end - hoo_start
          else
            occ = 24.0 + hoo_end - hoo_start
          end
          vac = 24.0 - occ
          string = string.gsub('start', hoo_start.to_s)
          string = string.gsub('end', hoo_end.to_s)
          string = string.gsub('occ', occ.to_s)
          string = string.gsub('vac', vac.to_s)
          temp_array[i] = string
        end

        # re-assemble and convert to hash
        final_string = temp_array.join(']], :')

        hash = eval("{#{final_string}}").to_hash
      rescue SyntaxError => se
        puts "{#{final_string}} could not be converted to a hash."
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.LoadsSystem.process_hash',"{#{final_string}} could not be converted to a hash.")
        return false
      end
    end
  end
end
