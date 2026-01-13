# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************
RSpec.describe 'BuildingSection' do
  describe 'initialization' do
    before(:all) do
      # -- Setup
      @ns = 'auc'
      g = BuildingSync::Generator.new
      doc_string = g.create_bsync_root_to_building
      doc = REXML::Document.new(doc_string)
      g.add_section_to_first_building(doc)
      @facility_xml = g.get_first_facility_element(doc)
      @section_xml = g.get_first_building_section_element(doc)
    end
    it 'should raise an error given a non-Section REXML Element' do
      BuildingSync::BuildingSection.new(@facility_xml, nil, nil, nil, @ns)
    rescue StandardError => e
      expect(e.message).to eql 'Attempted to initialize Section object with Element name of: Facility'
    end

    it 'Should generate meaningful error when passing empty XML data' do
      section = BuildingSync::BuildingSection.new(@section_xml, nil, nil, nil, @ns)

      # Should not reach this line
      expect(false).to be true
    rescue StandardError => e
      expect(e.message.to_s).to eq('Unable to set OccupancyClassification to nil')
    end
  end
end

RSpec.describe 'BuildingSection methods' do
  to_test = [
    ['Retail', 'xget_text', ['OccupancyClassification']],
    ['40.0', 'typical_occupant_usage_value_hours', []],
    ['50.0', 'typical_occupant_usage_value_weeks', []]
  ]
  to_test.each do |test|
    it 'building_151_level1.xml: Should return values as expected' do
      # -- Setup
      file_name = 'building_151_level1.xml'
      std = ASHRAE90_1
      xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.4.0')
      building_section = BuildingSync::Generator.new.get_building_section_from_file(xml_path)

      # -- Assert
      expect(building_section.send(test[1], *test[2]) == test[0]).to be true
    end
  end
end
