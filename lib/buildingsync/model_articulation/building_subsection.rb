module BuildingSync
  class BuildingSubsection
    type = null
    faction_area = null
    num_of_units = null
    @occupancy_type = null
    @bldg_type = null
    @system_type = null
    @space_types = null
    @bar_division_method = null
    @subsection_element = nil

    # initialize
    def initialize(subSectionElement, standard_template)
      # code to initialize
      # floor areas
      set_floor_areas(subSectionElement)
      # based on the occupancy type set building type, system type and bar division method
      set_bldg_system_type_based_on_occupancy_type(subSectionElement)

      @space_types = get_space_types_from_building_type(@bldg_type, standard_template, true)

      @subsection_element = subSectionElement
    end

    def set_bldg_system_type_based_on_occupancy_type(subSectionElement)
      @occupancy_type = subSectionElement.elements["#{@ns}:OccupancyClassification"].text
      if @occupancy_type == 'Retail'
        @bldg_type = 'RetailStandalone'
        @bar_division_method = 'Multiple Space Types - Individual Stories Sliced'
        @system_type = 'PSZ-AC with gas coil heat'
      elsif @occupancy_type  == 'Office'
        @bar_division_method = 'Single Space Type - Core and Perimeter'
        if @total_floor_area > 0 && @total_floor_area < 20000
          @bldg_type = 'SmallOffice'
          @system_type = 'PSZ-AC with gas coil heat'
        elsif @total_floor_area >= 20000 && @total_floor_area < 75000
          @bldg_type = 'MediumOffice'
          @system_type = 'PVAV with reheat'
        else
          raise "Office building size is beyond BuildingSync scope"
        end
      else
        raise "Building type '#{@occupancy_type}' is beyond BuildingSync scope"
      end

      raise "Subsection does not define gross floor area" if @total_floor_area.nil?
    end

    # create geometry
    def create_geometry
      # need to do some parameter checking
      #
      #
      # creating the geometry
      #
      # deal with party walls. etc
      #
      # create bar
      #
      # check expected floor areas against actual
    end

    # create space types
    def create_space_types
      # create space types from subsection type
      puts "Info: Creating Space Types for #{@occupancy_type}."
      # mapping building_type name is needed for a few methods
      building_type = standard.model_get_lookup_name(@occupancy_type)
      # create space_type_map from array
      sum_of_ratios = 0.0
      @space_types.each do |space_type_name, hash|
        # create space type
        space_type = OpenStudio::Model::SpaceType.new(model)
        space_type.setStandardsBuildingType(@occupancy_type)
        space_type.setStandardsSpaceType(space_type_name)
        space_type.setName("#{@occupancy_type} #{space_type_name}")

        # set color
        test = standard.space_type_apply_rendering_color(space_type) # this uses openstudio-standards
        if !test
          puts "Warning: Could not find color for #{args['template']} #{space_type.name}"
        end
        # extend hash to hold new space type object
        hash[:space_type] = space_type

        # add to sum_of_ratios counter for adjustment multiplier
        sum_of_ratios += hash[:ratio]
      end

      # store multiplier needed to adjust sum of ratios to equal 1.0
      @ratio_adjustment_multiplier = 1.0 / sum_of_ratios

      @space_types.each do |space_type, hash|
        ratio_of_bldg_total = hash[:ratio] * @ratio_adjustment_multiplier * @frac_bldg_area
        final_floor_area = ratio_of_bldg_total * total_bldg_floor_area_si # I think I can just pass ratio but passing in area is cleaner
        space_types_hash[space_type] = { floor_area: final_floor_area }
      end
    end
  end
end
