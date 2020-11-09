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
  # helper class for helper methods in BuildingSync
  class Helper
    # get text value from xml element
    # @param xml_element [REXML::Element]
    # @return string
    def self.get_text_value(xml_element)
      if xml_element
        return xml_element.text
      end
      return nil
    end

    # get date value from xml element
    # @param xml_element [REXML::Element]
    # @return string
    def self.get_date_value(xml_element)
      if xml_element
        return Date.parse(xml_element.text)
      end
      return nil
    end

    # get zone name list
    # @param zones [array<OpenStudio::Model::ThermalZone>]
    # @return array
    def self.get_zone_name_list(zones)
      names = []
      zones.each do |zone|
        names << zone.name.get
      end
      return names
    end

    # read xml file document
    # @param xml_file_path [String]
    # @return REXML::Document
    def self.read_xml_file_document(xml_file_path)
      doc = nil
      File.open(xml_file_path, 'r') do |file_content|
        doc = REXML::Document.new(file_content, ignore_whitespace_nodes: :all)
      end
      return doc
    end

    # print all schedules to a file
    # @param file_name [String]
    # @param default_schedule_set [OpenStudio::Model::DefaultScheduleSet]
    def self.print_all_schedules(file_name, default_schedule_set)
      f = File.open(file_name, 'w')
      print_schedule(f, default_schedule_set.numberofPeopleSchedule)
      print_schedule(f, default_schedule_set.hoursofOperationSchedule)
      print_schedule(f, default_schedule_set.peopleActivityLevelSchedule)
      print_schedule(f, default_schedule_set.lightingSchedule)
      print_schedule(f, default_schedule_set.electricEquipmentSchedule)
      print_schedule(f, default_schedule_set.gasEquipmentSchedule)
      print_schedule(f, default_schedule_set.hotWaterEquipmentSchedule)
      print_schedule(f, default_schedule_set.infiltrationSchedule)
      print_schedule(f, default_schedule_set.steamEquipmentSchedule)
      print_schedule(f, default_schedule_set.otherEquipmentSchedule)
      f.close
    end

    # write a schedule profile
    # @param f [File]
    # @param profile [OpenStudio::Model::ScheduleDay]
    # @param rule [OpenStudio::Model::ScheduleRule]
    # @param cut_off_value [Float]
    def self.write_profile(f, profile, rule, cut_off_value = 0.5)
      time_row = "#{profile.name},"
      if rule.nil?
        time_row += ',,,,,,,'
      else
        if rule.applySunday
          time_row += 'X,'
        else
          time_row += ','
        end
        if rule.applyMonday
          time_row += 'X,'
        else
          time_row += ','
        end
        if rule.applyTuesday
          time_row += 'X,'
        else
          time_row += ','
        end
        if rule.applyWednesday
          time_row += 'X,'
        else
          time_row += ','
        end
        if rule.applyThursday
          time_row += 'X,'
        else
          time_row += ','
        end
        if rule.applyFriday
          time_row += 'X,'
        else
          time_row += ','
        end
        if rule.applySaturday
          time_row += 'X,'
        else
          time_row += ','
        end
      end
      time_row += ','
      value_row = ",,,,,,,,#{get_duration(profile, cut_off_value)},"

      profile.times.each do |time|
        time_row += "#{time},"
        value_row += "#{profile.getValue(time)},"
      end
      f.write time_row + "\n"
      f.write value_row + "\n"
    end

    # print schedule
    # @param f [File]
    # @param optional_schedule [OpenStudio::Model::OptionalSchedule]
    # @param cut_off_value [Float]
    def self.print_schedule(f, optional_schedule, cut_off_value = 0.5)
      if optional_schedule.is_a?(OpenStudio::Model::OptionalSchedule) && optional_schedule.is_initialized
        schedule = optional_schedule.get
        if schedule.is_a?(OpenStudio::Model::OptionalSchedule) && schedule.is_initialized
          schedule = schedule.get
        end
      else
        schedule = optional_schedule
      end
      if schedule.is_a?(OpenStudio::Model::Schedule)
        schedule_rule_set = schedule.to_ScheduleRuleset.get
        f.puts "schedule_rule_set name: ,#{schedule_rule_set.name}, duration:, #{calculate_hours(optional_schedule, cut_off_value)}"
        defaultProfile = schedule_rule_set.defaultDaySchedule

        f.puts 'Name, Su, Mo, Tu, We, Th, Fr, Sa, Duration, TimeValue1, TV2, ...'
        write_profile(f, defaultProfile, nil, cut_off_value)

        schedule_rule_set.scheduleRules.each do |rule|
          write_profile(f, rule.daySchedule, rule, cut_off_value)
        end
        f.puts
      else
        puts "schedule: #{schedule}"
      end
    end

    # get start time weekday
    # @param schedule_rule_set [OpenStudio::Model::ScheduleRuleSet]
    # @param cut_off_value [Float]
    def self.get_start_time_weekday(schedule_rule_set, cut_off_value = 0.5)
      profile = schedule_rule_set.defaultDaySchedule
      schedule_rule_set.scheduleRules.each do |rule|
        if rule.applyMonday
          profile = rule.daySchedule
        end
      end

      return get_start_time(profile, cut_off_value)
    end

    # get end time weekday
    # @param schedule_rule_set [OpenStudio::Model::ScheduleRuleSet]
    # @param cut_off_value [Float]
    def self.get_end_time_weekday(schedule_rule_set, cut_off_value = 0.5)
      profile = schedule_rule_set.defaultDaySchedule
      schedule_rule_set.scheduleRules.each do |rule|
        if rule.applyMonday
          profile = rule.daySchedule
        end
      end

      return get_end_time(profile, cut_off_value)
    end

    # get start time Saturday
    # @param schedule_rule_set [OpenStudio::Model::ScheduleRuleSet]
    # @param cut_off_value [Float]
    def self.get_start_time_sat(schedule_rule_set, cut_off_value = 0.5)
      profile = schedule_rule_set.defaultDaySchedule
      schedule_rule_set.scheduleRules.each do |rule|
        if rule.applySaturday
          profile = rule.daySchedule
        end
      end

      return get_start_time(profile, cut_off_value)
    end

    # get end time Saturday
    # @param schedule_rule_set [OpenStudio::Model::ScheduleRuleSet]
    # @param cut_off_value [Float]
    def self.get_end_time_sat(schedule_rule_set, cut_off_value = 0.5)
      profile = schedule_rule_set.defaultDaySchedule
      schedule_rule_set.scheduleRules.each do |rule|
        if rule.applySaturday
          profile = rule.daySchedule
        end
      end

      return get_end_time(profile, cut_off_value)
    end

    # get start time Sunday
    # @param schedule_rule_set [OpenStudio::Model::ScheduleRuleSet]
    # @param cut_off_value [Float]
    def self.get_start_time_sun(schedule_rule_set, cut_off_value = 0.5)
      profile = schedule_rule_set.defaultDaySchedule
      schedule_rule_set.scheduleRules.each do |rule|
        if rule.applySunday
          profile = rule.daySchedule
        end
      end

      return get_start_time(profile, cut_off_value)
    end

    # get end time Sunday
    # @param schedule_rule_set [OpenStudio::Model::ScheduleRuleSet]
    # @param cut_off_value [Float]
    def self.get_end_time_sun(schedule_rule_set, cut_off_value = 0.5)
      profile = schedule_rule_set.defaultDaySchedule
      schedule_rule_set.scheduleRules.each do |rule|
        if rule.applySunday
          profile = rule.daySchedule
        end
      end

      return get_end_time(profile, cut_off_value)
    end

    # get start time
    # @param profile [OpenStudio::Model::ScheduleDay]
    # @param cut_off_value [Float]
    def self.get_start_time(profile, cut_off_value)
      last_time = OpenStudio::Time.new
      profile.times.each do |time|
        if profile.getValue(time) >= cut_off_value
          return last_time
        end
        last_time = time
      end
      return OpenStudio::Time.new
    end

    # get end time
    # @param profile [OpenStudio::Model::ScheduleDay]
    # @param cut_off_value [Float]
    def self.get_end_time(profile, cut_off_value)
      last_time = nil
      profile.times.each do |time|
        if profile.getValue(time) >= cut_off_value
          last_time = time
        elsif profile.getValue(time) < cut_off_value && !last_time.nil?
          return last_time
        end
      end
      return OpenStudio::Time.new
    end

    # get schedule rule set from schedule
    # @param optional_schedule [OpenStudio::Model::OptionalSchedule]
    # @return [OpenStudio::Model::ScheduleRuleSet]
    def self.get_schedule_rule_set_from_schedule(optional_schedule)
      if optional_schedule.is_a?(OpenStudio::Model::OptionalSchedule)
        if optional_schedule.is_initialized
          schedule = optional_schedule.get
        else
          return nil
        end
      else
        schedule = optional_schedule
      end
      return schedule.to_ScheduleRuleset.get
    end

    # calculate schedule hours that are at or above the cut off value
    # @param optional_schedule [OpenStudio::Model::OptionalSchedule]
    # @return [OpenStudio::Model::ScheduleRuleSet]
    # @ return [Float]
    def self.calculate_hours(optional_schedule, cut_off_value = 0.5)
      calculated_hours_per_week = 0.0
      schedule_rule_set = get_schedule_rule_set_from_schedule(optional_schedule)
      return 0.0 if schedule_rule_set.nil?
      defaultProfile = schedule_rule_set.defaultDaySchedule
      default_profile_duration = get_duration(defaultProfile, cut_off_value)
      default_number_of_days = 7
      schedule_rule_set.scheduleRules.each do |rule|
        profile_duration = get_duration(rule.daySchedule, cut_off_value)
        number_of_days = count_number_of_days(rule)
        default_number_of_days -= number_of_days
        calculated_hours_per_week += profile_duration * number_of_days
      end
      calculated_hours_per_week += default_profile_duration * default_number_of_days
      return calculated_hours_per_week
    end

    # count number of days
    # @param rule [OpenStudio::Model::ScheduleRule]
    # return [Integer]
    def self.count_number_of_days(rule)
      count = 0
      count += 1 if rule.applyFriday
      count += 1 if rule.applyMonday
      count += 1 if rule.applySaturday
      count += 1 if rule.applySunday
      count += 1 if rule.applyThursday
      count += 1 if rule.applyTuesday
      count += 1 if rule.applyWednesday
      return count
    end

    # get duration
    # @param profile [OpenStudio::Model::ScheduleDay]
    # @param cut_off_value [Float]
    # return [Float]
    def self.get_duration(profile, cut_off_value)
      last_time = nil
      duration_above_cut_off = 0.0
      profile.times.each do |time|
        if profile.getValue(time) >= cut_off_value
          if last_time.nil?
            duration_above_cut_off += time.totalHours
          else
            duration_above_cut_off += time.totalHours - last_time.totalHours
          end
        end
        last_time = time
      end

      return duration_above_cut_off
    end

    # get default schedule set
    # @param model [OpenStudio::Model]
    # return [OpenStudio::Model::DefaultScheduleSet]
    def self.get_default_schedule_set(model)
      if model.getBuilding.defaultScheduleSet.is_initialized
        return model.getBuilding.defaultScheduleSet.get
      else
        space_types = model.getSpaceTypes
        space_types.each do |space_type|
          return space_type.defaultScheduleSet.get
        end
      end
    end
  end
end
