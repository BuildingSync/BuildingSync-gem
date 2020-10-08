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
    def self.process_schedules(model, hoo_per_week, hoo_start_wkdy = 9.0, hoo_end_wkdy = 17, hoo_start_sat = 9.0, hoo_end_sat = 12.0, hoo_start_sun = 7.0, hoo_end_sun = 18.0, htg_setpoint = 67.0, clg_setpoint = 75.0, setback_delta = 4)
      # this is the new way of integrating the parametric schedule feature
      # add in logic for hours per week override
      # add to this for day types that should use weekday instead of user entered profile
      profile_override, hoo_start_wkdy, hoo_end_wkdy, hoo_start_sat, hoo_end_sat,
          hoo_start_sun, hoo_end_sun = get_profile_override(hoo_per_week, hoo_start_wkdy, hoo_end_wkdy, hoo_start_sat, hoo_end_sat, hoo_start_sun, hoo_end_sun)

      # pre-process space types to identify which ones to alter - in this case we want to alter all of them so we do not do any selections
      # create shared default schedule set
      # TODO: do we need to create a new one or should we get the existing one from the model
      default_schedule_set = OpenStudio::Model::DefaultScheduleSet.new(model)
      default_schedule_set.setName('Parametric Hours of Operation Schedule Set')

      # alter all objects
      remove_old_schedules(model, default_schedule_set)

      lighting_profiles, electric_equipment_profiles, gas_equipment_profiles, occupancy_profiles, infiltration_profiles, hvac_availability_profiles, swh_profiles, thermostat_setback_profiles = get_profiles

      create_schedule_hours_of_operations(model, default_schedule_set, hoo_start_wkdy, hoo_end_wkdy, hoo_start_sat, hoo_end_sat, hoo_start_sun, hoo_end_sun)
      create_schedule_activity(model, default_schedule_set, hoo_start_wkdy, hoo_end_wkdy, hoo_start_sat, hoo_end_sat, hoo_start_sun, hoo_end_sun)
      create_schedule_lighting(model, default_schedule_set, lighting_profiles, profile_override, hoo_start_wkdy, hoo_end_wkdy, hoo_start_sat, hoo_end_sat, hoo_start_sun, hoo_end_sun)
      create_schedule_electric_equipment(model, default_schedule_set, electric_equipment_profiles, profile_override, hoo_start_wkdy, hoo_end_wkdy, hoo_start_sat, hoo_end_sat, hoo_start_sun, hoo_end_sun)
      create_schedule_gas_equipment(model, default_schedule_set, gas_equipment_profiles, profile_override, hoo_start_wkdy, hoo_end_wkdy, hoo_start_sat, hoo_end_sat, hoo_start_sun, hoo_end_sun)
      create_schedule_occupancy(model, default_schedule_set, occupancy_profiles, profile_override, hoo_start_wkdy, hoo_end_wkdy, hoo_start_sat, hoo_end_sat, hoo_start_sun, hoo_end_sun)
      create_schedule_infiltration(model, default_schedule_set, infiltration_profiles, profile_override, hoo_start_wkdy, hoo_end_wkdy, hoo_start_sat, hoo_end_sat, hoo_start_sun, hoo_end_sun)
      create_schedule_hvac_availability(model, default_schedule_set, hvac_availability_profiles, profile_override, hoo_start_wkdy, hoo_end_wkdy, hoo_start_sat, hoo_end_sat, hoo_start_sun, hoo_end_sun)
      create_schedule_heating_cooling(model, default_schedule_set, thermostat_setback_profiles, htg_setpoint, clg_setpoint, setback_delta, profile_override,hoo_start_wkdy, hoo_end_wkdy, hoo_start_sat, hoo_end_sat, hoo_start_sun, hoo_end_sun)
      create_schedule_SHW(model, default_schedule_set, swh_profiles, profile_override, hoo_start_wkdy, hoo_end_wkdy, hoo_start_sat, hoo_end_sat, hoo_start_sun, hoo_end_sun)
    end

    def self.get_profiles(lighting_profiles = nil, electric_equipment_profiles = nil, gas_equipment_profiles = nil, occupancy_profiles = nil,
                     infiltration_profiles = nil, hvac_availability_profiles = nil, swh_profiles = nil, thermostat_setback_profiles = nil)
      # set the default profiles
      if lighting_profiles.nil?
        string = []
        string << ':default => [[start-2,0.1],[start-1,0.3],[start,0.75],[end,0.75],[end+2,0.3],[end+vac*0.5,0.1]]'
        string << ':saturday => [[start-1,0.1],[start,0.3],[end,0.3],[end+1,0.1]]'
        string << ':sunday => [[start,0.1],[end,0.1]]'
        lighting_profiles = string.join(', ')
      end
      if electric_equipment_profiles.nil?
        string = []
        string << ':default => [[start-1,0.3],[start,0.85],[start+0.5*occ-0.5,0.85],[start+0.5*occ-0.5,0.75],[start+0.5*occ+0.5,0.75],[start+0.5*occ+0.5,0.85],[end,0.85],[end+1,0.45],[end+2,0.3]]'
        string << ':saturday => [[start-2,0.2],[start,0.35],[end,0.35],[end+6,0.2]]'
        string << ':sunday => [[start,0.2],[end,0.2]]'
        electric_equipment_profiles = string.join(', ')
      end
      if gas_equipment_profiles.nil?
        string = []
        string << ':default => [[start-1,0.3],[start,0.85],[start+0.5*occ-0.5,0.85],[start+0.5*occ-0.5,0.75],[start+0.5*occ+0.5,0.75],[start+0.5*occ+0.5,0.85],[end,0.85],[end+1,0.45],[end+2,0.3]]'
        string << ':saturday => [[start-2,0.2],[start,0.35],[end,0.35],[end+6,0.2]]'
        string << ':sunday => [[start,0.2],[end,0.2]]'
        gas_equipment_profiles = string.join(', ')
      end
      if occupancy_profiles.nil?
        string = []
        string << ':default => [[start-3,0],[start-1,0.2],[start,0.95],[start+0.5*occ-0.5,0.95],[start+0.5*occ-0.5,0.5],[start+0.5*occ+0.5,0.5],[start+0.5*occ+0.5,0.95],[end,0.95],[end+1,0.3],[end+vac*0.4,0]]'
        string << ':saturday => [[start-3,0],[start,0.3],[end,0.3],[end+1,0.1],[end+vac*0.3,0]]'
        string << ':sunday => [[start,0],[start,0.05],[end,0.05],[end,0]]'
        occupancy_profiles = string.join(', ')
      end
      if infiltration_profiles.nil?
        string = []
        string << ':default => [[start,1],[start,0.25],[end+vac*0.35,0.25],[end+vac*0.35,1]]'
        string << ':saturday => [[start,1],[start,0.25],[end+vac*0.25,0.25],[end+vac*0.25,1]]'
        string << ':sunday => [[start,1],[start,0.25],[end+vac*0.25,0.25],[end+vac*0.25,1]]'
        infiltration_profiles = string.join(', ')
      end
      if hvac_availability_profiles.nil?
        string = []
        string << ':default => [[start,0],[start,1],[end+vac*0.35,1],[end+vac*0.35,0]]'
        string << ':saturday => [[start,0],[start,1],[end+vac*0.25,1],[end+vac*0.25,0]]'
        string << ':sunday => [[start,0],[start,1],[end+vac*0.25,1],[end+vac*0.25,0]]'
        hvac_availability_profiles = string.join(', ')
      end
      if swh_profiles.nil?
        string = []
        string << ':default => [[start-2,0],[start-2,0.07],[start+0.5*occ,0.57],[vac-2,0.33],[vac,0.44],[end+vac*0.35,0.05],[end+vac*0.35,0]]'
        string << ':saturday => [[start-2,0],[start-2,0.07],[start+0.5*occ,0.23],[end+vac*0.25,0.05],[end+vac*0.25,0]]'
        string << ':sunday => [[start-2,0],[start-2,0.04],[start+0.5*occ,0.09],[end+vac*0.25,0.04],[end+vac*0.25,0]]'
        swh_profiles = string.join(', ')
      end
      if thermostat_setback_profiles.nil?
        string = []
        string << ':default => [[start-2,floor],[start-2,ceiling],[end+vac*0.35,ceiling],[end+vac*0.35,floor]]'
        string << ':saturday => [[start-2,floor],[start-2,ceiling],[end+vac*0.25,ceiling],[end+vac*0.25,floor]]'
        string << ':sunday => [[start-2,floor],[start-2,ceiling],[end+vac*0.25,ceiling],[end+vac*0.25,floor]]'
        thermostat_setback_profiles = string.join(', ')
      end

      return lighting_profiles, electric_equipment_profiles, gas_equipment_profiles, occupancy_profiles, infiltration_profiles,
          hvac_availability_profiles, swh_profiles, thermostat_setback_profiles
    end

    def self.get_profile_override(hoo_per_week, hoo_start_wkdy, hoo_end_wkdy, hoo_start_sat, hoo_end_sat, hoo_start_sun, hoo_end_sun)
      profile_override = []
      if hoo_per_week > 0.0
        #runner.registerInfo('Hours per week input was a non zero value, it will override the user intered hours of operation for weekday, saturday, and sunday')
        # TODO: update logging
        if hoo_per_week > 84
          max_hoo = [hoo_per_week / 7.0, 24.0].min
        else
          max_hoo = 12.0
        end

        # for 60 horus per week or less only alter weekday. If longer then use weekday profiles for saturday for 12 hours and then sunday
        typical_weekday_input_hours = hoo_end_wkdy - hoo_start_wkdy
        target_weekday_hours = [hoo_per_week / 5.0, max_hoo].min
        delta_hours_per_day = target_weekday_hours - typical_weekday_input_hours

        # shift hours as needed
        hoo_start_wkdy -= delta_hours_per_day / 2.0
        hoo_end_wkdy += delta_hours_per_day / 2.0
        #runner.registerInfo("Adjusted hours of operation for weekday are from #{hoo_start_wkdy} to #{hoo_end_wkdy}.")

        # add logic if more than 60 hours
        if hoo_per_week > 60.0
          # for 60-72 horus per week or less only alter saturday.
          typical_weekday_input_hours = hoo_end_sat - hoo_start_sat
          target_weekday_hours = [(hoo_per_week - 60.0), max_hoo].min
          delta_hours_per_day = target_weekday_hours - typical_weekday_input_hours

          # code in process_hash method will alter saturday to use default profile formula

          # shift hours as needed
          hoo_start_sat -= delta_hours_per_day / 2.0
          hoo_end_sat += delta_hours_per_day / 2.0
          #runner.registerInfo("Adjusted hours of operation for saturday are from #{hoo_start_sat} to #{hoo_end_sat}. Saturday will use typical weekday profile formula.")
          # TODO: update logging
          # set flag to override typical profile
          profile_override << 'saturday'
        end

        # add logic if more than 72 hours
        if hoo_per_week > 72.0
          # for 60-72 horus per week or less only alter sunday.
          typical_weekday_input_hours = hoo_end_sun - hoo_start_sun
          target_weekday_hours = [(hoo_per_week - 72.0), max_hoo].min
          delta_hours_per_day = target_weekday_hours - typical_weekday_input_hours

          # code in process_hash method will alter sunday to use default profile formula

          # shift hours as needed
          hoo_start_sun -= delta_hours_per_day / 2.0
          hoo_end_sun += delta_hours_per_day / 2.0
          #runner.registerInfo("Adjusted hours of operation for sunday are from #{hoo_start_sun} to #{hoo_end_sun}. Saturday will use typical weekday profile formula.")
          # TODO: update logging
          # set flag to override typical profile
          profile_override << 'sunday'
        end
      end
      return profile_override, hoo_start_wkdy, hoo_end_wkdy, hoo_start_sat, hoo_end_sat, hoo_start_sun, hoo_end_sun
    end

    def self.remove_old_schedules(model, default_schedule_set)
      # remove schedule sets for load instances
      model.getLightss.each(&:resetSchedule)
      model.getElectricEquipments.each(&:resetSchedule)
      model.getGasEquipments.each(&:resetSchedule)
      model.getSpaceInfiltrationDesignFlowRates.each(&:resetSchedule)
      model.getPeoples.each(&:resetNumberofPeopleSchedule)
      # don't have to remove HVAC and setpoint schedules, they will be replaced individually

      # remove schedule sets.
      model.getDefaultScheduleSets.each do |sch_set|
        next if sch_set == default_schedule_set
        sch_set.remove
      end

      # assign default schedule set to building level
      model.getBuilding.setDefaultScheduleSet(default_schedule_set)

      thermostats_to_alter = model.getThermostatSetpointDualSetpoints
      air_loops_to_alter = model.getAirLoopHVACs
      water_use_equipment_to_alter = model.getWaterUseEquipments
      return thermostats_to_alter, air_loops_to_alter, water_use_equipment_to_alter
    end

    def self.create_schedule_hours_of_operations(model, default_schedule_set, hoo_start_wkdy, hoo_end_wkdy, hoo_start_sat, hoo_end_sat, hoo_start_sun, hoo_end_sun)
      # populate hours of operation schedule for schedule set (this schedule isn't used but in future could be used to dynamically generate schedules)
      ruleset_name = 'Parametric Hours of Operation Schedule'
      winter_design_day = nil
      summer_design_day = nil
      rules = []
      if hoo_end_wkdy == hoo_start_wkdy
        default_day = ['Weekday', [hoo_start_wkdy, 0], [hoo_end_wkdy, 0], [24, 0]]
      elsif hoo_end_wkdy > hoo_start_wkdy
        default_day = ['Weekday', [hoo_start_wkdy, 0], [hoo_end_wkdy, 1], [24, 0]]
      else
        default_day = ['Weekday', [hoo_end_wkdy, 1], [hoo_start_wkdy, 0], [24, 1]]
      end
      if hoo_end_sat == hoo_start_sat
        rules << ['Saturday', '1/1-12/31', 'Sat', [hoo_start_sat, 0], [hoo_end_sat, 0], [24, 0]]
      elsif hoo_end_sat > hoo_start_sat
        rules << ['Saturday', '1/1-12/31', 'Sat', [hoo_start_sat, 0], [hoo_end_sat, 1], [24, 0]]
      else
        rules << ['Saturday', '1/1-12/31', 'Sat', [hoo_end_sat, 1], [hoo_start_sat, 0], [24, 1]]
      end
      if hoo_end_sun == hoo_start_sun
        rules << ['Sunday', '1/1-12/31', 'Sun', [hoo_start_sun, 0], [hoo_end_sun, 0], [24, 0]]
      elsif hoo_end_sun > hoo_start_sun
        rules << ['Sunday', '1/1-12/31', 'Sun', [hoo_start_sun, 0], [hoo_end_sun, 1], [24, 0]]
      else
        rules << ['Sunday', '1/1-12/31', 'Sun', [hoo_end_sun, 1], [hoo_start_sun, 0], [24, 1]]
      end
      options = {'name' => ruleset_name,
                 'winter_design_day' => winter_design_day,
                 'summer_design_day' => summer_design_day,
                 'default_day' => default_day,
                 'rules' => rules}
      hoo_sch = OsLib_Schedules.createComplexSchedule(model, options)
      default_schedule_set.setHoursofOperationSchedule(hoo_sch)
    end

    def self.create_schedule_activity(model, default_schedule_set, hoo_start_wkdy, hoo_end_wkdy, hoo_start_sat, hoo_end_sat, hoo_start_sun, hoo_end_sun)
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
      activity_sch = OsLib_Schedules.createComplexSchedule(model, options)
      default_schedule_set.setPeopleActivityLevelSchedule(activity_sch)
    end

    def self.create_schedule_lighting(model, default_schedule_set, lighting_profiles, profile_override, hoo_start_wkdy, hoo_end_wkdy, hoo_start_sat, hoo_end_sat, hoo_start_sun, hoo_end_sun)
      # generate and apply lighting schedule using hours of operation schedule and parametric inputs
      ruleset_name = 'Parametric Lighting Schedule'
      hash = process_hash(lighting_profiles, profile_override, ruleset_name, hoo_start_wkdy, hoo_end_wkdy, hoo_start_sat, hoo_end_sat, hoo_start_sun, hoo_end_sun)
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
      default_schedule_set.setLightingSchedule(lighting_sch)
    end

    def self.create_schedule_electric_equipment(model, default_schedule_set, electric_equipment_profiles, profile_override, hoo_start_wkdy, hoo_end_wkdy, hoo_start_sat, hoo_end_sat, hoo_start_sun, hoo_end_sun)
      # generate and apply electric_equipment schedule using hours of operation schedule and parametric inputs
      ruleset_name = 'Parametric Electric Equipment Schedule'
      hash = process_hash(electric_equipment_profiles, profile_override, ruleset_name, hoo_start_wkdy, hoo_end_wkdy, hoo_start_sat, hoo_end_sat, hoo_start_sun, hoo_end_sun)
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
      default_schedule_set.setElectricEquipmentSchedule(electric_equipment_sch)
    end

    def self.create_schedule_gas_equipment(model, default_schedule_set, gas_equipment_profiles, profile_override, hoo_start_wkdy, hoo_end_wkdy, hoo_start_sat, hoo_end_sat, hoo_start_sun, hoo_end_sun)
      # generate and apply gas_equipment schedule using hours of operation schedule and parametric inputs
      ruleset_name = 'Parametric Gas Equipment Schedule'
      hash = process_hash(gas_equipment_profiles, profile_override, ruleset_name, hoo_start_wkdy, hoo_end_wkdy, hoo_start_sat, hoo_end_sat, hoo_start_sun, hoo_end_sun)
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
      default_schedule_set.setGasEquipmentSchedule(gas_equipment_sch)
    end

    def self.create_schedule_occupancy(model, default_schedule_set, occupancy_profiles, profile_override, hoo_start_wkdy, hoo_end_wkdy, hoo_start_sat, hoo_end_sat, hoo_start_sun, hoo_end_sun)
      # generate and apply occupancy schedule using hours of operation schedule and parametric inputs
      ruleset_name = 'Parametric Occupancy Schedule'
      hash = process_hash(occupancy_profiles, profile_override, ruleset_name, hoo_start_wkdy, hoo_end_wkdy, hoo_start_sat, hoo_end_sat, hoo_start_sun, hoo_end_sun)
      if !hash then OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.LoadsSystem.create_schedue', "Failed to generate #{ruleset_name}"); return false end
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
      default_schedule_set.setNumberofPeopleSchedule(occupancy_sch)
    end

    def self.create_schedule_infiltration(model, default_schedule_set, infiltration_profiles, profile_override, hoo_start_wkdy, hoo_end_wkdy, hoo_start_sat, hoo_end_sat, hoo_start_sun, hoo_end_sun)
      # generate and apply infiltration schedule using hours of operation schedule and parametric inputs
      ruleset_name = 'Parametric Infiltration Schedule'
      hash = process_hash(infiltration_profiles, profile_override, ruleset_name, hoo_start_wkdy, hoo_end_wkdy, hoo_start_sat, hoo_end_sat, hoo_start_sun, hoo_end_sun)
      if !hash then OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.LoadsSystem.create_schedue', "Failed to generate #{ruleset_name}"); return false end
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
      default_schedule_set.setInfiltrationSchedule(infiltration_sch)
    end

    def self.create_schedule_hvac_availability(model, default_schedule_set, hvac_availability_profiles, profile_override, hoo_start_wkdy, hoo_end_wkdy, hoo_start_sat, hoo_end_sat, hoo_start_sun, hoo_end_sun)
      # generate and apply hvac_availability schedule using hours of operation schedule and parametric inputs
      ruleset_name = 'Parametric HVAC Availability Schedule'
      hash = process_hash(hvac_availability_profiles, profile_override, ruleset_name, hoo_start_wkdy, hoo_end_wkdy, hoo_start_sat, hoo_end_sat, hoo_start_sun, hoo_end_sun)
      if !hash then OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.LoadsSystem.create_schedue', "Failed to generate #{ruleset_name}"); return false end
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

      # apply HVAC schedules
      # todo - measure currently only replaces AirLoopHVAC.setAvailabilitySchedule)
      model.getAirLoopHVACs.each do |air_loop|
        air_loop.setAvailabilitySchedule(hvac_availability_sch)
      end
    end

    def self.create_schedule_heating_cooling(model, default_schedule_set, thermostat_setback_profiles, htg_setpoint, clg_setpoint, setback_delta, profile_override, hoo_start_wkdy, hoo_end_wkdy, hoo_start_sat, hoo_end_sat, hoo_start_sun, hoo_end_sun)
      # generate and apply heating_setpoint schedule using hours of operation schedule and parametric inputs
      ruleset_name = 'Parametric Heating Setpoint Schedule'

      # htg setpoints
      htg_occ = OpenStudio.convert(htg_setpoint, 'F', 'C').get
      htg_vac = OpenStudio.convert(htg_setpoint - setback_delta, 'F', 'C').get

      # replace floor and ceiling with user specified values
      htg_setpoint_profiles = thermostat_setback_profiles.gsub('ceiling', htg_occ.to_s)
      htg_setpoint_profiles = htg_setpoint_profiles.gsub('floor', htg_vac.to_s)

      # process hash
      hash = process_hash(htg_setpoint_profiles, profile_override, ruleset_name, hoo_start_wkdy, hoo_end_wkdy, hoo_start_sat, hoo_end_sat, hoo_start_sun, hoo_end_sun)
      if !hash then OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.LoadsSystem.create_schedule', "Failed to generate #{ruleset_name}"); return false end

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
      hash = process_hash(clg_setpoint_profiles, profile_override, ruleset_name, hoo_start_wkdy, hoo_end_wkdy, hoo_start_sat, hoo_end_sat, hoo_start_sun, hoo_end_sun)
      if !hash then OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.LoadsSystem.create_schedue', "Failed to generate #{ruleset_name}"); return false end

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

      # apply heating and cooling setpoint schedules
      model.getThermostatSetpointDualSetpoints.each do |thermostat|
        thermostat.setHeatingSchedule(heating_setpoint_sch)
        thermostat.setCoolingSchedule(cooling_setpoint_sch)
      end
    end

    def self.create_schedule_SHW(model, default_schedule_set, swh_profiles, profile_override, hoo_start_wkdy, hoo_end_wkdy, hoo_start_sat, hoo_end_sat, hoo_start_sun, hoo_end_sun)
      # generate and apply water use equipment schedule using hours of operation schedule and parametric inputs
      ruleset_name = 'Parametric SWH Schedule'
      hash = process_hash(swh_profiles, profile_override, ruleset_name, hoo_start_wkdy, hoo_end_wkdy, hoo_start_sat, hoo_end_sat, hoo_start_sun, hoo_end_sun)
      if !hash then OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.LoadsSystem.create_schedue', "Failed to generate #{ruleset_name}"); return false end
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
      model.getWaterUseEquipments.each do |water_use_equipment|
        water_use_equipment.setFlowRateFractionSchedule(swh_sch)
      end
    end

    # make hash of out string argument in eval. Rescue if can't be made into hash
    def self.process_hash(string, profile_override, ruleset_name, hoo_start_wkdy, hoo_end_wkdy, hoo_start_sat, hoo_end_sat, hoo_start_sun, hoo_end_sun)
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
            hoo_start = hoo_start_wkdy
            hoo_end = hoo_end_wkdy
          elsif day_type == 'saturday'
            hoo_start = hoo_start_sat
            hoo_end = hoo_end_sat
          elsif day_type == 'sunday'
            hoo_start = hoo_start_sun
            hoo_end = hoo_end_sun
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
