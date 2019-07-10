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

RSpec.describe 'BuildingSpec' do
  it 'Should generate meaningful error when passing empty XML data' do
    begin
      generate_baseline('building_151_Blank', '', '', 'auc')
    rescue StandardError => e
      expect(e.message.include?('Year of Construction is blank in your BuildingSync file.')).to be true
    end
  end

  it 'Should create an instance of the site class with minimal XML snippet' do
    create_minimum_building('Retail', '1954', 'Gross', '69452')
  end

  it 'Should return the no of building stories' do
    building = create_minimum_building('Retail', '1954', 'Gross', '69452')
    puts "expected no. of stories: 1 but got: #{building.num_stories} " if building.num_stories != 1
    expect(building.num_stories == 1).to be true
  end

  it 'Should return the correct building type' do
    building = create_minimum_building('Retail', '1954', 'Gross', '69452')
    puts "expected building type: RetailStandalone but got: #{building.get_building_type} " if building.get_building_type != 'RetailStandalone'
    expect(building.get_building_type == 'RetailStandalone').to be true
  end

  it 'Should return the correct system type' do
    building = create_minimum_building('Retail', '1954', 'Gross', '69452')
    puts "expected system type: PSZ-AC with gas coil heat but got: #{building.get_system_type} " if building.get_system_type != 'PSZ-AC with gas coil heat'
    expect(building.get_system_type == 'PSZ-AC with gas coil heat').to be true
  end

  it 'Should return the correct building template' do
    building = create_minimum_building('Retail', '1954', 'Gross', '69452')
    building.determine_open_studio_standard(CA_TITLE24)
    puts "expected building template: CBES Pre-1978 but got: #{building.get_building_template} " if building.get_building_template != 'CBES Pre-1978'
    expect(building.get_building_template == 'CBES Pre-1978').to be true
  end

  it 'Should successfully set an ASHRAE 90.1 climate zone' do
    building = create_minimum_building('Retail', '1954', 'Gross', '69452')
    building.get_model
    puts "expected climate zone: true but got: #{building.set_climate_zone('ASHRAE 3C', ASHRAE90_1, '')} " if building.set_climate_zone('ASHRAE 3C', ASHRAE90_1, '') != true
    expect(building.set_climate_zone('ASHRAE 3C', ASHRAE90_1, '')).to be true
  end

  it 'Should successfully set a CA T24 climate zone' do
    building = create_minimum_building('Office', '2015', 'Gross', '20000')
    building.get_model
    puts "expected climate zone: true but got: #{building.set_climate_zone('Climate Zone 6', CA_TITLE24, '')} " if building.set_climate_zone('Climate Zone 6', CA_TITLE24, '') != true
    expect(building.set_climate_zone('Climate Zone 6', CA_TITLE24, '')).to be true
  end

  # we skip the method "set_weater_and_climate_zone" function because this method doesn't return any value

  def generate_baseline(file_name, occupancy_type, total_floor_area, ns)
    buildings = []
    xml_path = File.expand_path("../../files/#{file_name}.xml", File.dirname(__FILE__))
    expect(File.exist?(xml_path)).to be true

    doc = create_xml_file_object(xml_path)
    site_xml = create_site_object(doc, ns)

    site_xml.elements.each("#{ns}:Buildings/#{ns}:Building") do |building_element|
      buildings.push(BuildingSync::Building.new(building_element, occupancy_type, total_floor_area, ns))
    end
    return buildings
  end

  def create_site_object(doc, ns)
    sites = []
    doc.elements.each("/#{ns}:BuildingSync/#{ns}:Facilities/#{ns}:Facility/#{ns}:Sites/#{ns}:Site") do |site_xml|
      sites.push(site_xml)
    end
    return sites[0]
  end

  def create_xml_file_object(xml_file_path)
    doc = nil
    File.open(xml_file_path, 'r') do |file|
      doc = REXML::Document.new(file)
    end
    return doc
  end

  def create_minimum_building(occupancy_classification, year_of_const, floor_area_type, floor_area_value)
    ns = 'auc'
    xml_snippet = create_minimum_snippet(occupancy_classification, year_of_const, floor_area_type, floor_area_value, ns)

    building_element = xml_snippet.elements["/#{ns}:BuildingSync/#{ns}:Facilities/#{ns}:Facility/#{ns}:Sites/#{ns}:Site/#{ns}:Buildings/#{ns}:Building"]
    if !building_element.nil?
      return BuildingSync::Building.new(building_element, '', '', ns)
    else
      expect(building_element.nil?).to be false
    end
  end

  def create_minimum_snippet(occupancy_classification, year_of_const, floor_area_type, floor_area_value, ns)
    xml_path = File.expand_path('../../files/building_151_Blank.xml', File.dirname(__FILE__))
    doc = create_xml_file_object(xml_path)

    building_element = doc.elements["#{ns}:BuildingSync/#{ns}:Facilities/#{ns}:Facility/#{ns}:Sites/#{ns}:Site/#{ns}:Buildings/#{ns}:Building"]

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

    occupancy_classification_element = REXML::Element.new("#{ns}:OccupancyClassification")
    occupancy_classification_element.text = occupancy_classification
    building_element.add_element(occupancy_classification_element)
    # doc.write(File.open(xml_path, 'w'), 2)

    return doc
  end
end
