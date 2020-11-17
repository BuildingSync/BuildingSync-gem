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
require 'builder'
require 'buildingsync/generator'

RSpec.describe 'FacilitySpec' do
  it 'Should generate meaningful error when passing empty XML data' do
    # -- Setup
    file_name = 'building_151_Blank.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
    begin
      BuildingSync::Generator.new.generate_baseline_facilities(xml_path, 'auc')
    rescue StandardError => e
      puts "expected error message:Year of Construction is blank in your BuildingSync file. but got: #{e.message} " if !e.message.include?('Year of Construction is blank in your BuildingSync file.')
      expect(e.message.include?('Year of Construction is blank in your BuildingSync file.')).to be true
    end
  end

  # TODO: Add actual assertions
  it 'Should create an instance of the facility class with minimal XML snippet' do
    generator = BuildingSync::Generator.new
    generator.create_minimum_facility('Retail', '1954', 'Gross', '69452')
  end

  it 'Should return the boolean value for creating osm file correctly or not.' do
    # -- Setup
    file_name = 'building_151.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
    epw_path = File.join(SPEC_WEATHER_DIR, 'CZ01RV2.epw')
    expect(File.exist?(epw_path)).to be true

    generator = BuildingSync::Generator.new
    facility = generator.create_minimum_facility('Retail', '1954', 'Gross', '69452')
    facility.determine_open_studio_standard(std)

    # -- Assert
    expect(facility.generate_baseline_osm(epw_path, output_path, std)).to be true
  end

  # TODO: Add actual assertions
  it 'Should create a building system with parameters set to true' do
    # -- Setup
    file_name = 'building_151.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
    doc = nil
    File.open(xml_path, 'r') do |file|
      doc = REXML::Document.new(file)
    end
    ns = 'auc'

    # -- Act
    facility = BuildingSync::Facility.new(doc.elements["/#{ns}:BuildingSync/#{ns}:Facilities/#{ns}:Facility"], ns)
    facility.determine_open_studio_standard(ASHRAE90_1)
    facility.get_sites[0].generate_baseline_osm(nil, ASHRAE90_1)
    facility.create_building_systems(output_path, nil, 'Forced Air', 'Electricity', 'Electricity',
                                     true, true, true, true,
                                     true, true, true, true, true)
  end

  # TODO: Add actual assertions
  it 'Should create a building system with parameters set to false' do
    # -- Setup
    file_name = 'building_151.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
    doc = nil
    File.open(xml_path, 'r') do |file|
      doc = REXML::Document.new(file)
    end

    # -- Act
    ns = 'auc'
    facility = BuildingSync::Facility.new(doc.elements["/#{ns}:BuildingSync/#{ns}:Facilities/#{ns}:Facility"], ns)
    facility.determine_open_studio_standard(ASHRAE90_1)
    facility.get_sites[0].generate_baseline_osm(nil, ASHRAE90_1)
    facility.create_building_systems(output_path, 'Forced Air', 'Electricity', 'Electricity',
                                     false, false, false, false,
                                     false, false, false, false, false)
  end

  it 'Should return benchmark_eui' do
    # -- Setup
    file_name = 'building_151_level1.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')

    facility = BuildingSync::Generator.new.get_facility_from_file(xml_path)
    expected_value = '9.7'

    # -- Assert
    puts "expected benchmark_eui: #{expected_value} but got: #{facility.building_eui_benchmark} " if facility.building_eui_benchmark != expected_value
    expect(facility.building_eui_benchmark == expected_value).to be true
  end

  it 'Should return eui_building' do
    # -- Setup
    file_name = 'building_151_level1.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')

    facility = BuildingSync::Generator.new.get_facility_from_file(xml_path)
    expected_value = '10.5'
    puts "expected eui_building: #{expected_value} but got: #{facility.building_eui} " if facility.building_eui != expected_value
    expect(facility.building_eui == expected_value).to be true
  end

  it 'Should return auditor_contact_id' do
    # -- Setup
    file_name = 'building_151_level1.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')

    facility = BuildingSync::Generator.new.get_facility_from_file(xml_path)
    expected_value = 'Contact1'
    puts "expected auditor_contact_id: #{expected_value} but got: #{facility.auditor_contact_id} " if facility.auditor_contact_id != expected_value
    expect(facility.auditor_contact_id == expected_value).to be true
  end

  it 'Should return benchmark_tool' do
    # -- Setup
    file_name = 'building_151_level1.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')

    facility = BuildingSync::Generator.new.get_facility_from_file(xml_path)
    expected_value = 'Portfolio Manager'

    # -- Assert
    puts "expected benchmark_tool: #{expected_value} but got: #{facility.benchmark_tool} " if facility.benchmark_tool != expected_value
    expect(facility.benchmark_tool == expected_value).to be true
  end

  it 'Should return annual_fuel_use_native_units' do
    # -- Setup
    file_name = 'building_151_level1.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')

    facility = BuildingSync::Generator.new.get_facility_from_file(xml_path)
    expected_value = '123'

    # -- Assert
    puts "expected annual_fuel_use_native_units: #{expected_value} but got: #{facility.annual_fuel_use_native_units} " if facility.annual_fuel_use_native_units != expected_value
    expect(facility.annual_fuel_use_native_units == expected_value).to be true
  end

  it 'Should return energy_cost' do
    # -- Setup
    file_name = 'building_151_level1.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')

    facility = BuildingSync::Generator.new.get_facility_from_file(xml_path)
    expected_value = '1000'

    # -- Assert
    puts "expected energy_cost: #{expected_value} but got: #{facility.energy_cost} " if facility.energy_cost != expected_value
    expect(facility.energy_cost == expected_value).to be true
  end

  it 'Should return audit_date' do
    # -- Setup
    file_name = 'building_151_level1.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')

    facility = BuildingSync::Generator.new.get_facility_from_file(xml_path)
    expected_value = Date.parse('2019-05-01')

    # -- Assert
    puts "expected audit_date: #{expected_value} but got: #{facility.audit_date} " if facility.audit_date != expected_value
    expect(facility.audit_date == expected_value).to be true
  end

  it 'Should return error about number of stories below grade' do
    # -- Setup
    file_name = 'report_479.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__)

    begin
      BuildingSync::Generator.new.get_facility_from_file(xml_path)
    rescue StandardError => e
      # -- Assert
      puts "rescued StandardError: #{e.message}"
      expect(e.message.include?('Number of stories below grade is larger than')).to be true
    end
  end

  it 'Should return contact_name' do
    # -- Setup
    file_name = 'report_479.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__)

    facility = BuildingSync::Generator.new.get_facility_from_file(xml_path)
    expected_value = 'John Doe'

    # -- Assert
    puts "expected contact_name: #{expected_value} but got: #{facility.contact_auditor_name} " if facility.contact_auditor_name != expected_value
    expect(facility.contact_auditor_name == expected_value).to be true
  end

  it 'Should return utility_name' do
    # -- Setup
    file_name = 'building_151_level1.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')

    facility = BuildingSync::Generator.new.get_facility_from_file(xml_path)
    expected_value = 'an utility'

    # -- Assert
    puts "expected utility_name: #{expected_value} but got: #{facility.utility_name} " if facility.utility_name != expected_value
    expect(facility.utility_name == expected_value).to be true
  end

  it 'Should return metering_configuration ' do
    # -- Setup
    file_name = 'building_151_level1.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')

    facility = BuildingSync::Generator.new.get_facility_from_file(xml_path)
    expected_value = 'Direct metering'

    # -- Assert
    puts "expected metering_configuration: #{expected_value} but got: #{facility.metering_configuration} " if facility.metering_configuration != expected_value
    expect(facility.metering_configuration == expected_value).to be true
  end

  it 'Should return rate_schedules ' do
    # -- Setup
    file_name = 'building_151_level1.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')

    facility = BuildingSync::Generator.new.get_facility_from_file(xml_path)
    expected_value = REXML::Element.new("auc:CriticalPeakPricing")
    rate_schedule = facility.rate_schedules_xml[0]
    rate_structure_type = rate_schedule.get_elements("auc:TypeOfRateStructure/*")[0]

    # -- Assert
    puts "expected rate_schedules: #{expected_value.to_s} but got: #{rate_structure_type.to_s} " if rate_structure_type != expected_value
    expect(rate_structure_type.to_s == expected_value.to_s).to be true
  end

  it 'Should return utility_meter_numbers' do
    # -- Setup
    file_name = 'building_151_level1.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')

    facility = BuildingSync::Generator.new.get_facility_from_file(xml_path)
    expected_value = '0123456'
    meter_number = facility.utility_meter_numbers[0]

    # -- Assert
    puts "expected utility_meter_number: #{expected_value} but got: #{meter_number} " if meter_number != expected_value
    expect(meter_number == expected_value).to be true
  end

end
