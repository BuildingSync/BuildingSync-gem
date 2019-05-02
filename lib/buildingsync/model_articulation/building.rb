require_relative 'building_subsection'
module BuildingSync
  class Building < SpecialElement
    include OsLib_ModelGenerationBRICR
    # an array that contains all the building subsections
    @building_subsections = []
    # @total_floor_area = nil # ft2 -> m2 -- also gross_floor_area
    @heated_and_cooled_floor_area = nil
    @footprint_floor_area = nil
    @num_stories_above_grade = nil
    @num_stories_below_grade = nil
    @ns_to_ew_ratio = nil

    @building_rotation = 0.0 # setDefaultValue
    @floor_height = 0.0 # ft -> m -- setDefaultValue in ft
    @wwr = 0.0 # setDefaultValue in fraction
    @name = nil

    # initialize
    def initialize(build_element, ns)
      @building_subsections = []
      @standard_template = nil
      @single_floor_area = 0.0
      @building_rotation = 0.0
      @floor_height = 0.0
      @wwr = 0.0
      @name = nil
      # code to initialize
      read_xml(build_element, ns)
    end

    def num_stories
      return @num_stories_above_grade + @num_stories_below_grade
    end

    def read_xml(build_element, ns)
      # floor areas
      read_floor_areas(build_element, ns)
      # standard template
      read_standard_template_based_on_year(build_element, ns)
      # deal with stories above and below grade
      read_stories_above_and_below_grade(build_element, ns)
      # aspect ratio
      read_aspect_ratio(build_element, ns)

      build_element.elements.each("#{ns}:Subsections/#{ns}:Subsection") do |subsection_element|
        @building_subsections.push(BuildingSubsection.new(subsection_element, @standard_template, ns))
      end

      # need to set those defaults after initializing the subsections
      read_building_form_defaults

      # generate building name
      read_building_name

      read_width_and_length
    end

    def read_width_and_length
      footprint = nil
      # handle user-assigned single floor plate size condition
      if @single_floor_area > 0.0
        footprint = OpenStudio.convert(@single_floor_area, 'ft2', 'm2')
        @total_floor_area = footprint * num_stories.to_f
        puts 'INFO: User-defined single floor area was used for calculation of total building floor area'
      else
        footprint = @total_floor_area / num_stories.to_f
      end
      @width = Math.sqrt(footprint / @ns_to_ew_ratio)
      @length = footprint / @width
    end

    def read_standard_template_based_on_year(build_element, nodeSap)
      built_year = build_element.elements["#{nodeSap}:YearOfConstruction"].text.to_f

      if build_element.elements["#{nodeSap}:YearOfLastMajorRemodel"]
        major_remodel_year = build_element.elements["#{nodeSap}:YearOfLastMajorRemodel"].text.to_f
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

    def read_stories_above_and_below_grade(build_element, nodeSap)
      if build_element.elements["#{nodeSap}:FloorsAboveGrade"]
        @num_stories_above_grade = build_element.elements["#{nodeSap}:FloorsAboveGrade"].text.to_f
        if @num_stories_above_grade == 0
          @num_stories_above_grade = 1.0
        end
      else
        @num_stories_above_grade = 1.0 # setDefaultValue
      end

      if build_element.elements["#{nodeSap}:FloorsBelowGrade"]
        @num_stories_below_grade = build_element.elements["#{nodeSap}:FloorsBelowGrade"].text.to_f
      else
        @num_stories_below_grade = 0.0 # setDefaultValue
      end
    end

    def read_aspect_ratio(build_element, nodeSap)
      if build_element.elements["#{nodeSap}:AspectRatio"]
        @ns_to_ew_ratio = build_element.elements["#{nodeSap}:AspectRatio"].text.to_f
      else
        @ns_to_ew_ratio = 0.0 # setDefaultValue
      end
    end

    def read_building_form_defaults
      # if aspect ratio, story height or wwr have argument value of 0 then use smart building type defaults
      building_form_defaults = building_form_defaults(@building_subsections[0].bldg_type)
      if @ns_to_ew_ratio == 0.0
        @ns_to_ew_ratio = building_form_defaults[:aspect_ratio]
        puts "Warning: 0.0 value for aspect ratio will be replaced with smart default for #{@building_subsections[0].bldg_type} of #{building_form_defaults[:aspect_ratio]}."
      end
      if @floor_height == 0.0
        @floor_height = OpenStudio.convert(building_form_defaults[:typical_story], 'ft', 'm').get
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
        next if subsection.fraction_area.nil?
        building_fraction -= subsection.fraction_area
      end
      if building_fraction <= 0.0
        puts 'ERROR: Primary Building Type fraction of floor area must be greater than 0. Please lower one or more of the fractions for Building Type B-D.'
        return false
      end
      @building_subsections[0].fraction_area = building_fraction
      true
    end

    def read_building_name
      name_array = [@standard_template]
      @building_subsections.each do |bld_tp|
        name_array << bld_tp.bldg_type
      end
      @name = name_array.join('|').to_s
    end

    def create_space_types(model)
      @building_subsections.each do |bldg_subsec|
        bldg_subsec.create_space_types(model, @total_floor_area)
      end
    end

    def bldg_space_types_floor_area_hash
      newHash = {}
      @building_subsections.each do |bldg_subsec|
        bldg_subsec.space_types_floor_area.each do |space_type, hash|
          newHash[space_type] = hash
        end
      end
      return newHash
    end

    attr_reader :building_rotation, :name, :length, :width, :num_stories_above_grade, :num_stories_below_grade, :floor_height, :space, :wwr
  end
end
