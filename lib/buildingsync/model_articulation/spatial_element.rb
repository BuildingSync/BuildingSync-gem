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
require 'openstudio'
require 'fileutils'
require 'json'
require 'openstudio/extension/core/os_lib_model_generation'

require 'buildingsync/helpers/helper'
require 'buildingsync/helpers/xml_get_set'

module BuildingSync
  # base class for objects that will configure workflows based on building sync files
  class SpatialElement
    include OsLib_ModelGeneration
    include BuildingSync::Helper
    include BuildingSync::XmlGetSet
    # initialize SpatialElement class
    # @param base_xml [REXML::Element] an element corresponding to a spatial element,
    #   either an auc:Site, auc:Building, auc:Section
    # @param ns [String] namespace, likely 'auc'
    def initialize(base_xml, ns)
      @base_xml = base_xml
      @ns = ns

      @total_floor_area = nil
      @standards_building_type = nil
      @system_type = nil
      @bar_division_method = nil
      @space_types = {}
      @fraction_area = nil
      @space_types_floor_area = nil
      @conditioned_floor_area_heated_only = nil
      @conditioned_floor_area_cooled_only = nil
      @conditioned_floor_area_heated_cooled = 0
      @custom_conditioned_above_grade_floor_area = nil
      @custom_conditioned_below_grade_floor_area = nil

      @user_defined_fields = REXML::Element.new("#{@ns}:UserDefinedFields")
    end

    # read floor areas
    # @param parent_total_floor_area [Float]
    def read_floor_areas(parent_total_floor_area)
      @base_xml.elements.each("#{@ns}:FloorAreas/#{@ns}:FloorArea") do |floor_area_element|
        next if !floor_area_element.elements["#{@ns}:FloorAreaValue"]
        floor_area = floor_area_element.elements["#{@ns}:FloorAreaValue"].text.to_f
        next if floor_area.nil?

        floor_area_type = floor_area_element.elements["#{@ns}:FloorAreaType"].text
        if floor_area_type == 'Gross'
          @total_floor_area = OpenStudio.convert(validate_positive_number_excluding_zero('gross_floor_area', floor_area), 'ft^2', 'm^2').get
        elsif floor_area_type == 'Footprint'
          @footprint_floor_area = OpenStudio.convert(validate_positive_number_excluding_zero('@footprint_floor_area', floor_area), 'ft^2', 'm^2').get
        elsif floor_area_type == 'Conditioned' || floor_area_type == 'Common' || floor_area_type == 'Heated and Cooled'
          @conditioned_floor_area_heated_cooled += OpenStudio.convert(validate_positive_number_excluding_zero('@conditioned_floor_area_heated_cooled', floor_area), 'ft^2', 'm^2').get
        elsif floor_area_type == 'Heated Only'
          @conditioned_floor_area_heated_only = OpenStudio.convert(validate_positive_number_excluding_zero('@heated_only_floor_area', floor_area), 'ft^2', 'm^2').get
        elsif floor_area_type == 'Cooled Only'
          @conditioned_floor_area_cooled_only = OpenStudio.convert(validate_positive_number_excluding_zero('@cooled_only_floor_area', floor_area), 'ft^2', 'm^2').get
        elsif floor_area_type == 'Custom'
          if floor_area_element.elements["#{@ns}:FloorAreaCustomName"].text == 'Conditioned above grade'
            @custom_conditioned_above_grade_floor_area = OpenStudio.convert(validate_positive_number_excluding_zero('@custom_conditioned_above_grade_floor_area', floor_area), 'ft^2', 'm^2').get
          elsif floor_area_element.elements["#{@ns}:FloorAreaCustomName"].text == 'Conditioned below grade'
            @custom_conditioned_below_grade_floor_area = OpenStudio.convert(validate_positive_number_excluding_zero('@custom_conditioned_below_grade_floor_area', floor_area), 'ft^2', 'm^2').get
          end
        else
          OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.SpatialElement.generate_baseline_osm', "Unsupported floor area type found: #{floor_area_type}")
        end
      end

      if @total_floor_area.nil? || @total_floor_area == 0
        # if the total floor area is null, we try to calculate the total area, from various conditioned areas
        running_floor_area = 0
        if !@conditioned_floor_area_cooled_only.nil? && @conditioned_floor_area_cooled_only > 0
          running_floor_area += @conditioned_floor_area_cooled_only
        end
        if !@conditioned_floor_area_heated_only.nil? && @conditioned_floor_area_heated_only > 0
          running_floor_area += @conditioned_floor_area_heated_only
        end
        if !@conditioned_floor_area_heated_cooled.nil? && @conditioned_floor_area_heated_cooled > 0
          running_floor_area += @conditioned_floor_area_heated_cooled
        end
        if running_floor_area > 0
          @total_floor_area = running_floor_area
        else
          # if the conditions floor areas are null, we look at the conditioned above and below grade areas
          if !@custom_conditioned_above_grade_floor_area.nil? && @custom_conditioned_above_grade_floor_area > 0
            running_floor_area += @custom_conditioned_above_grade_floor_area
          end
          if !@custom_conditioned_below_grade_floor_area.nil? && @custom_conditioned_below_grade_floor_area > 0
            running_floor_area += @custom_conditioned_below_grade_floor_area
          end
          if running_floor_area > 0
            @total_floor_area = running_floor_area
          end
        end
      end

      # if we did not find any area we get the parent one
      if @total_floor_area.nil? || @total_floor_area == 0
        return parent_total_floor_area
      else
        return @total_floor_area
      end
    end

    # set building and system type
    # @param occupancy_classification [String]
    # @param total_floor_area [Float]
    # @param total_number_floors [Integer]
    # @param raise_exception [Boolean]
    def set_bldg_and_system_type(occupancy_classification, total_floor_area, total_number_floors, raise_exception)
      # DOE Prototype building types:from openstudio-standards/lib/openstudio-standards/prototypes/common/prototype_metaprogramming.rb
      # SmallOffice, MediumOffice, LargeOffice, RetailStandalone, RetailStripmall, PrimarySchool, SecondarySchool, Outpatient
      # Hospital, SmallHotel, LargeHotel, QuickServiceRestaurant, FullServiceRestaurant, MidriseApartment, HighriseApartment, Warehouse

      if !occupancy_classification.nil? && !total_floor_area.nil?

        building_and_system_types = eval(File.read(BUILDING_AND_SYSTEMS_FILE_PATH))

        process_bldg_and_system_type(building_and_system_types, occupancy_classification, total_floor_area, total_number_floors)

        if @standards_building_type == ''
          raise "Building type '#{occupancy_classification}' is beyond BuildingSync scope"
        end
      elsif raise_exception
        if occupancy_classification.nil? && !total_floor_area.nil?
          raise "ID: #{xget_id} occupancy classification '#{occupancy_classification}' is nil"
        elsif !occupancy_classification.nil? && total_floor_area.nil?
          raise "ID: #{xget_id} Building total floor area '#{total_floor_area}' is nil"
        end
      end
    end

    # gets the standards occupancy type from the building type or the potential overwrite occupancy type
    # @param occ_type [Hash]
    # @return [Boolean]
    def sets_occupancy_bldg_system_types(occ_type)
      @standards_building_type = occ_type[:standards_building_type]
      @bar_division_method = occ_type[:bar_division_method]
      @system_type = occ_type[:system_type]
      OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.SpatialElement.sets_occupancy_bldg_system_types', "Element ID: #{xget_id} @standards_building_type #{@standards_building_type}, @bar_division_method #{@bar_division_method} and @system_type: #{@system_type}")
      return true
    end

    # Determine the standards_building_type, bar_division_method, and system_type given:
    # - occupancy_classification, total_floor_area, total_number_floors
    # @param building_and_system_types [Hash] a read in of the building_and_system_types.json file
    # @param occupancy_classification [String] value of OccupancyClassification element
    # @param total_floor_area [Float]
    # @param total_number_floors [Integer]
    # @return [Boolean]
    def process_bldg_and_system_type(building_and_system_types, occupancy_classification, total_floor_area, total_number_floors)
      OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.SpatialElement.process_bldg_and_system_type', "Element ID: #{xget_id} started with occupancy_classification #{occupancy_classification} and total floor area: #{total_floor_area}")
      puts "Element ID: #{xget_id} started with occupancy_classification #{occupancy_classification} and total floor area: #{total_floor_area}"

      # if building_and_system_types doesn't contain occupancy_classification, there's nothing we can do.
      occ_types = building_and_system_types[:"#{occupancy_classification}"]
      if occ_types.nil?
        raise "BuildingSync Occupancy type #{occupancy_classification} is not available in the building_and_system_types.json dictionary"
      end

      # if theres only one, we chose it indiscriminately
      # TODO: idk if we should do this but its what the tests want
      if occ_types.length == 1
        return sets_occupancy_bldg_system_types(occ_types[0])
      end

      # Try on each occ_type in the occupancy_classification for size
      occ_types.each do |occ_type|
        # if occ_type has a specified floor area range, see if it matches up
        if occ_type[:min_floor_area] || occ_type[:max_floor_area]
          min_floor_area = occ_type[:min_floor_area].nil? ?
            nil :
            OpenStudio.convert(occ_type[:min_floor_area].to_f, 'ft^2', 'm^2').get
          max_floor_area = occ_type[:max_floor_area].nil? ?
            nil :
            OpenStudio.convert(occ_type[:max_floor_area].to_f, 'ft^2', 'm^2').get

          too_small = min_floor_area && total_floor_area < min_floor_area
          too_big = max_floor_area && total_floor_area >= max_floor_area
          if !too_big && !too_small
            puts "selected the following standards_building_type: #{occ_type[:standards_building_type]}"
            return sets_occupancy_bldg_system_types(occ_type)
          end

        # else, if occ_type a specified floor number range, see if it matches up
        elsif occ_type[:min_number_floors] || occ_type[:max_number_floors]
          min_number_floors = occ_type[:min_number_floors].nil? ? nil : occ_type[:min_number_floors].to_i
          max_number_floors = occ_type[:max_number_floors].nil? ? nil : occ_type[:max_number_floors].to_i

          too_small = min_number_floors && total_number_floors < min_number_floors
          too_big = max_number_floors && total_number_floors >= max_number_floors
          if !too_big && !too_small
            puts "selected the following standards_building_type: #{occ_type[:standards_building_type]}"
            return sets_occupancy_bldg_system_types(occ_type)
          end
        end
      end

      # no occ_type fit! We must give up
      return false
    end

    # validate positive number excluding zero
    # @param name [String]
    # @param value [Float]
    # @return float
    def validate_positive_number_excluding_zero(name, value)
      puts "Error: parameter #{name} must be positive and not zero." if value <= 0
      return value
    end

    # validate positive number including zero
    # @param name [String]
    # @param value [Float]
    # @return float
    def validate_positive_number_including_zero(name, value)
      puts "Error: parameter #{name} must be positive or zero." if value < 0
      return value
    end

    # create space types
    # @param model [OpenStudio::Model]
    # @param total_bldg_floor_area [Float]
    # @param total_number_floors [Integer]
    # @param standard_template [String]
    # @param open_studio_standard [Standard]
    # @return hash
    def create_space_types(model, total_bldg_floor_area, total_number_floors, standard_template, open_studio_standard)
      # create space types from section type
      # mapping lookup_name name is needed for a few methods
      set_bldg_and_system_type(xget_text('OccupancyClassification'), total_bldg_floor_area, total_number_floors, false) if @standards_building_type.nil?
      if open_studio_standard.nil?
        begin
          open_studio_standard = Standard.build("#{standard_template}_#{@standards_building_type}")
        rescue StandardError => e
          # if the combination of standard type and bldg type fails we try the standard type alone.
          puts "could not find open studio standard for template #{standard_template} and bldg type: #{@standards_building_type}, trying the standard type alone"
          open_studio_standard = Standard.build(standard_template)
          raise(e)
        end
      end

      @space_types = get_space_types_from_building_type(@standards_building_type, standard_template, true)
      puts "BuildingSync.SpatialElement.create_space_types - Space types: #{@space_types} selected for building type: #{@standards_building_type} and standard template: #{standard_template}"
      # create space_type_map from array
      sum_of_ratios = 0.0

      @space_types.each do |space_type_name, hash|
        # create space type
        space_type = OpenStudio::Model::SpaceType.new(model)
        space_type.setStandardsBuildingType(@standards_building_type)
        space_type.setStandardsSpaceType(space_type_name)
        space_type.setName("#{@standards_building_type} #{space_type_name}")

        # set color
        test = open_studio_standard.space_type_apply_rendering_color(space_type) # this uses openstudio-standards
        OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.SpatialElement.create_space_types', "Warning: Could not find color for #{space_type.name}") if !test
        # extend hash to hold new space type object
        hash[:space_type] = space_type

        # add to sum_of_ratios counter for adjustment multiplier
        sum_of_ratios += hash[:ratio]
      end

      # store multiplier needed to adjust sum of ratios to equal 1.0
      @ratio_adjustment_multiplier = 1.0 / sum_of_ratios

      @space_types_floor_area = {}
      @space_types.each do |space_type_name, hash|
        ratio_of_bldg_total = hash[:ratio] * @ratio_adjustment_multiplier * @fraction_area
        final_floor_area = ratio_of_bldg_total * total_bldg_floor_area # I think I can just pass ratio but passing in area is cleaner
        @space_types_floor_area[hash[:space_type]] = { floor_area: final_floor_area }
      end
      puts 'BuildingSync.SpatialElement.create_space_types'
      return @space_types_floor_area
    end

    # add user defined field to xml file
    # @param field_name [String]
    # @param field_value [String]
    def add_user_defined_field_to_xml_file(field_name, field_value)
      user_defined_field = REXML::Element.new("#{@ns}:UserDefinedField")
      field_name_element = REXML::Element.new("#{@ns}:FieldName")
      field_value_element = REXML::Element.new("#{@ns}:FieldValue")

      if !field_value.nil?
        @user_defined_fields.add_element(user_defined_field)
        user_defined_field.add_element(field_name_element)
        user_defined_field.add_element(field_value_element)

        field_name_element.text = field_name
        field_value_element.text = field_value
      end
    end

    # write parameters to xml for spatial element
    def prepare_final_xml_for_spatial_element
      add_user_defined_field_to_xml_file('StandardsBuildingType', @standards_building_type)
      add_user_defined_field_to_xml_file('SystemType', @system_type)
      add_user_defined_field_to_xml_file('BarDivisionMethod', @bar_division_method)
      add_user_defined_field_to_xml_file('FractionArea', @fraction_area)
      add_user_defined_field_to_xml_file('SpaceTypesFloorArea', @space_types_floor_area)
      add_user_defined_field_to_xml_file('TotalFloorArea(m^2)', @total_floor_area)
      add_user_defined_field_to_xml_file('ConditionedFloorArea(m^2)', @conditioned_floor_area_heated_cooled) if !@conditioned_floor_area_heated_cooled.nil?
      add_user_defined_field_to_xml_file('HeatedFloorArea(m^2)', @conditioned_floor_area_heated_only) if !@conditioned_floor_area_heated_only.nil?
      add_user_defined_field_to_xml_file('CooledFloorArea(m^2)', @conditioned_floor_area_cooled_only) if !@conditioned_floor_area_cooled_only.nil?
      add_user_defined_field_to_xml_file('ConditionedAboveGradeFloorArea(m^2)', @custom_conditioned_above_grade_floor_area) if !@custom_conditioned_above_grade_floor_area.nil?
      add_user_defined_field_to_xml_file('ConditionedBelowGradeFloorArea(m^2)', @custom_conditioned_below_grade_floor_area) if !@custom_conditioned_below_grade_floor_area.nil?

      @base_xml.add_element(@user_defined_fields)
    end

    attr_reader :total_floor_area, :standards_building_type, :system_type, :space_types
  end
end
