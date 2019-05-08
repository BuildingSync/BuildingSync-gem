require_relative '../Helpers/os_lib_model_generation_bricr'
require 'openstudio-standards'
module BuildingSync
  class BuildingSubsection < SpecialElement
    include OsLib_ModelGenerationBRICR
    include OpenstudioStandards

    # initialize
    def initialize(subSectionElement, standard_template, occType, ns)
      @subsection_element = nil
      @standard = nil
      @fraction_area = nil
      @bldg_type = {}
      @space_types = {}
      @space_types_floor_area = {}
      # code to initialize
      read_xml(subSectionElement, standard_template, occType, ns)
    end

    def read_xml(subSectionElement, standard_template, occType, ns)
      # floor areas
      read_floor_areas(subSectionElement, nil, ns)
      # based on the occupancy type set building type, system type and bar division method
      read_bldg_system_type_based_on_occupancy_type(subSectionElement, occType, ns)

      @space_types = get_space_types_from_building_type(@bldg_type, standard_template, true)

      @subsection_element = subSectionElement

      # Make the standard applier
      @standard = Standard.build("#{standard_template}_#{@bldg_type}")
    end

    def read_bldg_system_type_based_on_occupancy_type(subSectionElement, occType, ns)
      @occupancy_type = read_occupancy_type(subSectionElement, occType, ns)
      set_bldg_and_system_type(@occupancy_type, @total_floor_area)
    end

    # create space types
    def create_space_types(model, total_bldg_floor_area)
      # create space types from subsection type
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
    end
    attr_reader :bldg_type, :space_types_floor_area
    attr_accessor :fraction_area
  end
end
