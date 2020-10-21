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

RSpec.describe 'LoadSystemSpec' do
  it 'Should add internal loads successfully' do
    model = OpenStudio::Model::Model.new
    standard = Standard.build('DOE Ref Pre-1980')
    load_system = BuildingSync::LoadsSystem.new
    puts 'expected add internal loads : true but got: false} ' if load_system.add_internal_loads(model, standard, 'DOE Ref Pre-1980', nil, false) != true
    expect(load_system.add_internal_loads(model, standard, 'DOE Ref Pre-1980', nil, false)).to be true
  end

  it 'Should add exterior lights successfully' do
    site = create_minimum_site('Retail', '1980', 'Gross', '20000')
    site.determine_open_studio_standard(ASHRAE90_1)
    site.generate_baseline_osm(File.expand_path('../../weather/CZ01RV2.epw', File.dirname(__FILE__)), ASHRAE90_1)
    # we need to create a site and call the generate_baseline_osm method in order to set the space types in the model, why are those really needed?
    load_system = BuildingSync::LoadsSystem.new
    puts 'expected add internal loads : true but got: false} ' if load_system.add_exterior_lights(site.get_model, site.determine_open_studio_system_standard, 1.0, '3 - All Other Areas', false) != true
    expect(load_system.add_exterior_lights(site.get_model, site.determine_open_studio_system_standard, 1.0, '3 - All Other Areas', false)).to be true
  end

  it 'Should add elevator successfully' do
    model = OpenStudio::Model::Model.new
    standard = Standard.build('DOE Ref Pre-1980')
    load_system = BuildingSync::LoadsSystem.new
    puts 'expected add elevator : true but got: false} ' if load_system.add_elevator(model, standard) != true
    expect(load_system.add_elevator(model, standard)).to be true
  end

  it 'Should add daylighting controls successfully' do
    model = OpenStudio::Model::Model.new
    standard = Standard.build('DOE Ref Pre-1980')
    load_system = BuildingSync::LoadsSystem.new
    puts 'expected add day lighting controls : true but got: false} ' if load_system.add_day_lighting_controls(model, standard, 'DOE Ref Pre-1980') != true
    expect(load_system.add_day_lighting_controls(model, standard, 'DOE Ref Pre-1980')).to be true
  end

  it 'Should add internal loads and adjust schedules successfully' do
    model = OpenStudio::Model::Model.new
    standard = Standard.build('DOE Ref Pre-1980')
    load_system = BuildingSync::LoadsSystem.new
    puts 'expected add internal loads : true but got: false} ' if load_system.add_internal_loads(model, standard, 'DOE Ref Pre-1980', nil, false) != true
    expect(load_system.add_internal_loads(model, standard, 'DOE Ref Pre-1980', nil, false)).to be true

    new_building_section = BuildingSync::BuildingSection.new(create_minimum_section_xml('auc'), 'Office', '20000', 'auc')
    expect(load_system.adjust_people_schedule(nil, new_building_section, model)).to be true

    # building.defaultScheduleSet.get
  end

  it 'should parse and write building_151.xml and adjust schedules successfully' do
    translator = test_baseline_creation('building_151.xml', CA_TITLE24)
    model = translator.get_model

    # read in the schedule
    space_types = model.getSpaceTypes
    expect(space_types.length).to be 4
    space_types.each do |space_type|
      calculated_hours_per_week = 0
      default_schedule_set = space_type.defaultScheduleSet.get
      puts "default_schedule_set: #{default_schedule_set.name} for space type: #{space_type.name}"
      occupancy_Schedule = default_schedule_set.numberofPeopleSchedule.get
      puts "occupancy_Schedule: #{occupancy_Schedule}"
      occupancy_Schedule_rule_set = occupancy_Schedule.to_ScheduleRuleset.get
      puts "occupancy_Schedule_rule_set: #{occupancy_Schedule_rule_set}"
      defaultProfile = occupancy_Schedule_rule_set.defaultDaySchedule

      default_profile_duration = get_duration(defaultProfile, 0.5)
      puts "default_profile_duration: #{default_profile_duration}"

      default_number_of_days = 7
      occupancy_Schedule_rule_set.scheduleRules.each do |rule|
        profile_duration = get_duration(rule.daySchedule, 0.5)
        puts "profile_duration: #{profile_duration}"

        number_of_days = count_number_of_days(rule)
        default_number_of_days -= number_of_days
        calculated_hours_per_week += profile_duration * number_of_days
      end
      calculated_hours_per_week += default_profile_duration * default_number_of_days
      expect(calculated_hours_per_week).to be 48
    end
  end

  def count_number_of_days(rule)
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

  def get_duration(profile, cut_off_value)
    min_time = nil
    max_time = nil
    min_time_value = nil
    max_time_value = nil
    last_time = nil

    profile.times.each do |time|

      puts "time: #{time} value: #{profile.getValue(time)}"
      if min_time.nil?
        if profile.getValue(time) >= cut_off_value
          min_time = time
          min_time_value = profile.getValue(time)
        end
      elsif max_time.nil?
        if profile.getValue(time) < cut_off_value then max_time = last_time end
      end
      last_time = time
    end

    return 0 if min_time.nil?
    puts "min_time: #{min_time}"
    puts "max_time: #{max_time}"
    puts "min_time_value: #{min_time_value}"
    puts "max_time_value: #{profile.getValue(max_time)}"
    duration = max_time.hours - min_time.hours
    puts "duration: #{duration}"
    return duration
  end

  def create_minimum_section_xml(ns, typical_usage_hours = 40)
    section = REXML::Element.new("#{ns}:Section")
    ## adding the XML elements for the typical hourly usage per week
    typical_usages = REXML::Element.new("#{ns}:TypicalOccupantUsages")
    section.add_element(typical_usages)
    typical_usage = REXML::Element.new("#{ns}:TypicalOccupantUsage")
    typical_usages.add_element(typical_usage)
    typical_usage_unit = REXML::Element.new("#{ns}:TypicalOccupantUsageUnits")
    typical_usage_unit.text = 'Hours per week'
    typical_usage.add_element(typical_usage_unit)
    typical_usage_value = REXML::Element.new("#{ns}:TypicalOccupantUsageValue")
    typical_usage_value.text = typical_usage_hours
    typical_usage.add_element(typical_usage_value)
    return section
  end
end
