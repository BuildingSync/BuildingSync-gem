module BuildingSync
  class BuildingSubsection
    type = null
    faction_area = null
    num_of_units = null
    @occupancy_type = null
    @bldg_type = null
    @system_type = null
    @bar_division_method = null
    @subsection_element = nil
    # initialize
    def initialize(subSectionElement)
      # code to initialize
      # floor areas
      set_floor_areas(subSectionElement)
      # based on the occupancy type set building type, system type and bar division method
      set_bldg_system_type_based_on_occupancy_type(subSectionElement)

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
        if @gross_floor_area > 0 && @gross_floor_area < 20000
          @bldg_type = 'SmallOffice'
          @system_type = 'PSZ-AC with gas coil heat'
        elsif @gross_floor_area >= 20000 && @gross_floor_area < 75000
          @bldg_type = 'MediumOffice'
          @system_type = 'PVAV with reheat'
        else
          raise "Office building size is beyond BuildingSync scope"
        end
      else
        raise "Building type '#{@occupancy_type}' is beyond BuildingSync scope"
      end

      raise "Subsection does not define gross floor area" if @gross_floor_area.nil?
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
    end
  end
end
