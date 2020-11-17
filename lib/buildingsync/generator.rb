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
require 'builder/xmlmarkup'

module BuildingSync
  # Generator class that generates basic data that is used mostly for testing
  class Generator

    # @param version [String] version of BuildingSync
    def initialize(version = "2.2.0", ns = 'auc')
      supported_versions = ["2.0", "2.2.0"]
      if !supported_versions.include? version
        @version = nil
        OpenStudio.logFree(OpenStudio::Error, "BuildingSync.Generator.create_bsync_root_to_section", "The version: #{version} is not one of the supported versions: #{supported_versions}")
      else
        @version = version
      end
      @ns = ns
    end

    # Starts from scratch and creates all necessary elements up to and including an
    #  - Sites/Site/Buildings/Building/Sections/Section
    #  - Reports/Report/Scenarios/Scenario
    # @return [String] string formatted XML document
    def create_bsync_root_to_building
      xml = Builder::XmlMarkup.new(indent: 2)
      auc_ns = "http://buildingsync.net/schemas/bedes-auc/2019"
      location = "https://raw.githubusercontent.com/BuildingSync/schema/v#{@version}/BuildingSync.xsd"
      xml.instruct! :xml
      xml.tag!("#{@ns}BuildingSync", {
          :"xmlns:#{@ns}" => auc_ns,
          :"xsi:schemaLocation" => "#{auc_ns} #{location}",
          :"xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
          :version => "#{@version}"
      }) do |buildsync|

        buildsync.tag!("#{@ns}:Facilities") do |faclts|
          faclts.tag!("#{@ns}:Facility", {:ID => "Facility1"}) do |faclt|
            faclt.tag!("#{@ns}:Sites") do |sites|
              sites.tag!("#{@ns}:Site", {:ID => "Site1"}) do |site|
                site.tag!("#{@ns}:Buildings") do |builds|
                  builds.tag!("#{@ns}:Building", {:ID => "Building1"}) do |build|
                  end
                end
              end
            end
          end
        end
      end
    end

    # creates a minimum building sync snippet
    # @param occupancy_classification [String]
    # @param year_of_const [Integer]
    # @param floor_area_type [String]
    # @param floor_area_value [Float]
    # @param ns [String]
    # @return REXML::Document
    def create_minimum_snippet(occupancy_classification, year_of_const, floor_area_type, floor_area_value, floors_above_grade = 1, ns = 'auc')
      doc_string = create_bsync_root_to_building
      doc = REXML::Document.new(doc_string)
      site_element = doc.elements["/#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility/#{@ns}:Sites/#{@ns}:Site"]

      occupancy_classification_element = REXML::Element.new("#{@ns}:OccupancyClassification")
      occupancy_classification_element.text = occupancy_classification
      site_element.add_element(occupancy_classification_element)

      building_element = site_element.elements["#{@ns}:Buildings/#{@ns}:Building"]

      year_of_construction_element = REXML::Element.new("#{@ns}:YearOfConstruction")
      year_of_construction_element.text = year_of_const
      building_element.add_element(year_of_construction_element)

      floor_areas_element = REXML::Element.new("#{@ns}:FloorAreas")
      floor_area_element = REXML::Element.new("#{@ns}:FloorArea")
      floor_area_type_element = REXML::Element.new("#{@ns}:FloorAreaType")
      floor_area_type_element.text = floor_area_type
      floor_area_value_element = REXML::Element.new("#{@ns}:FloorAreaValue")
      floor_area_value_element.text = floor_area_value

      floor_area_element.add_element(floor_area_type_element)
      floor_area_element.add_element(floor_area_value_element)
      floor_areas_element.add_element(floor_area_element)
      building_element.add_element(floor_areas_element)

      floors_above_grade_element = REXML::Element.new("#{@ns}:FloorsAboveGrade")
      floors_above_grade_element.text = floors_above_grade
      building_element.add_element(floors_above_grade_element)

      occupancy_classification_element = REXML::Element.new("#{@ns}:OccupancyClassification")
      occupancy_classification_element.text = occupancy_classification
      building_element.add_element(occupancy_classification_element)

      return doc
    end

    # creates a minimum facility
    # @param occupancy_classification [String]
    # @param year_of_const [Integer]
    # @param floor_area_type [String]
    # @param floor_area_value [Float]
    # @return BuildingSync::Facility
    def create_minimum_facility(occupancy_classification, year_of_const, floor_area_type, floor_area_value, floors_above_grade = 1)
      xml_snippet = create_minimum_snippet(occupancy_classification, year_of_const, floor_area_type, floor_area_value, floors_above_grade)
      ns = 'auc'
      facility_element = xml_snippet.elements["/#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility"]
      if !facility_element.nil?
        return BuildingSync::Facility.new(facility_element, @ns)
      else
        expect(facility_element.nil?).to be false
      end
    end


    # create minimum site
    # @param occupancy_classification [String]
    # @param year_of_const [Integer]
    # @param floor_area_type [String]
    # @param floor_area_value [Float]
    # @return [BuildingSync::Site]
    def create_minimum_site(occupancy_classification, year_of_const, floor_area_type, floor_area_value)
      xml_snippet = create_minimum_snippet(occupancy_classification, year_of_const, floor_area_type, floor_area_value)
      site_element = xml_snippet.elements["/#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility/#{@ns}:Sites/#{@ns}:Site"]
      if !site_element.nil?
        return BuildingSync::Site.new(site_element, @ns)
      else
        expect(site_element.nil?).to be false
      end
    end

    def create_minimum_building(occupancy_classification, year_of_const, floor_area_type, floor_area_value)
      xml_snippet = create_minimum_snippet(occupancy_classification, year_of_const, floor_area_type, floor_area_value)

      building_element = xml_snippet.elements["/#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility/#{@ns}:Sites/#{@ns}:Site/#{@ns}:Buildings/#{@ns}:Building"]
      if !building_element.nil?
        return BuildingSync::Building.new(building_element, '', '', @ns)
      else
        expect(building_element.nil?).to be false
      end
    end

    attr_reader :version
  end
end
