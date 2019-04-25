module OpenStudio
  module ModelArticulation
    class Building
      # an array that contains all the building subsections
      @building_subsections = []
      @gross_floor_area = null
      @heated_and_cooled_floor_area = null
      @footprint_floor_area = null
      @template = null
      @num_stories_above_grade = null
      @num_stories_below_grade = null
      @ns_to_ew_ratio = null
      @building_rotation = null
      @floor_height = null
      @wwr = null
      @buildElement = nil
      # initialize
      def initialize(build_element)
        # code to initialize
        build_element.elements.each("/#{@ns}:FloorAreas/#{@ns}:FloorArea") do |floor_area_element|
          floor_area = floor_area_element.elements["#{@ns}:FloorAreaValue"].text.to_f
          next if floor_area.nil?

          floor_area_type = floor_area_element.elements["#{@ns}:FloorAreaType"].text
          if floor_area_type == 'Gross'
            @gross_floor_area = floor_area
          elsif floor_area_type == 'Heated and Cooled'
            @heated_and_cooled_floor_area = floor_area
          elsif floor_area_type == 'Footprint'
            @footprint_floor_area = floor_area
          end
        end
      end

      # SHL- get the template (vintage)
      @template = nil

      built_year = @buildElement.elements["#{@ns}:YearOfConstruction"].text.to_f

      if @buildElement.elements["#{@ns}:YearOfLastMajorRemodel"]
        major_remodel_year = @buildElement.elements["#{@ns}:YearOfLastMajorRemodel"].text.to_f
        built_year = major_remodel_year if major_remodel_year > built_year
      end

      if built_year < 1978
        @template = "CBES Pre-1978"
      elsif built_year >= 1978 && built_year < 1992
        @template = "CBES T24 1978"
      elsif built_year >= 1992 && built_year < 2001
        @template = "CBES T24 1992"
      elsif built_year >= 2001 && built_year < 2005
        @template = "CBES T24 2001"
      elsif built_year >= 2005 && built_year < 2008
        @template = "CBES T24 2005"
      else
        @template = "CBES T24 2008"
      end


      if @buildElement.elements["#{@ns}:FloorsAboveGrade"]
        @num_stories_above_grade = @buildElement.elements["#{@ns}:FloorsAboveGrade"].text.to_f
        if @num_stories_above_grade == 0
          @num_stories_above_grade = 1.0
        end
      else
        @num_stories_above_grade = 1.0 # setDefaultValue
      end

      if @buildElement.elements["#{@ns}:FloorsBelowGrade"]
        @num_stories_below_grade = @buildElement.elements["#{@ns}:FloorsBelowGrade"].text.to_f
      else
        @num_stories_below_grade = 0.0 # setDefaultValue
      end

      if @buildElement.elements["#{@ns}:AspectRatio"]
        @ns_to_ew_ratio = @buildElement.elements["#{@ns}:AspectRatio"].text.to_f
      else
        @ns_to_ew_ratio = 0.0 # setDefaultValue
      end

      @building_rotation = 0.0 # setDefaultValue
      @floor_height = 0.0 # setDefaultValue in ft
      @wwr = 0.0 # setDefaultValue in fraction

      @buildElement.elements.each("#{@ns}:Subsections/#{@ns}:Subsection") do |subsection_element|
        floor_area = subsection_element.elements["#{@ns}:FloorAreas"].text.to_f
        next if floor_area.nil?
        @building_subsections.push(subsection_element)
      end

      # adding a subsection to this building
      def create_building
        # code to create a subsection
        #
        # if aspect ratio, story height or wwr have argument value of 0 then use smart building type defaults
        #
        # check that sum of fractions for b,c, and d is less than 1.0 (so something is left for primary building type)
        #
        # set building rotation
        #
        # init subsections
        #
        # set building name
        @building_subsections.each do |subsection|
          BuildingSubsection.new(subsection)
        end
      end
    end
  end
end
