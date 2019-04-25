module OpenStudio
  module ModelArticulation
    class BuildingSubsection
      type = null
      faction_area = null
      num_of_units = null
      @subsection_element=nil
      # initialize
      def initialize(subSectionElement)
        # code to initialize
        @subsection_element = subSectionElement
      end

      subsection = {'gross_floor_area' => nil, 'heated_and_cooled_floor_area' => nil, 'footprint_floor_area' => nil, 'occupancy_type' => nil, 'bldg_type' => nil, 'bar_division_method' => nil, 'system_type' => nil}

      @subsection_element.elements.each("#{@ns}:FloorAreas/#{@ns}:FloorArea") do |floor_area_element|
        floor_area = floor_area_element.elements["#{@ns}:FloorAreaValue"].text.to_f
        next if floor_area.nil?

        floor_area_type = floor_area_element.elements["#{@ns}:FloorAreaType"].text
        if floor_area_type == 'Gross'
          subsection['gross_floor_area'] = floor_area
        elsif floor_area_type == 'Heated and Cooled'
          subsection['heated_and_cooled_floor_area'] = floor_area
        elsif floor_area_type == 'Footprint'
          subsection['footprint_floor_area'] = floor_area
        end
      end

      #puts @subsection_element
      subsection['occupancy_type'] = @subsection_element.elements["#{@ns}:OccupancyClassification"].text
      if subsection['occupancy_type'] == 'Retail'
        subsection['bldg_type'] = 'RetailStandalone'
        subsection['bar_division_method'] = 'Multiple Space Types - Individual Stories Sliced'
        subsection['system_type'] = 'PSZ-AC with gas coil heat'
      elsif subsection['occupancy_type']  == 'Office'
        subsection['bar_division_method'] = 'Single Space Type - Core and Perimeter'
        if subsection['gross_floor_area'] > 0 && subsection['gross_floor_area'] < 20000
          subsection['bldg_type'] = 'SmallOffice'
          subsection['system_type'] = 'PSZ-AC with gas coil heat'
        elsif subsection['gross_floor_area'] >= 20000 && subsection['gross_floor_area'] < 75000
          subsection['bldg_type'] = 'MediumOffice'
          subsection['system_type'] = 'PVAV with reheat'
        else
          raise "Office building size is beyond BuildingSync scope"
        end
      else
        raise "Building type '#{subsection['occupancy_type']}' is beyond BuildingSync scope"
      end

      raise "Subsection does not define gross floor area" if subsection['gross_floor_area'].nil?

      # create geometry
      def create_geoemtry
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
end

