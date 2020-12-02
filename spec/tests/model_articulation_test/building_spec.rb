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
    g = BuildingSync::Generator.new
    doc_string = g.create_bsync_root_to_building
    doc = REXML::Document.new(doc_string)
    building_xml = g.get_first_building_element(doc)

    begin
      b = BuildingSync::Building.new(building_xml, '', '', 'auc')

      # Should not reach this line
      expect(false).to be true
    rescue StandardError => e
      expect(e.message.to_s).to eq('Building ID: Building1. Year of Construction is blank in your BuildingSync file, but is required.')
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
    puts "expected building template: CBES Pre-1978 but got: #{building.get_standard_template} " if building.get_standard_template != 'CBES Pre-1978'
    expect(building.get_standard_template == 'CBES Pre-1978').to be true
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

  describe 'Building XmlGetSet Accessors' do
    before(:all) do
      # -- Setup
      file_name = 'building_151_level1.xml'
      std = ASHRAE90_1
      xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
      @building = BuildingSync::Generator.new.get_building_from_file(xml_path)
    end

    expectations = [
        # [expected value, method used to access, element_name]
        ['Property management company', 'xget_text', ['Ownership']],
        ['Health care-Inpatient hospital', 'xget_text', ['OccupancyClassification']],
        ['Contact1', 'xget_attribute_for_element', ['PrimaryContactID', 'IDref']],
        [Date.new(2019, 1, 1), 'xget_text_as_date', ['RetrocommissioningDate']],
        [true, 'xget_text_as_bool', ['BuildingAutomationSystem']],
        [true, 'xget_text_as_bool', ['HistoricalLandmark']],
        [2010, 'xget_text_as_integer', ['YearOfLastEnergyAudit']],
        [2003, 'xget_text_as_integer', ['YearOfLastMajorRemodel']],
        [2010, 'xget_text_as_integer', ['YearOfLastEnergyAudit']],
        [60.0, 'xget_text_as_float', ['PercentOccupiedByOwner']],
    ]

    expectations.each do |e|
      it "#{e[2][0]} accessed via #{e[1]} should equal '#{e[0]}'" do
        expect(@building.send(e[1], *e[2])).to eq(e[0])
      end
    end
  end

  describe 'Building Attribute Accessors' do
    before(:all) do
      # -- Setup
      file_name = 'building_151_level1.xml'
      std = ASHRAE90_1
      xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
      @building = BuildingSync::Generator.new.get_building_from_file(xml_path)
    end
    it 'Should return OccupantQuantity' do
      # -- Setup
      expected_value = '15000'

      # -- Assert
      puts "expected occupant_quantity: #{expected_value} but got: #{@building.occupant_quantity} " if @building.occupant_quantity != expected_value
      expect(@building.occupant_quantity == expected_value).to be true
    end

    it 'Should return NumberOfUnits' do
      # -- Setup
      expected_value = '18'

      # -- Assert
      puts "expected number_of_units: #{expected_value} but got: #{@building.number_of_units} " if @building.number_of_units != expected_value
      expect(@building.number_of_units == expected_value).to be true
    end

    it 'Should return built_year' do
      expected_value = Integer('2003')

      # -- Assert
      puts "expected built_year: #{expected_value} but got: #{@building.built_year} " if @building.built_year != expected_value
      expect(@building.built_year == expected_value).to be true
    end
  end

end
