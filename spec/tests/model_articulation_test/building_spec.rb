# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************
require 'buildingsync/model_articulation/building'

RSpec.describe 'BuildingSpec' do
  describe 'Expected Errors' do
    it 'should raise an StandardError given a non-Building REXML Element' do
      # -- Setup
      ns = 'auc'
      v = '2.4.0'
      g = BuildingSync::Generator.new(ns, v)
      doc_string = g.create_bsync_root_to_building
      doc = REXML::Document.new(doc_string)
      facility_element = doc.elements["//#{ns}:Facility"]

      # -- Create Building object from Facility
      begin
        BuildingSync::Building.new(facility_element, '', '', ns)

        # Should not reach this
        expect(false).to be true
      rescue StandardError => e
        puts e.message
        expect(e.message).to eql 'Attempted to initialize Building object with Element name of: Facility'
      end
    end
    it 'Should raise StandardError when YearOfConstruction not provided at the Building level' do
      # -- Setup
      g = BuildingSync::Generator.new
      doc_string = g.create_bsync_root_to_building
      doc = REXML::Document.new(doc_string)
      building_xml = g.get_first_building_element(doc)

      begin
        b = BuildingSync::Building.new(building_xml, 'Retail', '', 'auc')

        # Should not reach this line
        expect(false).to be true
      rescue StandardError => e
        expect(e.message.to_s).to eq('Building ID: Building1. Year of Construction is blank in your BuildingSync file, but is required.')
      end
    end
    it 'Should raise StandardError when Site OccupancyClassification provided is empty string' do
      # -- Setup
      g = BuildingSync::Generator.new
      doc_string = g.create_bsync_root_to_building
      doc = REXML::Document.new(doc_string)
      building_xml = g.get_first_building_element(doc)
      # -- Setup - add necessary data
      year_of_construction = help_get_or_create(building_xml, 'auc:YearOfConstruction')
      year_of_construction.text = 1990

      begin
        b = BuildingSync::Building.new(building_xml, '', '', 'auc')

        # Should not reach this line
        expect(false).to be true
      rescue StandardError => e
        expect(e.message.to_s).to eq('Unable to set OccupancyClassification to be empty')
      end
    end
    it 'Should raise StandardError when Site OccupancyClassification provided is nil' do
      # -- Setup
      g = BuildingSync::Generator.new
      doc_string = g.create_bsync_root_to_building
      doc = REXML::Document.new(doc_string)
      building_xml = g.get_first_building_element(doc)
      # -- Setup - add necessary data
      year_of_construction = help_get_or_create(building_xml, 'auc:YearOfConstruction')
      year_of_construction.text = 1990

      begin
        b = BuildingSync::Building.new(building_xml, nil, '', 'auc')

        # Should not reach this line
        expect(false).to be true
      rescue StandardError => e
        expect(e.message.to_s).to eq('Building ID: Building1. OccupancyClassification must be defined at either the Site or Building level.')
      end
    end

    it 'Should raise StandardError when FloorsBelowGrade or ConditionedFloorsBelowGrade > 1' do
      # -- Setup
      g = BuildingSync::Generator.new
      doc_string = g.create_bsync_root_to_building
      doc = REXML::Document.new(doc_string)
      building_xml = g.get_first_building_element(doc)

      # -- Setup - add necessary data
      year_of_construction = help_get_or_create(building_xml, 'auc:YearOfConstruction')
      year_of_construction.text = 1990
      floors_below_grade = help_get_or_create(building_xml, 'auc:FloorsBelowGrade')
      floors_below_grade.text = 2

      begin
        b = BuildingSync::Building.new(building_xml, 'Retail', '', 'auc')

        # Should not reach this line
        expect(false).to be true
      rescue StandardError => e
        expect(e.message.to_s).to eq('Building ID: Building1. Number of stories below grade is > 1 (2.0).  Currently, only one story below grade is supported.')
      end
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

  describe 'Building XmlGetSet Accessors' do
    before(:all) do
      # -- Setup
      file_name = 'building_151_level1.xml'
      std = ASHRAE90_1
      xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.4.0')
      @building = BuildingSync::Generator.new.get_building_from_file(xml_path)
    end

    expectations = [
      # [expected value, method used to access, element_name]
      ['Property management company', 'xget_text', ['Ownership']],
      ['Retail', 'xget_text', ['OccupancyClassification']],
      ['Contact1', 'xget_attribute_for_element', ['PrimaryContactID', 'IDref']],
      [Date.new(2019, 1, 1), 'xget_text_as_date', ['RetrocommissioningDate']],
      [true, 'xget_text_as_bool', ['BuildingAutomationSystem']],
      [true, 'xget_text_as_bool', ['HistoricalLandmark']],
      [2010, 'xget_text_as_integer', ['YearOfLastEnergyAudit']],
      [2003, 'xget_text_as_integer', ['YearOfLastMajorRemodel']],
      [2010, 'xget_text_as_integer', ['YearOfLastEnergyAudit']],
      [60.0, 'xget_text_as_float', ['PercentOccupiedByOwner']]
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
      xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.4.0')
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
