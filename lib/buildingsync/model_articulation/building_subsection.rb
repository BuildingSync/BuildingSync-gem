require_relative '../Helpers/os_lib_model_generation_bricr'
require 'openstudio-standards'
module BuildingSync
  class BuildingSubsection < SpecialElement

    include OsLib_ModelGenerationBRICR
    include OpenstudioStandards
    @bldg_type = nil
    @fraction_area = nil
    @num_of_units = nil
    @occupancy_type = nil
    @system_type = nil
    @bar_division_method = nil
    @standard = nil
    @space_types = {}
    @space_types_floor_area = {}

    # initialize
    def initialize(subSectionElement, standard_template, ns)
      @bldg_type = nil
      @subsection_element = nil
      @standard = nil
      @fraction_area = nil
      @space_types = {}
      @space_types_floor_area = {}
      # code to initialize
      read_xml(subSectionElement, standard_template, ns)
    end

    def read_xml(subSectionElement, standard_template, ns)
      # floor areas
      read_floor_areas(subSectionElement, ns)
      # based on the occupancy type set building type, system type and bar division method
      read_bldg_system_type_based_on_occupancy_type(subSectionElement, ns)

      @space_types = get_space_types_from_building_type(@bldg_type, standard_template, true)

      @subsection_element = subSectionElement

      # Make the standard applier
      @standard = Standard.build("#{standard_template}_#{@bldg_type}")
    end

    def read_bldg_system_type_based_on_occupancy_type(subSectionElement, nodeSap)
      @occupancy_type = subSectionElement.elements["#{nodeSap}:OccupancyClassification"].text
      if @occupancy_type == 'Retail'
        @bldg_type = 'RetailStandalone'
        @bar_division_method = 'Multiple Space Types - Individual Stories Sliced'
        @system_type = 'PSZ-AC with gas coil heat'
      elsif @occupancy_type == 'Office'
        @bar_division_method = 'Single Space Type - Core and Perimeter'
        if @total_floor_area > 0 && @total_floor_area < 20000
          @bldg_type = 'SmallOffice'
          @system_type = 'PSZ-AC with gas coil heat'
        elsif @total_floor_area >= 20000 && @total_floor_area < 75000
          @bldg_type = 'MediumOffice'
          @system_type = 'PVAV with reheat'
        else
          raise 'Office building size is beyond BuildingSync scope'
        end
      else
        raise "Building type '#{@occupancy_type}' is beyond BuildingSync scope"
      end
    end

    # create space types
    def create_space_types(model, total_bldg_floor_area)
      # create space types from subsection type
      puts "Info: Creating Space Types for #{@occupancy_type}."
      # mapping building_type name is needed for a few methods
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
          puts "Warning: Could not find color for #{@occupancy_type} #{space_type.name}"
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
    end
    attr_reader :bldg_type, :space_types_floor_area
    attr_accessor :fraction_area
  end
end
