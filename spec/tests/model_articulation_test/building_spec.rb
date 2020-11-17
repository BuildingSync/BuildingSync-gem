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
require 'buildingsync/model_articulation/building'

RSpec.describe 'BuildingSpec' do
  it 'Should generate meaningful error when passing empty XML data' do
    # -- Setup
    file_name = 'building_151_Blank.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
    begin
      generate_baseline_buildings(xml_path, '', '', 'auc')
    rescue StandardError => e
      expect(e.message.include?('Year of Construction is blank in your BuildingSync file.')).to be true
    end
  end

  it 'Should create an instance of the site class with minimal XML snippet' do
    g = BuildingSync::Generator.new
    g.create_minimum_building('Retail', '1954', 'Gross', '69452')
  end

  it 'Should return the no of building stories' do
    g = BuildingSync::Generator.new
    building = g.create_minimum_building('Retail', '1954', 'Gross', '69452')
    puts "expected no. of stories: 1 but got: #{building.num_stories} " if building.num_stories != 1
    expect(building.num_stories == 1).to be true
  end

  it 'Should return the correct building type' do
    g = BuildingSync::Generator.new
    building = g.create_minimum_building('Retail', '1954', 'Gross', '69452')
    puts "expected building type: RetailStandalone but got: #{building.get_building_type} " if building.get_building_type != 'RetailStandalone'
    expect(building.get_building_type == 'RetailStandalone').to be true
  end

  it 'Should return the correct system type' do
    g = BuildingSync::Generator.new
    building = g.create_minimum_building('Retail', '1954', 'Gross', '69452')
    puts "expected system type: PSZ-AC with gas coil heat but got: #{building.get_system_type} " if building.get_system_type != 'PSZ-AC with gas coil heat'
    expect(building.get_system_type == 'PSZ-AC with gas coil heat').to be true
  end

  it 'Should return the correct building template' do
    g = BuildingSync::Generator.new
    building = g.create_minimum_building('Retail', '1954', 'Gross', '69452')
    building.determine_open_studio_standard(CA_TITLE24)
    puts "expected building template: CBES Pre-1978 but got: #{building.get_building_template} " if building.get_building_template != 'CBES Pre-1978'
    expect(building.get_building_template == 'CBES Pre-1978').to be true
  end

  it 'Should successfully set an ASHRAE 90.1 climate zone' do
    g = BuildingSync::Generator.new
    building = g.create_minimum_building('Retail', '1954', 'Gross', '69452')
    building.get_model
    puts "expected climate zone: true but got: #{building.set_climate_zone('ASHRAE 3C', ASHRAE90_1, '')} " if building.set_climate_zone('ASHRAE 3C', ASHRAE90_1, '') != true
    expect(building.set_climate_zone('ASHRAE 3C', ASHRAE90_1, '')).to be true
  end

  it 'Should successfully set a CA T24 climate zone' do
    g = BuildingSync::Generator.new
    building = g.create_minimum_building('Office', '2015', 'Gross', '20000')
    building.get_model
    puts "expected climate zone: true but got: #{building.set_climate_zone('Climate Zone 6', CA_TITLE24, '')} " if building.set_climate_zone('Climate Zone 6', CA_TITLE24, '') != true
    expect(building.set_climate_zone('Climate Zone 6', CA_TITLE24, '')).to be true
  end

  it 'Should return the year of last energy audit' do
    # -- Setup
    file_name = 'building_151_level1.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
    building = get_building_from_file(xml_path)
    expected_value = 2010

    # -- Assert
    puts "expected year_of_last_energy_audit: #{expected_value} but got: #{building.year_of_last_energy_audit} " if building.year_of_last_energy_audit != expected_value
    expect(building.year_of_last_energy_audit == expected_value).to be true
  end

  it 'Should return ownership' do
    # -- Setup
    file_name = 'building_151_level1.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
    building = get_building_from_file(xml_path)
    expected_value = 'Property management company'

    # -- Assert
    puts "expected ownership: #{expected_value} but got: #{building.ownership} " if building.ownership != expected_value
    expect(building.ownership == expected_value).to be true
  end

  it 'Should return occupancy_classification' do
    # -- Setup
    file_name = 'building_151_level1.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
    building = get_building_from_file(xml_path)
    expected_value = 'Health care-Inpatient hospital'

    # -- Assert
    puts "expected occupancy_classification: #{expected_value} but got: #{building.occupancy_classification} " if building.occupancy_classification != expected_value
    expect(building.occupancy_classification == expected_value).to be true
  end

  it 'Should return the IDref attribute for PrimaryContactID' do
    # -- Setup
    file_name = 'building_151_level1.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
    building = get_building_from_file(xml_path)
    expected_value = 'Contact1'

    # -- Assert
    puts "expected primary_contact_id: #{expected_value} but got: #{building.primary_contact_id} " if building.primary_contact_id != expected_value
    expect(building.primary_contact_id == expected_value).to be true
  end

  it 'Should return RetrocommissioningDate' do
    # -- Setup
    file_name = 'building_151_level1.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
    building = get_building_from_file(xml_path)
    expected_value = Date.parse '1/1/2019'

    # -- Assert
    puts "expected retro_commissioning_date: #{expected_value} but got: #{building.year_last_commissioning} " if building.year_last_commissioning != expected_value
    expect(building.year_last_commissioning == expected_value).to be true
  end

  it 'Should return BuildingAutomationSystem' do
    # -- Setup
    file_name = 'building_151_level1.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
    building = get_building_from_file(xml_path)
    expected_value = true

    # -- Assert
    puts "expected building_automation_system: #{expected_value} but got: #{building.building_automation_system} " if building.building_automation_system != expected_value
    expect(building.building_automation_system == expected_value).to be true
  end

  it 'Should return HistoricalLandmark' do
    # -- Setup
    file_name = 'building_151_level1.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
    building = get_building_from_file(xml_path)
    expected_value = true

    # -- Assert
    puts "expected historical_landmark: #{expected_value} but got: #{building.historical_landmark} " if building.historical_landmark != expected_value
    expect(building.historical_landmark == expected_value).to be true
  end

  it 'Should return PercentOccupiedByOwner' do
    # -- Setup
    file_name = 'building_151_level1.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
    building = get_building_from_file(xml_path)
    expected_value = '60'

    # -- Assert
    puts "expected percent_occupied_by_owner: #{expected_value} but got: #{building.percent_occupied_by_owner} " if building.percent_occupied_by_owner != expected_value
    expect(building.percent_occupied_by_owner == expected_value).to be true
  end

  it 'Should return OccupantQuantity' do
    # -- Setup
    file_name = 'building_151_level1.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
    building = get_building_from_file(xml_path)
    expected_value = '15000'

    # -- Assert
    puts "expected occupant_quantity: #{expected_value} but got: #{building.occupant_quantity} " if building.occupant_quantity != expected_value
    expect(building.occupant_quantity == expected_value).to be true
  end

  it 'Should return NumberOfUnits' do
    # -- Setup
    file_name = 'building_151_level1.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
    building = get_building_from_file(xml_path)
    expected_value = '18'

    # -- Assert
    puts "expected number_of_units: #{expected_value} but got: #{building.number_of_units} " if building.number_of_units != expected_value
    expect(building.number_of_units == expected_value).to be true
  end

  it 'Should return built_year' do
    # -- Setup
    file_name = 'building_151_level1.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
    building = get_building_from_file(xml_path)
    expected_value = Integer('2003')

    # -- Assert
    puts "expected built_year: #{expected_value} but got: #{building.built_year} " if building.built_year != expected_value
    expect(building.built_year == expected_value).to be true
  end

  it 'Should return major_remodel_year' do
    # -- Setup
    file_name = 'building_151_level1.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
    building = get_building_from_file(xml_path)
    expected_value = Integer('2003')

    # -- Assert
    puts "expected major_remodel_year: #{expected_value} but got: #{building.year_major_remodel} " if building.year_major_remodel != expected_value
    expect(building.year_major_remodel == expected_value).to be true
  end

  it 'Should return year_of_last_energy_audit' do
    # -- Setup
    file_name = 'building_151_level1.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
    building = get_building_from_file(xml_path)
    expected_value = Integer('2010')

    # -- Assert
    puts "expected year_of_last_energy_audit: #{expected_value} but got: #{building.year_of_last_energy_audit} " if building.year_of_last_energy_audit != expected_value
    expect(building.year_of_last_energy_audit == expected_value).to be true
  end
end
