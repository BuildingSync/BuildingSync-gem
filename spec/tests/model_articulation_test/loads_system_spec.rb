# frozen_string_literal: true

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
require 'buildingsync/generator'

RSpec.describe 'LoadSystemSpec' do
  it 'Should add internal loads successfully' do
    model = OpenStudio::Model::Model.new
    standard = Standard.build('DOE Ref Pre-1980')
    load_system = BuildingSync::LoadsSystem.new
    puts 'expected add internal loads : true but got: false} ' if load_system.add_internal_loads(model, standard, 'DOE Ref Pre-1980', nil, false) != true
    expect(load_system.add_internal_loads(model, standard, 'DOE Ref Pre-1980', nil, false)).to be true
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
    puts 'expected add day lighting controls : true but got: false} ' if load_system.add_daylighting_controls(model, standard, 'DOE Ref Pre-1980') != true
    expect(load_system.add_daylighting_controls(model, standard, 'DOE Ref Pre-1980')).to be true
  end

  xit 'should parse and write building_151.xml and adjust schedules successfully' do
    # -- Setup
    file_name = 'building_151.xml'
    std = CA_TITLE24
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
    epw_path = nil
    translator = translator_sizing_run_and_check(xml_path, output_path, epw_path, std)
    model = translator.get_model

    cut_off_value = 0.5
    # read in the schedule
    space_types = model.getSpaceTypes
    expect(space_types.length).to be 4
    space_types.each do |space_type|
      default_schedule_set = space_type.defaultScheduleSet.get
      puts "default_schedule_set: #{default_schedule_set.name} for space type: #{space_type.name}"

      help_print_all_schedules("schedules-#{space_type.name}.csv", default_schedule_set)

      expect(help_calculate_hours(default_schedule_set.numberofPeopleSchedule, cut_off_value).round(1)).to be 47.9
      expect(help_calculate_hours(default_schedule_set.hoursofOperationSchedule, cut_off_value).round(1)). to be 40.0
      expect(help_calculate_hours(default_schedule_set.peopleActivityLevelSchedule, cut_off_value).round(1)). to be 168.0
      expect(help_calculate_hours(default_schedule_set.lightingSchedule, cut_off_value).round(1)). to be 67.0
      expect(help_calculate_hours(default_schedule_set.electricEquipmentSchedule, cut_off_value).round(1)).to be 67.4
      expect(help_calculate_hours(default_schedule_set.gasEquipmentSchedule, cut_off_value).round(1)).to be 0.0
      expect(help_calculate_hours(default_schedule_set.hotWaterEquipmentSchedule, cut_off_value).round(1)).to be 0.0
      expect(help_calculate_hours(default_schedule_set.infiltrationSchedule, cut_off_value).round(1)).to be 66.0
      expect(help_calculate_hours(default_schedule_set.steamEquipmentSchedule, cut_off_value).round(1)).to be 0.0
      expect(help_calculate_hours(default_schedule_set.otherEquipmentSchedule, cut_off_value).round(1)).to be 0.0
      break
    end
  end
end
