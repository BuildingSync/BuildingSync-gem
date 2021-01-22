# frozen_string_literal: true

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
      xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
      building_section = BuildingSync::Generator.new.get_building_section_from_file(xml_path)

      # -- Assert
      expect(building_section.send(test[1], *test[2]) == test[0]).to be true
    end
  end
end
