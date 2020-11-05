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
module BuildingSync
  # Generator class that generates basic data that is used mostly for testing
  class Generator
    # creates a minimum building sync snippet
    # @param occupancy_classification [string]
    # @param year_of_const [int]
    # @param floor_area_type [string]
    # @param floor_area_value [float]
    # @param ns [string]
    # @return REXML::Document
    def create_minimum_snippet(occupancy_classification, year_of_const, floor_area_type, floor_area_value, ns = 'auc')
      xml_path = File.expand_path('./../../spec/files/building_151_Blank.xml', File.dirname(__FILE__))

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

      occupancy_classification_element = REXML::Element.new("#{ns}:OccupancyClassification")
      occupancy_classification_element.text = occupancy_classification
      building_element.add_element(occupancy_classification_element)

      return doc
    end

    # creates a minimum facility
    # @param occupancy_classification [string]
    # @param year_of_const [int]
    # @param floor_area_type [string]
    # @param floor_area_value [float]
    # @return BuildingSync::Facility
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
  end
end
