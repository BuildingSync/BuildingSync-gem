# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************
require 'builder'

require 'buildingsync/generator'

RSpec.describe 'FacilitySpec' do
  describe 'Expected Errors' do
    it 'should raise an StandardError given a non-Facility REXML Element' do
      # -- Setup
      ns = 'auc'
      v = '2.4.0'
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
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.4.0')

    facility = BuildingSync::Generator.new.get_facility_from_file(xml_path)

    # -- Assert
    expect(facility.report.scenarios.size).to eq 17
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
end

RSpec.describe 'Facility Methods' do
  before(:all) do
    # -- Setup
    file_name = 'building_151_level1.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.4.0')

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
