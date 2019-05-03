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
    @model = nil

    # initialize
    def initialize(build_element, ns)
      @building_subsections = []
      @standard_template = nil
      @single_floor_area = 0.0
      @building_rotation = 0.0
      @floor_height = 0.0
      @wwr = 0.0
      @name = nil
      @model = nil
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
        raise 'ERROR: Primary Building Type fraction of floor area must be greater than 0. Please lower one or more of the fractions for Building Type B-D.'
      end
      @building_subsections[0].fraction_area = building_fraction
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

    def generate_baseline_osm
      # this is code refactored from the "create_bar_from_building_type_ratios" measure
      # first we check is there is any data at all in this facility, aka if there is a site in the list
      # TODO: the original measure contains value range checks, should we implement them here or while importing data??
      # Fraction: 'bldg_type_b_fract_bldg_area', 'bldg_type_c_fract_bldg_area', 'bldg_type_d_fract_bldg_area', 'wwr', 'party_wall_fraction' 0 =<= 1
      # Bigger than 0 (excluding 0): 'total_bldg_floor_area' 0 <= nil
      # Bigger than 1 (including 1): 'num_stories_above_grade' 1 =< nil
      # Bigger than 0 (including 0): 'bldg_type_a_num_units', 'bldg_type_c_num_units', 'bldg_type_d_num_units', 'num_stories_below_grade', 'floor_height', 'ns_to_ew_ratio', 'party_wall_stories_north',
      # 'party_wall_stories_south', 'party_wall_stories_east', 'party_wall_stories_west', 'single_floor_area' 0 =<= nil

      # TODO: we have not really defined a good logic what happens with multiple sites, versus multiple buildings, here we just take the first building on the first site
      read_building_form_defaults

      # checking that the factions add up
      check_building_faction

      # let's create our new empty model
      @model = OpenStudio::Model::Model.new

      # set building rotation
      initial_rotation = @model.getBuilding.northAxis
      if building_rotation != initial_rotation
        @model.getBuilding.setNorthAxis(building_rotation)
        puts "INFO: Set Building Rotation to #{model.getBuilding.northAxis}"
      end
      @model.getBuilding.setName(name)

      create_space_types(@model)

      # calculate length and width of bar
      # todo - update slicing to nicely handle aspect ratio less than 1

      # create envelope
      # populate bar_hash and create envelope with data from envelope_data_hash and user arguments
      bar_hash = {}
      bar_hash[:length] = length
      bar_hash[:width] =  width
      bar_hash[:num_stories_below_grade] = num_stories_below_grade
      bar_hash[:num_stories_above_grade] = num_stories_above_grade
      bar_hash[:floor_height] = floor_height
      # bar_hash[:center_of_footprint] = OpenStudio::Point3d.new(length* 0.5,width * 0.5,0.0)
      bar_hash[:center_of_footprint] = OpenStudio::Point3d.new(0, 0, 0)
      bar_hash[:bar_division_method] = 'Multiple Space Types - Individual Stories Sliced'
      # default for now 'Multiple Space Types - Individual Stories Sliced', 'Multiple Space Types - Simple Sliced', 'Single Space Type - Core and Perimeter'
      bar_hash[:make_mid_story_surfaces_adiabatic] = false
      bar_hash[:space_types] = bldg_space_types_floor_area_hash
      bar_hash[:building_wwr_n] = wwr
      bar_hash[:building_wwr_s] = wwr
      bar_hash[:building_wwr_e] = wwr
      bar_hash[:building_wwr_w] = wwr

      # TODO: implement the party wall logic

      runner = OpenStudio::Ruleset::OSRunner.new
      # remove non-resource objects not removed by removing the building
      remove_non_resource_objects(runner, @model)

      party_walls_array = {}
      # populate bar hash with story information
      bar_hash[:stories] = {}
      num_stories.ceil.times do |i|
        if party_walls_array.empty?
          party_walls = []
        else
          party_walls = party_walls_array[i]
        end

        # add below_partial_story
        if num_stories.ceil > num_stories && i == num_stories_round_up - 2
          below_partial_story = true
        else
          below_partial_story = false
        end

        # bottom_story_ground_exposed_floor and top_story_exterior_exposed_roof already setup as bool
        bar_hash[:stories]["key #{i}"] = { story_party_walls: party_walls, story_min_multiplier: 1, story_included_in_building_area: true, below_partial_story: below_partial_story, bottom_story_ground_exposed_floor: true, top_story_exterior_exposed_roof: true }
      end

      # store expected floor areas to check after bar made
      target_areas = {}
      bar_hash[:space_types].each do |k, v|
        target_areas[k] = v[:floor_area]
      end

      # create bar
      create_bar(runner, @model, bar_hash, 'Basements Ground Mid Top')
      # using the default value for story multiplier for now 'Basements Ground Mid Top'

      # check expected floor areas against actual
      @model.getSpaceTypes.sort.each do |space_type|
        next if !target_areas.key? space_type

        # convert to IP
        actual_ip = OpenStudio.convert(space_type.floorArea, 'm^2', 'ft^2').get
        target_ip = OpenStudio.convert(target_areas[space_type], 'm^2', 'ft^2').get

        if (space_type.floorArea - target_areas[space_type]).abs >= 1.0
          if !bar_hash[:bar_division_method].include? 'Single Space Type'
            puts "ERROR: #{space_type.name} doesn't have the expected floor area (actual #{OpenStudio.toNeatString(actual_ip, 0, true)} ft^2, target #{OpenStudio.toNeatString(target_ip, 0, true)} ft^2)"
            return false
          else
            # will see this if use Single Space type division method on multi-use building or single building type without whole building space type
            puts "WARNING: #{space_type.name} doesn't have the expected floor area (actual #{OpenStudio.toNeatString(actual_ip, 0, true)} ft^2, target #{OpenStudio.toNeatString(target_ip, 0, true)} ft^2)"
          end
        end
      end

      # test for excessive exterior roof area (indication of problem with intersection and or surface matching)
      ext_roof_area = @model.getBuilding.exteriorSurfaceArea - @model.getBuilding.exteriorWallArea
      expected_roof_area = total_floor_area / num_stories.to_f
      if ext_roof_area > expected_roof_area && single_floor_area == 0.0 # only test if using whole-building area input
        puts 'WARNING: Roof area larger than expected, may indicate problem with inter-floor surface intersection or matching.'
        return false
      end

      # report final condition of model
      puts "INFO: The building finished with #{@model.getSpaces.size} spaces."

      return true
    end

    def write_osm(dir)
      @model.save("#{dir}/in.osm", true)
      p 'Model saved successfully'
    end

    attr_reader :building_rotation, :name, :length, :width, :num_stories_above_grade, :num_stories_below_grade, :floor_height, :space, :wwr
  end
end
