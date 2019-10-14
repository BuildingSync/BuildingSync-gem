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
require 'builder'

RSpec.describe 'FacilitySpec' do
  it 'Should generate meaningful error when passing empty XML data' do
    begin
      generate_baseline('building_151_Blank', 'auc')
    rescue StandardError => e
      puts "expected error message:Year of Construction is blank in your BuildingSync file. but got: #{e.message} " if !e.message.include?('Year of Construction is blank in your BuildingSync file.')
      expect(e.message.include?('Year of Construction is blank in your BuildingSync file.')).to be true
    end
  end

  it 'Should create an instance of the facility class with minimal XML snippet' do
    create_minimum_facility('Retail', '1954', 'Gross', '69452')
  end

  it 'Should return the boolean value for creating osm file correctly or not.' do
    facility = create_minimum_facility('Retail', '1954', 'Gross', '69452')
    facility.determine_open_studio_standard(ASHRAE90_1)
    epw_file_path = File.expand_path('../../weather/CZ01RV2.epw', File.dirname(__FILE__))
    output_path = File.expand_path("../../output/#{File.basename(__FILE__, File.extname(__FILE__))}/", File.dirname(__FILE__))
    expect(facility.generate_baseline_osm(epw_file_path, output_path, ASHRAE90_1)).to be true
  end

  it 'Should create a building system with parameters set to true' do
    xml_file_path = File.expand_path('./../../files/building_151.xml', File.dirname(__FILE__))
    doc = nil
    File.open(xml_file_path, 'r') do |file|
      doc = REXML::Document.new(file)
    end
    ns = 'auc'
    facility = BuildingSync::Facility.new(doc.elements["/#{ns}:BuildingSync/#{ns}:Facilities/#{ns}:Facility"], ns)
    facility.determine_open_studio_standard(ASHRAE90_1)
    output_path = File.expand_path("../../output/#{File.basename(__FILE__, File.extname(__FILE__))}/", File.dirname(__FILE__))
    facility.get_sites[0].generate_baseline_osm(nil, ASHRAE90_1)
    facility.create_building_systems(output_path, 'Forced Air', 'Electricity', 'Electricity',
                                     true, true, true, true,
                                     true, true, true, true, true)
  end

  it 'Should create a building system with parameters set to false' do
    xml_file_path = File.expand_path('./../../files/building_151.xml', File.dirname(__FILE__))
    doc = nil
    File.open(xml_file_path, 'r') do |file|
      doc = REXML::Document.new(file)
    end
    ns = 'auc'
    facility = BuildingSync::Facility.new(doc.elements["/#{ns}:BuildingSync/#{ns}:Facilities/#{ns}:Facility"], ns)
    facility.determine_open_studio_standard(ASHRAE90_1)
    output_path = File.expand_path("../../output/#{File.basename(__FILE__, File.extname(__FILE__))}/", File.dirname(__FILE__))
    facility.get_sites[0].generate_baseline_osm(nil, ASHRAE90_1)
    facility.create_building_systems(output_path, 'Forced Air', 'Electricity', 'Electricity',
                                     false, false, false, false,
                                     false, false, false, false, false)
  end

  it 'Should return benchmark_eui' do
    facility = get_facility_from_file('building_151_level1.xml', ASHRAE90_1)
    expected_value = '9.7'
    puts "expected benchmark_eui: #{expected_value} but got: #{facility.building_eui_benchmark} " if facility.building_eui_benchmark != expected_value
    expect(facility.building_eui_benchmark == expected_value).to be true
  end

  it 'Should return eui_building' do
    facility = get_facility_from_file('building_151_level1.xml', ASHRAE90_1)
    expected_value = '10.5'
    puts "expected eui_building: #{expected_value} but got: #{facility.building_eui} " if facility.building_eui != expected_value
    expect(facility.building_eui == expected_value).to be true
  end

  it 'Should return auditor_contact_id' do
    facility = get_facility_from_file('building_151_level1.xml', ASHRAE90_1)
    expected_value = '123'
    puts "expected auditor_contact_id: #{expected_value} but got: #{facility.auditor_contact_id} " if facility.auditor_contact_id != expected_value
    expect(facility.auditor_contact_id == expected_value).to be true
  end

  it 'Should return benchmark_source' do
    facility = get_facility_from_file('building_151_level1.xml', ASHRAE90_1)
    expected_value = 'Benchmark Type 1'
    puts "expected benchmark_source: #{expected_value} but got: #{facility.benchmark_source} " if facility.benchmark_source != expected_value
    expect(facility.benchmark_source == expected_value).to be true
  end

  it 'Should return annual_fuel_use_native_units' do
    facility = get_facility_from_file('building_151_level1.xml', ASHRAE90_1)
    expected_value = 'kBtu/ft2'
    puts "expected annual_fuel_use_native_units: #{expected_value} but got: #{facility.annual_fuel_use_native_units} " if facility.annual_fuel_use_native_units != expected_value
    expect(facility.annual_fuel_use_native_units == expected_value).to be true
  end

  it 'Should return energy_cost' do
    facility = get_facility_from_file('building_151_level1.xml', ASHRAE90_1)
    expected_value = '1000'
    puts "expected energy_cost: #{expected_value} but got: #{facility.energy_cost} " if facility.energy_cost != expected_value
    expect(facility.energy_cost == expected_value).to be true
  end

  it 'Should return audit_date' do
    facility = get_facility_from_file('building_151_level1.xml', ASHRAE90_1)
    expected_value = Date.parse('5/1/2019')
    puts "expected auditor_contact_id: #{expected_value} but got: #{facility.audit_date} " if facility.audit_date != expected_value
    expect(facility.audit_date == expected_value).to be true
  end

  it 'Should return contact_name' do
    facility = get_facility_from_file('building_151_level1.xml', ASHRAE90_1)
    expected_value = 'a contact person'
    puts "expected contact_name: #{expected_value} but got: #{facility.contact_name} " if facility.contact_name != expected_value
    expect(facility.contact_name == expected_value).to be true
  end

  it 'Should return utility_name' do
    facility = get_facility_from_file('building_151_level1.xml', ASHRAE90_1)
    expected_value = 'an utility'
    puts "expected utility_name: #{expected_value} but got: #{facility.utility_name} " if facility.utility_name != expected_value
    expect(facility.utility_name == expected_value).to be true
  end

  it 'Should return metering_configuration ' do
    facility = get_facility_from_file('building_151_level1.xml', ASHRAE90_1)
    expected_value = 'metering config'
    puts "expected metering_configuration: #{expected_value} but got: #{facility.metering_configuration} " if facility.metering_configuration != expected_value
    expect(facility.metering_configuration == expected_value).to be true
  end

  it 'Should return rate_schedules ' do
    facility = get_facility_from_file('building_151_level1.xml', ASHRAE90_1)
    expected_value = 'rate schedule'
    puts "expected rate_schedules: #{expected_value} but got: #{facility.rate_schedules} " if facility.rate_schedules != expected_value
    expect(facility.rate_schedules == expected_value).to be true
  end

  it 'Should return rate_schedules ' do
    facility = get_facility_from_file('building_151_level1.xml', ASHRAE90_1)
    expected_value = 'meter 1'
    puts "expected utility_meter_number: #{expected_value} but got: #{facility.utility_meter_number} " if facility.utility_meter_number != expected_value
    expect(facility.utility_meter_number == expected_value).to be true
  end

  it 'Should generate osm and simulate baseline for all supported occupancy types' do
    run_minimum_facility('Retail', '1954', 'Gross', '69452', ASHRAE90_1)
  end

  def run_minimum_facility(occupancy_classification, year_of_const, floor_area_type, floor_area_value, standard_to_be_used)
    facility = create_minimum_facility(occupancy_classification,  year_of_const, floor_area_type, floor_area_value)
    facility.determine_open_studio_standard(standard_to_be_used)
    epw_file_path = File.expand_path('../../weather/CZ01RV2.epw', File.dirname(__FILE__))
    output_path = File.expand_path("../../output/#{File.basename(__FILE__, File.extname(__FILE__))}/", File.dirname(__FILE__))
    expect(facility.generate_baseline_osm(epw_file_path, output_path, standard_to_be_used)).to be true
    facility.write_osm(output_path)

    run_baseline_simulation(output_path + '/in.osm', 'CZ01RV2.epw')
  end

  def get_facility_from_file(xml_file_name, standard_to_be_used)
    xml_file_path = File.expand_path("../../files/#{xml_file_name}", File.dirname(__FILE__))
    File.open(xml_file_path, 'r') do |file|
      doc = REXML::Document.new(file)
      ns = 'auc'
      doc.elements.each("/#{ns}:BuildingSync/#{ns}:Facilities/#{ns}:Facility") do |facility|
        return BuildingSync::Facility.new(facility, ns)
      end
    end
  end

  def generate_baseline(file_name, ns)
    facilities = []
    @xml_path = File.expand_path("../../files/#{file_name}.xml", File.dirname(__FILE__))
    expect(File.exist?(@xml_path)).to be true
    @doc = create_xml_file_object(@xml_path)

    @doc.elements.each("#{ns}:BuildingSync/#{ns}:Facilities/#{ns}:Facility") do |facility_element|
      facilities.push(BuildingSync::Facility.new(facility_element, ns))
    end
    return facilities
  end

  def create_xml_file_object(xml_file_path)
    doc = nil
    File.open(xml_file_path, 'r') do |file|
      doc = REXML::Document.new(file)
    end
    return doc
  end

  def create_minimum_snippet(occupancy_classification, year_of_const, floor_area_type, floor_area_value)
    xml_path = File.expand_path('../../files/building_151_Blank.xml', File.dirname(__FILE__))
    ns = 'auc'
    doc = create_xml_file_object(xml_path)
    site_element = doc.elements["/#{ns}:BuildingSync/#{ns}:Facilities/#{ns}:Facility/#{ns}:Sites/#{ns}:Site"]

    occupancy_classification_element = REXML::Element.new("#{ns}:OccupancyClassification")
    occupancy_classification_element.text = occupancy_classification
    site_element.add_element(occupancy_classification_element)

    building_element = site_element.elements["#{ns}:Buildings/#{ns}:Building"]

    year_of_construction_element = REXML::Element.new("#{ns}:YearOfConstruction")
    year_of_construction_element.text = year_of_const
    building_element.add_element(year_of_construction_element)

    floor_areas_element = REXML::Element.new("#{ns}:FloorAreas")
    floor_area_element = REXML::Element.new("#{ns}:FloorArea")
    floor_area_type_element = REXML::Element.new("#{ns}:FloorAreaType")
    floor_area_type_element.text = floor_area_type
    floor_area_value_element = REXML::Element.new("#{ns}:FloorAreaValue")
    floor_area_value_element.text = floor_area_value

    floor_area_element.add_element(floor_area_type_element)
    floor_area_element.add_element(floor_area_value_element)
    floor_areas_element.add_element(floor_area_element)
    building_element.add_element(floor_areas_element)

    # doc.write(File.open(xml_path, 'w'), 2)

    return doc
  end

  def create_minimum_facility(occupancy_classification, year_of_const, floor_area_type, floor_area_value)
    xml_snippet = create_minimum_snippet(occupancy_classification, year_of_const, floor_area_type, floor_area_value)
    ns = 'auc'
    facility_element = xml_snippet.elements["/#{ns}:BuildingSync/#{ns}:Facilities/#{ns}:Facility"]
    if !facility_element.nil?
      return BuildingSync::Facility.new(facility_element, 'auc')
    else
      expect(facility_element.nil?).to be false
    end
  end

  def create_blank_xml_file1
    xml = Builder::XmlMarkup.new(indent: 2)
    xml.instruct! :xml, encoding: 'ASCII'
    xml.tag!('auc:BuildingSync') do |buildsync|
      buildsync.tag!('auc:Facilities') do |faclts|
        faclts.tag!('auc:Facility') do |faclt|
          faclt.tag!('auc:Sites') do |sites|
            sites.tag!('auc:Site') do |site|
              site.tag!('auc:Buildings') do |builds|
                builds.tag!('auc:Building') do |build|
                  build.tag!('auc:Sections') do |subsects|
                    subsects.tag!('auc:Section') do |subsect|
                      subsect.Perimeter 1325
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
