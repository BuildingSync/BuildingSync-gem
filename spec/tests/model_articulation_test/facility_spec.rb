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
  # it 'Should generate meaningful error when passing empty XML data' do
  #   # -- Setup
  #   g = BuildingSync::Generator.new
  #   doc_string = g.create_bsync_root_to_building
  #   doc = REXML::Document.new(doc_string)
  #   facility_xml = g.get_first_facility_element(doc)
  #   begin
  #     f = BuildingSync::Facility.new(facility_xml, 'auc')
  #
  #     # Should not reach this line
  #     expect(false).to be true
  #   rescue StandardError => e
  #     puts "expected error message:Year of Construction is blank in your BuildingSync file. but got: #{e.message} " if !e.message.include?('Year of Construction is blank in your BuildingSync file.')
  #     expect(e.message.include?('Year of Construction is blank in your BuildingSync file.')).to be true
  #   end
  # end
  #
  # # TODO: Add actual assertions
  # it 'Should create an instance of the facility class with minimal XML snippet' do
  #   generator = BuildingSync::Generator.new
  #   generator.create_minimum_facility('Retail', '1954', 'Gross', '69452')
  # end
  #
  # it 'Should return the boolean value for creating osm file correctly or not.' do
  #   # -- Setup
  #   file_name = 'building_151.xml'
  #   std = ASHRAE90_1
  #   xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
  #   epw_path = File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw')
  #   expect(File.exist?(epw_path)).to be true
  #
  #   generator = BuildingSync::Generator.new
  #   facility = generator.create_minimum_facility('Retail', '1954', 'Gross', '69452')
  #   facility.determine_open_studio_standard(std)
  #
  #   # -- Assert
  #   expect(facility.generate_baseline_osm(epw_path, output_path, std)).to be true
  # end

  # # TODO: Add actual assertions
  # it 'Should create a building system with parameters set to true' do
  #   # -- Setup
  #   file_name = 'building_151.xml'
  #   std = ASHRAE90_1
  #   xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
  #   doc = nil
  #   File.open(xml_path, 'r') do |file|
  #     doc = REXML::Document.new(file)
  #   end
  #   ns = 'auc'
  #
  #   # -- Act
  #   facility = BuildingSync::Facility.new(doc.elements["/#{ns}:BuildingSync/#{ns}:Facilities/#{ns}:Facility"], ns)
  #   facility.determine_open_studio_standard(ASHRAE90_1)
  #   facility.generate_baseline_osm(nil, output_path, ASHRAE90_1)
  #   facility.create_building_systems(output_path, nil, 'Forced Air', 'Electricity', 'Electricity',
  #                                    true, true, true, true,
  #                                    true, true, true, true, true)
  # end

  # # TODO: Add actual assertions
  # it 'Should create a building system with parameters set to false' do
  #   # -- Setup
  #   file_name = 'building_151.xml'
  #   std = ASHRAE90_1
  #   xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
  #   doc = nil
  #   File.open(xml_path, 'r') do |file|
  #     doc = REXML::Document.new(file)
  #   end
  #
  #   # -- Act
  #   ns = 'auc'
  #   facility = BuildingSync::Facility.new(doc.elements["/#{ns}:BuildingSync/#{ns}:Facilities/#{ns}:Facility"], ns)
  #   facility.determine_open_studio_standard(ASHRAE90_1)
  #   facility.generate_baseline_osm(nil, output_path, ASHRAE90_1)
  #   facility.create_building_systems(output_path, 'Forced Air', 'Electricity', 'Electricity',
  #                                    false, false, false, false,
  #                                    false, false, false, false, false)
  # end
end

RSpec.describe "Facility Systems Mapping" do
  before(:all) do
    # -- Setup
    @ns = 'auc'
    g = BuildingSync::Generator.new
    doc = g.create_minimum_snippet('Retail')
    doc_no_systems = g.create_minimum_snippet('Retail)')
    @facility_no_systems_xml = g.get_first_facility_element(doc_no_systems)

    g.add_hvac_system_to_first_facility(doc, "HVACSystem-1", "VAV with Hot Water Reheat")
    g.add_hvac_system_to_first_facility(doc, "HVACSystem-2", "VAV with Hot Water Reheat")
    g.add_lighting_system_to_first_facility(doc)
    g.add_plug_load_to_first_facility(doc)

    facility_xml = g.get_first_facility_element(doc)
    @facility = BuildingSync::Facility.new(facility_xml, @ns)
    puts @facility.systems_map
  end
  describe 'with systems defined' do
    it 'should be of the correct data structure' do

      # -- Assert
      expect(@facility.systems_map).to be_an_instance_of(Hash)
    end
    it 'should have the correct keys' do
      # -- Assert correct keys get created
      expected_keys = ['HVACSystems', 'LightingSystems', 'PlugLoads']
      expected_keys.each do |k|
        expect(@facility.systems_map.key?(k)).to be true
      end
    end

    it 'values should be of the correct type and size' do
      # -- Assert values of keys are correct type and size
      expect(@facility.systems_map['HVACSystems']).to be_an_instance_of(Array)
      expect(@facility.systems_map['LightingSystems']).to be_an_instance_of(Array)
      expect(@facility.systems_map['PlugLoads']).to be_an_instance_of(Array)
      expect(@facility.systems_map['HVACSystems'].size).to eq(2)
      expect(@facility.systems_map['LightingSystems'].size).to eq(1)
      expect(@facility.systems_map['PlugLoads'].size).to eq(1)
    end

    it 'values in array should be of the correct type' do
      # Only HVACSystem and LightingSystem should be typed as BSync element types (for now)
      expect(@facility.systems_map['HVACSystems'][0]).to be_an_instance_of(BuildingSync::HVACSystem)
      expect(@facility.systems_map['LightingSystems'][0]).to be_an_instance_of(BuildingSync::LightingSystemType)
      expect(@facility.systems_map['PlugLoads'][0]).to be_an_instance_of(REXML::Element)
    end
  end
  describe 'with no systems defined' do
    it 'should not error when Systems has no children' do
      # -- Setup - add a blank Systems element
      REXML::Element.new("#{@ns}:Systems", @facility_no_systems_xml)

      expect(@facility_no_systems_xml.get_elements("#{@ns}:Systems").size).to eq(1)
      facility_no_systems = BuildingSync::Facility.new(@facility_no_systems_xml, @ns)
    end
    it 'should not error when Systems does not exist' do
      # -- Setup - remove the Systems element
      @facility_no_systems_xml.elements.delete("#{@ns}:Systems")

      expect(@facility_no_systems_xml.get_elements("#{@ns}:Systems").size).to eq(0)
      facility_no_systems = BuildingSync::Facility.new(@facility_no_systems_xml, @ns)
    end
  end
end

RSpec.describe 'Facility Methods' do
  before(:all) do
    # -- Setup
    file_name = 'building_151_level1.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')

    @facility = BuildingSync::Generator.new.get_facility_from_file(xml_path)
  end
  describe 'building_151_level1.xml' do

    it 'Should return benchmark_eui' do
      expected_value = '9.7'

      # -- Assert
      expect(@facility.building_eui_benchmark == expected_value).to be true
    end

    it 'Should return eui_building' do
      # -- Setup
      expected_value = '10.5'

      # -- Assert
      expect(@facility.building_eui == expected_value).to be true
    end

    it 'Should return auditor_contact_id' do
      # -- Setup
      expected_value = 'Contact1'

      # -- Assert
      expect(@facility.auditor_contact_id == expected_value).to be true
    end

    it 'Should return benchmark_tool' do
      # -- Setup
      expected_value = 'Portfolio Manager'

      # -- Assert
      expect(@facility.benchmark_tool == expected_value).to be true
    end

    it 'Should return annual_fuel_use_native_units' do
      # -- Setup
      expected_value = '123'

      # -- Assert
      expect(@facility.annual_fuel_use_native_units == expected_value).to be true
    end

    it 'Should return energy_cost' do
      # -- Setup
      expected_value = '1000'

      # -- Assert
      expect(@facility.energy_cost == expected_value).to be true
    end

    it 'Should return audit_date' do
      # -- Setup
      expected_value = Date.parse('2019-05-01')

      # -- Assert
      expect(@facility.audit_date == expected_value).to be true
    end

    it 'Should return utility_name' do
      # -- Setup
      expected_value = 'an utility'

      # -- Assert
      expect(@facility.utility_name == expected_value).to be true
    end

    it 'Should return metering_configuration ' do
      # -- Setup
      expected_value = 'Direct metering'

      # -- Assert
      expect(@facility.metering_configuration == expected_value).to be true
    end

    it 'Should return rate_schedules ' do
      # -- Setup
      expected_value = REXML::Element.new("auc:CriticalPeakPricing")
      rate_schedule = @facility.rate_schedules_xml[0]
      rate_structure_type = rate_schedule.get_elements("auc:TypeOfRateStructure/*")[0]

      # -- Assert
      expect(rate_structure_type.to_s == expected_value.to_s).to be true
    end

    it 'Should return utility_meter_numbers' do
      # -- Setup
      expected_value = '0123456'
      meter_number = @facility.utility_meter_numbers[0]

      # -- Assert
      puts "expected utility_meter_number: #{expected_value} but got: #{meter_number} " if meter_number != expected_value
      expect(meter_number == expected_value).to be true
    end
  end

end

RSpec.describe 'Facility Methods' do
  before(:all) do
    # -- Setup
    file_name = 'report_479.xml'
    std = ASHRAE90_1
    @xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__)

    @facility = BuildingSync::Generator.new.get_facility_from_file(@xml_path)
  end
  describe 'report_479.xml' do
    it 'Should return error about number of stories below grade' do
      # -- Setup

      begin
        BuildingSync::Generator.new.get_facility_from_file(@xml_path)

        # Should not get here
        expect(false).to be true
      rescue StandardError => e
        # -- Assert
        puts "rescued StandardError: #{e.message}"
        expect(e.message.include?('Number of stories below grade is larger than')).to be true
      end
    end

    it 'Should return contact_name' do
      # -- Setup
      expected_value = 'John Doe'

      # -- Assert
      expect(@facility.contact_auditor_name == expected_value).to be true
    end
  end
end
