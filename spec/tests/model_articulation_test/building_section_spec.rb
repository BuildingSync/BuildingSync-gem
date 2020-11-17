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

RSpec.describe 'BuildingSpec' do
  it 'Should generate meaningful error when passing empty XML data' do
    # -- Setup
    file_name = 'building_151_Blank.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
    begin
      generate_baseline_building_sections(xml_path, nil, nil, 'auc')
    rescue StandardError => e
      puts "expected error message:Building type '' is nil but got: #{e.message} " if !e.message.include?("Building type '' is nil")
      expect(e.message.include?("Building type '' is nil")).to be true
    end
  end

  it 'building_151_level1.xml: Should return occupancy_type for the Section' do
    # -- Setup
    file_name = 'building_151_level1.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
    building_section = get_building_section_from_file(xml_path)
    expected_value = 'Retail'

    # -- Assert
    puts "expected bldgsync_occupancy_type : #{expected_value} but got: #{building_section.bldgsync_occupancy_type} " if building_section.bldgsync_occupancy_type != expected_value
    expect(building_section.bldgsync_occupancy_type == expected_value).to be true
  end

  it 'building_151_level1.xml: Should return typical_occupant_usage_value_hours for the Section' do
    # -- Setup
    file_name = 'building_151_level1.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
    building_section = get_building_section_from_file(xml_path)
    expected_value = '40.0'

    # -- Assert
    puts "expected typical_occupant_usage_value_hours : #{expected_value} but got: #{building_section.typical_occupant_usage_value_hours} " if building_section.typical_occupant_usage_value_hours != expected_value
    expect(building_section.typical_occupant_usage_value_hours == expected_value).to be true
  end

  it 'building_151_level1.xml: Should return typical_occupant_usage_value_weeks for the Section' do
    # -- Setup
    file_name = 'building_151_level1.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
    building_section = get_building_section_from_file(xml_path)
    expected_value = '50.0'

    # -- Assert
    puts "expected typical_occupant_usage_value_weeks : #{expected_value} but got: #{building_section.typical_occupant_usage_value_weeks} " if building_section.typical_occupant_usage_value_weeks != expected_value
    expect(building_section.typical_occupant_usage_value_weeks == expected_value).to be true
  end

end
