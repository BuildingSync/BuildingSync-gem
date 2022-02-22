# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2022, Alliance for Sustainable Energy, LLC.
# BuildingSync(R), Copyright (c) 2015-2022, Alliance for Sustainable Energy, LLC.
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
  describe 'Expected Errors' do
    it 'should raise an StandardError given a non-Facility REXML Element' do
      # -- Setup
      ns = 'auc'
      v = '2.2.0'
      g = BuildingSync::Generator.new(ns, v)
      doc_string = g.create_bsync_root_to_building
      doc = REXML::Document.new(doc_string)

      # -- Create Building object from Facility
      begin
        BuildingSync::Facility.new(doc.root, ns)

        # Should not reach this
        expect(false).to be true
      rescue StandardError => e
        puts e.message
        expect(e.message).to eql 'Attempted to initialize Facility object with Element name of: BuildingSync'
      end
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
    epw_path = File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw')
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
    facility.generate_baseline_osm(nil, output_path, ASHRAE90_1)
    facility.create_building_systems(main_output_dir: output_path, htg_src: 'Electricity',
                                     add_elevators: true, add_exterior_lights: true, remove_objects: true)
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
    facility.generate_baseline_osm(nil, output_path, ASHRAE90_1)
    facility.create_building_systems(main_output_dir: output_path, zone_hash: nil, hvac_delivery_type: 'Forced Air',
                                     htg_src: 'Electricity', clg_src: 'Electricity', add_space_type_loads: false,
                                     add_constructions: false, add_elevators: false, add_exterior_lights: false,
                                     add_exhaust: false, add_swh: false, add_hvac: false, add_thermostat: false,
                                     remove_objects: false)
  end
end

RSpec.describe 'Facility Scenario Parsing' do
  before(:each) do
    # -- Setup
    @ns = 'auc'
    g = BuildingSync::Generator.new
    @doc = g.create_minimum_snippet('Retail')
    @facility_xml = g.get_first_facility_element(@doc)
  end
  it 'building_151.xml get_scenarios should return an Array of length 30 with elements of type BuildingSync::Scenario' do
    # -- Setup
    file_name = 'building_151.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')

    facility = BuildingSync::Generator.new.get_facility_from_file(xml_path)

    # -- Assert
    expect(facility.report.scenarios.size).to eq 30
    facility.report.scenarios.each do |scenario|
      expect(scenario).to be_an_instance_of(BuildingSync::Scenario)
    end
  end
  it 'scenarios should return an empty array if no scenario elements are found' do
    scenarios = @doc.get_elements("//#{@ns}:Scenarios").first
    scenarios.elements.delete("#{@ns}:Scenario")

    scenario_elements = @doc.get_elements("//#{@ns}:Scenarios/#{@ns}:Scenario")
    expect(scenario_elements.size).to eq(0)

    facility = BuildingSync::Facility.new(@facility_xml, @ns)

    # -- Assert
    expect(facility.report.scenarios).to be_an_instance_of(Array)
    expect(facility.report.scenarios.empty?).to be true
  end
end

RSpec.describe 'Facility Systems Mapping' do
  before(:all) do
    # -- Setup
    @ns = 'auc'
    g = BuildingSync::Generator.new
    doc = g.create_minimum_snippet('Retail')
    doc_no_systems = g.create_minimum_snippet('Retail)')
    @facility_no_systems_xml = g.get_first_facility_element(doc_no_systems)

    g.add_hvac_system_to_first_facility(doc, 'HVACSystem-1', 'VAV with Hot Water Reheat')
    g.add_hvac_system_to_first_facility(doc, 'HVACSystem-2', 'VAV with Hot Water Reheat')
    g.add_lighting_system_to_first_facility(doc)
    g.add_plug_load_to_first_facility(doc)

    facility_xml = g.get_first_facility_element(doc)
    @facility = BuildingSync::Facility.new(facility_xml, @ns)
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
    it 'Should return contact_name' do
      # -- Setup
      expected_value = 'a contact person'

      # -- Assert
      expect(@facility.get_auditor_contact_name).to eql(expected_value)
    end

    it 'Should return annual_fuel_use_native_units' do
      # -- Setup
      expected_value = 123
      first_cb_measured = @facility.report.cb_measured[0]
      first_ru = first_cb_measured.get_resource_uses[0]

      # -- Assert
      expect(first_cb_measured).to be_an_instance_of(BuildingSync::Scenario)
      expect(first_ru).to be_an_instance_of(BuildingSync::ResourceUse)
      expect(first_ru.xget_text_as_integer('AnnualFuelUseNativeUnits')).to eql expected_value
    end

    it 'Should return energy_cost' do
      # -- Setup
      expected_value = 1000
      first_cb_measured = @facility.report.cb_measured[0]
      first_art = first_cb_measured.get_all_resource_totals[0]

      # -- Assert
      expect(first_cb_measured).to be_an_instance_of(BuildingSync::Scenario)
      expect(first_art).to be_an_instance_of(BuildingSync::AllResourceTotal)
      expect(first_art.xget_text_as_integer('EnergyCost')).to eql expected_value
    end

    it 'Should return metering_configuration ' do
      # -- Setup
      expected_value = 'Direct metering'
      first_utility = @facility.report.utilities[0]

      # -- Assert
      expect(first_utility).to be_an_instance_of(BuildingSync::Utility)
      expect(first_utility.xget_text('MeteringConfiguration')).to eql expected_value
    end

    it 'Should return rate_schedules ' do
      # -- Setup
      expected_value = REXML::Element.new('auc:CriticalPeakPricing')
      first_utility = @facility.report.utilities[0]
      first_rate_sch = first_utility.get_rate_schedules[0]
      rate_structure_type = first_rate_sch.get_elements('auc:TypeOfRateStructure/*')[0]

      # -- Assert
      expect(first_utility).to be_an_instance_of(BuildingSync::Utility)
      expect(first_rate_sch).to be_an_instance_of(REXML::Element)
      expect(rate_structure_type.to_s).to eql expected_value.to_s
    end
  end
end
