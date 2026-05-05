# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************
require 'openstudio-standards'

require 'buildingsync/constants'
require 'buildingsync/helpers/helper'

module BuildingSync
  # BuildingSection class
  class BuildingSection < SpatialElement
    include OpenstudioStandards
    include BuildingSync::Helper
    include BuildingSync::XmlGetSet
    # initialize
    # @param base_xml [REXML:Element] an element corresponding to a single auc:Section
    # @param bldgsync_occ_type [String] Office, Retail, etc.
    # @param building_total_floor_area [Float]
    # @param num_stories [Float]
    # @param ns [String] namespace, likely 'auc'
    def initialize(base_xml, building_occupancy_classification, building_total_floor_area, num_stories, ns, standard_to_be_used)
      super(base_xml, ns, standard_to_be_used)
      @base_xml = base_xml
      @ns = ns

      help_element_class_type_check(base_xml, 'Section')

      @door_ids = []
      @wall_ids = []
      @window_ids = []
      @roof_ids = []
      @skylight_ids = []
      @exterior_floor_ids = []
      @foundation_ids = []

      # parameter to read and write.
      @fraction_area = nil
      @standards_building_type = nil
      @occupancy_classification = nil
      @typical_occupant_usage_value_hours = nil
      @typical_occupant_usage_value_weeks = nil
      @occupant_quantity = nil
      @principal_hvac_type = nil
      @num_stories = num_stories
      @standard_to_be_used = standard_to_be_used

      @total_floor_area = read_floor_areas(building_total_floor_area)

      # code to initialize
      read_xml(building_occupancy_classification)
    end

    # read xml
    # @param building_occupancy_classification [String]
    def read_xml(building_occupancy_classification)
      # floor areas
      # based on the occupancy type set building type, system type and bar division method
      read_building_section_other_detail(building_occupancy_classification)
      read_construction_types

      if @base_xml.elements["#{@ns}:OccupancyLevels/#{@ns}:OccupancyLevel/#{@ns}:OccupantQuantity"]
        @occupant_quantity = @base_xml.elements["#{@ns}:OccupancyLevels/#{@ns}:OccupancyLevel/#{@ns}:OccupantQuantity"].text
      else
        @occupant_quantity = nil
      end
    end

    # read building section other details
    def read_building_section_other_detail(building_occupancy_classification)
      if @base_xml.elements["#{@ns}:TypicalOccupantUsages"]
        @base_xml.elements.each("#{@ns}:TypicalOccupantUsages/#{@ns}:TypicalOccupantUsage") do |occ_usage|
          if occ_usage.elements["#{@ns}:TypicalOccupantUsageUnits"].text == 'Hours per week'
            @typical_occupant_usage_value_hours = occ_usage.elements["#{@ns}:TypicalOccupantUsageValue"].text
          elsif occ_usage.elements["#{@ns}:TypicalOccupantUsageUnits"].text == 'Weeks per year'
            @typical_occupant_usage_value_weeks = occ_usage.elements["#{@ns}:TypicalOccupantUsageValue"].text
          end
        end
      end

      if @base_xml.elements["#{@ns}:OccupancyLevels"]
        @base_xml.elements.each("#{@ns}:OccupancyLevels/#{@ns}:OccupancyLevel") do |occ_level|
          if occ_level.elements["#{@ns}:OccupantQuantityType"].text == 'Peak total occupants'
            @occupant_quantity = occ_level.elements["#{@ns}:OccupantQuantity"].text
          end
        end
      end

      # read floor_to_floor_height
      floor_to_floor_height_xml = @base_xml.elements["#{@ns}:FloorToFloorHeight"]
      if floor_to_floor_height_xml
        @floor_to_floor_height = floor_to_floor_height_xml.first.to_s.to_f
      end

      # read occupancy_classification
      occupancy_classification_xml = @base_xml.elements["#{@ns}:OccupancyClassification"]
      if !occupancy_classification_xml.nil?
        @occupancy_classification = occupancy_classification_xml.text
      else
        @occupancy_classification = building_occupancy_classification
      end

      if @occupancy_classification.nil?
        raise StandardError, 'Unable to set OccupancyClassification to nil'
      end
    end

    # read construction types
    def read_construction_types
      if @base_xml.elements["#{@ns}:Sides"]
        @base_xml.elements.each("#{@ns}:Sides/#{@ns}:Side/#{@ns}:DoorID") do |door|
          @door_ids.push(door.attributes['IDref'])
        end
        @base_xml.elements.each("#{@ns}:Sides/#{@ns}:Side/#{@ns}:WallID") do |wall|
          @wall_ids.push(wall.attributes['IDref'])
        end
        @base_xml.elements.each("#{@ns}:Sides/#{@ns}:Side/#{@ns}:WindowID") do |window|
          @window_ids.push(window.attributes['IDref'])
        end
      end
      if @base_xml.elements["#{@ns}:Roofs"]
        @base_xml.elements.each("#{@ns}:Roofs/#{@ns}:Roof/#{@ns}:RoofID") do |roof|
          @roof_ids.push(roof.attributes['IDref'])
        end
        @base_xml.elements.each("#{@ns}:Roofs/#{@ns}:Roof/#{@ns}:RoofID/#{@ns}:SkylightIDs/#{@ns}:SkylightID") do |skylight|
          @skylight_ids.push(skylight.attributes['IDref'])
        end
      end
      if @base_xml.elements["#{@ns}:ExteriorFloors"]
        @base_xml.elements.each("#{@ns}:ExteriorFloors/#{@ns}:ExteriorFloor/#{@ns}:ExteriorFloorID ") do |floor|
          @exterior_floor_ids.push(floor.attributes['IDref'])
        end
      end
      if @base_xml.elements["#{@ns}:Foundations"]
        @base_xml.elements.each("#{@ns}:Foundations/#{@ns}:Foundation/#{@ns}:FoundationID  ") do |foundation|
          @foundation_ids.push(foundation.attributes['IDref'])
        end
      end
    end

    # add principal hvac type
    def prepare_final_xml
      @base_xml.elements["#{@ns}:fraction_area"].text = @fraction_area
      @base_xml.elements["#{@ns}:OriginalOccupancyClassification"].text = @occupancy_classification_original if !@occupancy_classification_original.nil?

      @base_xml.elements["#{@ns}:TypicalOccupantUsages/#{@ns}:TypicalOccupantUsage/#{@ns}:TypicalOccupantUsageValue"].text = @typical_occupant_usage_value_hours if !@typical_occupant_usage_value_hours.nil?
      @base_xml.elements["#{@ns}:TypicalOccupantUsages/#{@ns}:TypicalOccupantUsage/#{@ns}:TypicalOccupantUsageValue"].text = @typical_occupant_usage_value_weeks if !@typical_occupant_usage_value_weeks.nil?
      @base_xml.elements["#{@ns}:OccupancyLevels/#{@ns}:OccupancyLevel/#{@ns}:OccupantQuantity"].text = @occupant_quantity if !@occupant_quantity.nil?

      prepare_final_xml_for_spatial_element
    end

    # set building and system type
    def set_bldg_and_system_type
      super(xget_text('OccupancyClassification'), @total_floor_area, @num_stories, false)
    end

    # get peak occupancy
    # @return [String]
    def get_peak_occupancy
      return @occupant_quantity
    end

    # get floor area of this building section
    # @return [Float]
    def get_floor_area
      return @total_floor_area
    end

    attr_reader :space_types_floor_area, :occupancy_classification, :typical_occupant_usage_value_weeks, :typical_occupant_usage_value_hours, :standards_building_type, :section_type, :id, :floor_to_floor_height, :base_xml
    attr_accessor :fraction_area
  end
end
