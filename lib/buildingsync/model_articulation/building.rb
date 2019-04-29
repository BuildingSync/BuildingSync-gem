module BuildingSync
  class Building
    # an array that contains all the building subsections
    @building_subsections = []
    @gross_floor_area = null
    @heated_and_cooled_floor_area = null
    @footprint_floor_area = null
    @standard_template = null
    @num_stories_above_grade = null
    @num_stories_below_grade = null
    @ns_to_ew_ratio = null

    @building_rotation = 0.0 # setDefaultValue
    @floor_height = 0.0 # setDefaultValue in ft
    @wwr = 0.0 # setDefaultValue in fraction

    # initialize
    def initialize(build_element)
      # code to initialize
      # floor areas
      set_floor_areas(build_element)
      # standard template
      set_standard_template_based_on_year(build_element)
      # deal with stories above and below grade
      set_stories_above_and_below_grade(build_element)
      # aspect ratio
      set_aspect_ratio(build_element)

      build_element.elements.each("#{@ns}:Subsections/#{@ns}:Subsection") do |subsection_element|
        floor_area = subsection_element.elements["#{@ns}:FloorAreas"].text.to_f
        next if floor_area.nil?
        @building_subsections.push(BuildingSubsection.new(subsection_element, @standard_template))
      end

      # need to set those defaults after initializing the subsections
      set_building_form_defaults
    end

    def set_standard_template_based_on_year(build_element)
      built_year = build_element.elements["#{@ns}:YearOfConstruction"].text.to_f

      if build_element.elements["#{@ns}:YearOfLastMajorRemodel"]
        major_remodel_year = build_element.elements["#{@ns}:YearOfLastMajorRemodel"].text.to_f
        built_year = major_remodel_year if major_remodel_year > built_year
      end

      if built_year < 1978
        @standard_template = "CBES Pre-1978"
      elsif built_year >= 1978 && built_year < 1992
        @standard_template = "CBES T24 1978"
      elsif built_year >= 1992 && built_year < 2001
        @standard_template = "CBES T24 1992"
      elsif built_year >= 2001 && built_year < 2005
        @standard_template = "CBES T24 2001"
      elsif built_year >= 2005 && built_year < 2008
        @standard_template = "CBES T24 2005"
      else
        @standard_template = "CBES T24 2008"
      end
    end

    def set_stories_above_and_below_grade(build_element)
      if build_element.elements["#{@ns}:FloorsAboveGrade"]
        @num_stories_above_grade = build_element.elements["#{@ns}:FloorsAboveGrade"].text.to_f
        if @num_stories_above_grade == 0
          @num_stories_above_grade = 1.0
        end
      else
        @num_stories_above_grade = 1.0 # setDefaultValue
      end

      if build_element.elements["#{@ns}:FloorsBelowGrade"]
        @num_stories_below_grade = build_element.elements["#{@ns}:FloorsBelowGrade"].text.to_f
      else
        @num_stories_below_grade = 0.0 # setDefaultValue
      end
    end

    def set_aspect_ratio(build_element)
      if build_element.elements["#{@ns}:AspectRatio"]
        @ns_to_ew_ratio = build_element.elements["#{@ns}:AspectRatio"].text.to_f
      else
        @ns_to_ew_ratio = 0.0 # setDefaultValue
      end
    end

    def set_building_form_defaults
      # if aspect ratio, story height or wwr have argument value of 0 then use smart building type defaults
      building_form_defaults = building_form_defaults(@building_subsections[0].bldg_type)
      if @ns_to_ew_ratio == 0.0
        @ns_to_ew_ratio = building_form_defaults[:aspect_ratio]
        puts "Warning: 0.0 value for aspect ratio will be replaced with smart default for #{@building_subsections[0].bldg_type} of #{building_form_defaults[:aspect_ratio]}."
      end
      if @floor_height == 0.0
        @floor_height = building_form_defaults[:typical_story]
        puts "Warning: 0.0 value for floor height will be replaced with smart default for #{@building_subsections[0].bldg_type} of #{building_form_defaults[:typical_story]}."
      end
      # because of this can't set wwr to 0.0. If that is desired then we can change this to check for 1.0 instead of 0.0
      if @wwr == 0.0
        @wwr = building_form_defaults[:wwr]
        puts "Warning: 0.0 value for window to wall ratio will be replaced with smart default for #{@building_subsections[0].bldg_type} of #{building_form_defaults[:wwr]}."
      end
    end

    def check_building_faction
      # check that sum of fractions for b,c, and d is less than 1.0 (so something is left for primary building type)
      building_fraction = 1.0
      @building_subsections.each do |subsection|
        next if subsection.fraction.nil?
        building_fraction -= subsection.fraction
      end
      if building_fraction <= 0.0
        puts 'ERROR: Primary Building Type fraction of floor area must be greater than 0. Please lower one or more of the fractions for Building Type B-D.'
        return false
      end
      true
    end

    def create_space_types
      @building_subsections.each.create_space_types
    end
  end
end
