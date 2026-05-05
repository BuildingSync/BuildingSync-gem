# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************
require 'buildingsync/utility'

RSpec.describe 'Utility Spec' do
  describe 'Methods' do
    before(:all) do
      # -- Setup
      file_name = 'building_151_level1.xml'
      std = ASHRAE90_1
      xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.7.0')

      @utility = BuildingSync::Generator.new.get_utility_from_file(xml_path)
    end

    it 'Should return utility_name' do
      # -- Setup
      expected_value = 'an utility'

      # -- Assert
      expect(@utility.xget_name).to eql(expected_value)
    end
  end
end
