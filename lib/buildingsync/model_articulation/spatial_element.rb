# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2019, Alliance for Sustainable Energy, LLC.
# BuildingSync(R), Copyright (c) 2015-2019, Alliance for Sustainable Energy, LLC.
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

module BuildingSync
  # base class for objects that will configure workflows based on building sync files
  class SpatialElement
    include OpenStudio
    def initialize
      @total_floor_area = nil
      @bldg_type = nil
      @system_type = nil
      @bar_division_method = nil
    end

    def read_floor_areas(build_element, parent_total_floor_area, ns)
      build_element.elements.each("#{ns}:FloorAreas/#{ns}:FloorArea") do |floor_area_element|
        floor_area = floor_area_element.elements["#{ns}:FloorAreaValue"].text.to_f
        next if floor_area.nil?

        floor_area_type = floor_area_element.elements["#{ns}:FloorAreaType"].text
        if floor_area_type == 'Gross'
          @total_floor_area = OpenStudio.convert(validate_positive_number_excluding_zero('gross_floor_area', floor_area), 'ft^2', 'm^2').get
        elsif floor_area_type == 'Heated and Cooled'
          @heated_and_cooled_floor_area = OpenStudio.convert(validate_positive_number_excluding_zero('@heated_and_cooled_floor_area', floor_area), 'ft^2', 'm^2').get
        elsif floor_area_type == 'Footprint'
          @footprint_floor_area = OpenStudio.convert(validate_positive_number_excluding_zero('@footprint_floor_area', floor_area), 'ft^2', 'm^2').get
        elsif floor_area_type == 'Conditioned'
          @conditioned_floor_area = OpenStudio.convert(validate_positive_number_excluding_zero('@@conditioned_floor_area', floor_area), 'ft^2', 'm^2').get
        else
          OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.SpatialElement.generate_baseline_osm', "Unsupported floor area type found: #{floor_area_type}")
        end

        if @total_floor_area.nil? && !@conditioned_floor_area.nil?
          @total_floor_area = @conditioned_floor_area
        else
          if @total_floor_area.nil? && !@heated_and_cooled_floor_area.nil?
            @total_floor_area = @heated_and_cooled_floor_area
          end
        end

        raise 'Spatial element does not define gross floor area' if @total_floor_area.nil? && parent_total_floor_area.nil?
      end
      if @total_floor_area.nil?
        return parent_total_floor_area
      else
        return @total_floor_area
      end
    end

    def read_occupancy_type(xml_element, occupancy_type, ns)
      occ_element = xml_element.elements["#{ns}:OccupancyClassification"]
      if !occ_element.nil?
        return occ_element.text
      else
        return occupancy_type
      end
    end

    def set_bldg_and_system_type(occupancy_type, total_floor_area, raise_exception)
      ' DOE Prototype building types:from openstudio-standards/lib/openstudio-standards/prototypes/common/prototype_metaprogramming.rb'
      ' SmallOffice, MediumOffice, LargeOffice, RetailStandalone, RetailStripmall, PrimarySchool, SecondarySchool, Outpatient'
      ' Hospital, SmallHotel, LargeHotel, QuickServiceRestaurant, FullServiceRestaurant, MidriseApartment, HighriseApartment, Warehouse'
      if !occupancy_type.nil? && !total_floor_area.nil?
        if occupancy_type == 'Retail'
          @bldg_type = 'RetailStandalone'
          @bar_division_method = 'Multiple Space Types - Individual Stories Sliced'
          @system_type = 'PSZ-AC with gas coil heat'
        elsif occupancy_type == 'Office'
          @bar_division_method = 'Single Space Type - Core and Perimeter'
          if (total_floor_area > 0) && (total_floor_area < 20000)
            @bldg_type = 'SmallOffice'
            @system_type = 'PSZ-AC with gas coil heat'
          elsif total_floor_area >= 20000 && total_floor_area < 75000
            @bldg_type = 'MediumOffice'
            @system_type = 'PVAV with reheat'
          else
            @bldg_type = 'LargeOffice'
            @system_type = 'VAV with reheat'
          end
        elsif occupancy_type == 'StripMall'
          @bldg_type = 'RetailStripmall'
          @bar_division_method = 'Single Space Type - Core and Perimeter'
          @system_type = 'tbd'
        elsif occupancy_type == 'PrimarySchool'
          @bldg_type = occupancy_type
          @bar_division_method = 'Single Space Type - Core and Perimeter'
          @system_type = 'tbd'
        elsif occupancy_type == 'SecondarySchool'
          @bldg_type = occupancy_type
          @bar_division_method = 'Single Space Type - Core and Perimeter'
          @system_type = 'tbd'
        elsif occupancy_type == 'Outpatient'
          @bldg_type = occupancy_type
          @bar_division_method = 'Single Space Type - Core and Perimeter'
          @system_type = 'tbd'
        elsif occupancy_type == 'Hospital'
          @bldg_type = occupancy_type
          @bar_division_method = 'Single Space Type - Core and Perimeter'
          @system_type = 'tbd'
        elsif occupancy_type == 'SmallHotel'
          @bldg_type = occupancy_type
          @bar_division_method = 'Single Space Type - Core and Perimeter'
          @system_type = 'tbd'
        elsif occupancy_type == 'LargeHotel'
          @bldg_type = occupancy_type
          @bar_division_method = 'Single Space Type - Core and Perimeter'
          @system_type = 'tbd'
        elsif occupancy_type == 'QuickServiceRestaurant'
          @bldg_type = occupancy_type
          @bar_division_method = 'Single Space Type - Core and Perimeter'
          @system_type = 'tbd'
        elsif occupancy_type == 'FullServiceRestaurant'
          @bldg_type = occupancy_type
          @bar_division_method = 'Single Space Type - Core and Perimeter'
          @system_type = 'tbd'
        elsif occupancy_type == 'MidriseApartment'
          @bldg_type = occupancy_type
          @bar_division_method = 'Single Space Type - Core and Perimeter'
          @system_type = 'tbd'
        elsif occupancy_type == 'HighriseApartment'
          @bldg_type = occupancy_type
          @bar_division_method = 'Single Space Type - Core and Perimeter'
          @system_type = 'tbd'
        elsif occupancy_type == 'Warehouse'
          @bldg_type = occupancy_type
          @bar_division_method = 'Single Space Type - Core and Perimeter'
          @system_type = 'tbd'
        elsif occupancy_type == 'SuperMarket'
          @bldg_type = occupancy_type
          @bar_division_method = 'Single Space Type - Core and Perimeter'
          @system_type = 'tbd'
        else
          raise "Building type '#{occupancy_type}' is beyond BuildingSync scope"
        end
      elsif raise_exception
        if occupancy_type.nil? && !total_floor_area.nil?
          raise "Building type '#{occupancy_type}' is nil"
        elsif !occupancy_type.nil? && total_floor_area.nil?
          raise "Building total floor area '#{total_floor_area}' is nil"
        end
      end
    end

    def validate_positive_number_excluding_zero(name, value)
      if value <= 0
        puts "Error: parameter #{name} must be positive and not zero."
      end
      return value
    end

    def validate_positive_number_including_zero(name, value)
      if value < 0
        puts "Error: parameter #{name} must be positive or zero."
      end
      return value
    end

    # create space types
    def create_space_types(model, total_bldg_floor_area, standard_template, bldg_type)
      # create space types from subsection type
      # mapping building_type name is needed for a few methods
      if @standard.nil?
        @standard = Standard.build("#{standard_template}_#{bldg_type}")
      end
      building_type = @standard.model_get_lookup_name(@occupancy_type)
      # create space_type_map from array
      sum_of_ratios = 0.0
      @space_types.each do |space_type_name, hash|
        # create space type
        space_type = OpenStudio::Model::SpaceType.new(model)
        space_type.setStandardsBuildingType(@occupancy_type)
        space_type.setStandardsSpaceType(space_type_name)
        space_type.setName("#{@occupancy_type} #{space_type_name}")

        # set color
        test = @standard.space_type_apply_rendering_color(space_type) # this uses openstudio-standards
        if !test
          OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Building.generate_baseline_osm',"Warning: Could not find color for #{space_type.name}")
        end
        # extend hash to hold new space type object
        hash[:space_type] = space_type

        # add to sum_of_ratios counter for adjustment multiplier
        sum_of_ratios += hash[:ratio]
      end

      # store multiplier needed to adjust sum of ratios to equal 1.0
      @ratio_adjustment_multiplier = 1.0 / sum_of_ratios

      @space_types.each do |space_type_name, hash|
        ratio_of_bldg_total = hash[:ratio] * @ratio_adjustment_multiplier * fraction_area
        final_floor_area = ratio_of_bldg_total * total_bldg_floor_area # I think I can just pass ratio but passing in area is cleaner
        @space_types_floor_area[hash[:space_type]] = {floor_area: final_floor_area }
      end
      return @space_types_floor_area
    end

    def validate_fraction; end
    attr_reader :total_floor_area, :bldg_type, :system_type
  end
end
