# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************
require 'date'

require 'openstudio-standards'

require 'buildingsync/model_articulation/building_section'
require 'buildingsync/model_articulation/location_element'
require 'buildingsync/bcl_weather_file_downloader'

require_relative 'DOE_to_DEER_building_type'

module BuildingSync
  # Building class
  class Building < LocationElement
    # initialize
    # @param building_element [REXML::Element] an element corresponding to a single auc:Building
    # @param site_occupancy_classification [String]
    # @param site_total_floor_area [String]
    # @param ns [String] namespace, likely 'auc'
    def initialize(base_xml, site_occupancy_classification, site_total_floor_area, ns, standard_to_be_used)
      super(base_xml, ns, standard_to_be_used)
      @base_xml = base_xml
      @ns = ns

      help_element_class_type_check(base_xml, 'Building')
      @building_sections = []
      @building_sections_whole_building = []
      @model = nil
      @all_set = false

      # parameter to read and write.
      @epw_file_path = nil
      @standard_template = nil
      @building_rotation = 0.0
      @width = 0.0
      @length = 0.0
      @wwr = 0.0
      @name = nil
      # variables not used during read xml for now
      @party_wall_stories_north = 0
      @party_wall_stories_south = 0
      @party_wall_stories_west = 0
      @party_wall_stories_east = 0
      @party_wall_fraction = 0
      @built_year = 0
      @open_studio_standard = nil
      @occupant_quantity = nil
      @number_of_units = nil
      @fraction_area = 1.0
      @standard_to_be_used = standard_to_be_used
      # code to initialize
      read_xml(site_occupancy_classification, site_total_floor_area)
    end

    # returns number of stories
    # @return [Integer]
    def num_stories
      return @num_stories_above_grade + @num_stories_below_grade
    end

    # read xml
    # @param site_occupancy_classification [String]
    # @param site_total_floor_area [String]
    def read_xml(site_occupancy_classification, site_total_floor_area)
      # floor areas
      @total_floor_area = read_floor_areas(site_total_floor_area)
      # read location specific values
      read_location_values
      set_built_year

      # Validate and set occupancy classification
      check_occupancy_classification(site_occupancy_classification)

      # deal with stories above and below grade
      read_stories_above_and_below_grade
      # aspect ratio
      set_ns_to_ew_ratio

      # Create the BuildingSections
      @base_xml.elements.each("#{@ns}:Sections/#{@ns}:Section") do |section_element|
        section = BuildingSection.new(section_element, xget_text('OccupancyClassification'), @total_floor_area, num_stories, @ns, @standard_to_be_used)
        if section.section_type == 'Whole building'
          @building_sections_whole_building.push(section)
        elsif section.section_type == 'Space function' || section.section_type.nil?
          @building_sections.push(section)
        else
          puts "Unknown section type found:#{section.section_type}:"
        end
      end

      # generate building name
      read_other_building_details
    end

    # set all function to set all parameters for this building
    def set_all
      if !@all_set
        @all_set = true
        set_bldg_and_system_type_for_building_and_section
        set_building_form_defaults
        set_width_and_length
      end
    end

    # set width and length of the building footprint
    def set_width_and_length
      footprint = @total_floor_area / num_stories.to_f
      @width = Math.sqrt(footprint / @ns_to_ew_ratio)
      @length = footprint / @width
    end

    def check_occupancy_classification(site_occupancy_classification)
      # Set the OccupancyClassification text as that defined by the Site
      # ONLY if it is not already defined and is not empty
      if !site_occupancy_classification.nil? && !site_occupancy_classification.strip.empty?
        xset_or_create('OccupancyClassification', site_occupancy_classification, false)
      end
      occ = xget_text('OccupancyClassification')
      if occ.nil?
        if !site_occupancy_classification.nil? && site_occupancy_classification.strip.empty?
          raise StandardError, 'Unable to set OccupancyClassification to be empty'
        else
          raise StandardError, "Building ID: #{xget_id}. OccupancyClassification must be defined at either the Site or Building level."
        end
      end
    end

    # Set the @built_year based on YearOfConstruction / YearOfLastMajorRemodel
    def set_built_year
      if !@base_xml.elements["#{@ns}:YearOfConstruction"]
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Building.read_standard_template_based_on_year', 'Year of Construction is blank in your BuildingSync file.')
        raise StandardError, "Building ID: #{xget_id}. Year of Construction is blank in your BuildingSync file, but is required."
      end

      @built_year = xget_text_as_integer('YearOfConstruction')
      remodel_year = xget_text_as_integer('YearOfLastMajorRemodel')
      if !remodel_year.nil? && remodel_year > @built_year
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Building.set_built_year', "built_year for Standards reset from #{@built_year} (YearOfConstruction) to #{remodel_year} (YearOfLastMajorRemodel).")
        @built_year = remodel_year
      else
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Building.set_built_year', "built_year for Standards set to #{@built_year} (YearOfConstruction).")
      end
    end

    # read stories above and below grade
    def read_stories_above_and_below_grade
      if @base_xml.elements["#{@ns}:FloorsAboveGrade"]
        @num_stories_above_grade = @base_xml.elements["#{@ns}:FloorsAboveGrade"].text.to_f
      elsif @base_xml.elements["#{@ns}:ConditionedFloorsAboveGrade"]
        @num_stories_above_grade = @base_xml.elements["#{@ns}:ConditionedFloorsAboveGrade"].text.to_f
      else
        @num_stories_above_grade = 1.0 # setDefaultValue
      end

      if @base_xml.elements["#{@ns}:ConditionedFloorsBelowGrade"]
        @num_stories_below_grade = @base_xml.elements["#{@ns}:ConditionedFloorsBelowGrade"].text.to_f
      elsif @base_xml.elements["#{@ns}:FloorsBelowGrade"]
        @num_stories_below_grade = @base_xml.elements["#{@ns}:FloorsBelowGrade"].text.to_f
      else
        @num_stories_below_grade = 0.0 # setDefaultValue
      end

      if @num_stories_below_grade > 1
        raise StandardError, "Building ID: #{xget_id}. Number of stories below grade is > 1 (#{@num_stories_below_grade}).  Currently, only one story below grade is supported."
      end
    end

    # Set the @ns_to_ew_ratio parameter using the AspectRatio element if present
    def set_ns_to_ew_ratio
      if @base_xml.elements["#{@ns}:AspectRatio"]
        @ns_to_ew_ratio = xget_text_as_float('AspectRatio')
      else
        @ns_to_ew_ratio = 0.0 # setDefaultValue
      end
    end

    # get building type
    # @return [String]
    def get_building_type
      set_all
      # try to get the bldg type at the building level, if it is nil then look at the first section
      if !@standards_building_type.nil?
        return @standards_building_type
      else
        if @building_sections.count == 0
          OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Building.get_building_type', 'There is no occupancy type attached to this building in your BuildingSync file.')
          raise 'Error: There is no occupancy type attached to this building in your BuildingSync file.'
        else
          return @building_sections[0].standards_building_type
        end
      end
    end

    # get full path to epw file
    # return [String]
    def get_epw_file_path
      return @epw_file_path
    end

    # set aspect ratio, floor height, and WWR
    def set_building_form_defaults
      # if aspect ratio, story height or wwr have argument value of 0 then use smart building type defaults
      building_form_defaults = OpenstudioStandards::Geometry.building_form_defaults(get_building_type)
      if @ns_to_ew_ratio == 0.0 && !building_form_defaults.nil?
        @ns_to_ew_ratio = building_form_defaults[:aspect_ratio]
        OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Building.set_building_form_defaults', "0.0 value for aspect ratio will be replaced with smart default for #{get_building_type} of #{building_form_defaults[:aspect_ratio]}.")
      end
      # because of this can't set wwr to 0.0. If that is desired then we can change this to check for 1.0 instead of 0.0
      if @wwr == 0.0 && !building_form_defaults.nil?
        @wwr = building_form_defaults[:wwr]
        OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Building.set_building_form_defaults', "0.0 value for window to wall ratio will be replaced with smart default for #{get_building_type} of #{building_form_defaults[:wwr]}.")
      end
    end

    # read other building details
    def read_other_building_details
      if @base_xml.elements["#{@ns}:OccupancyLevels/#{@ns}:OccupancyLevel/#{@ns}:OccupantQuantity"]
        @occupant_quantity = @base_xml.elements["#{@ns}:OccupancyLevels/#{@ns}:OccupancyLevel/#{@ns}:OccupantQuantity"].text
      else
        @occupant_quantity = nil
      end

      if @base_xml.elements["#{@ns}:SpatialUnits/#{@ns}:SpatialUnit/#{@ns}:NumberOfUnits"]
        @number_of_units = @base_xml.elements["#{@ns}:SpatialUnits/#{@ns}:SpatialUnit/#{@ns}:NumberOfUnits"].text
      else
        @number_of_units = nil
      end
    end

    # create building space types
    # @param model [OpenStudio::Model]
    def create_bldg_space_types(model)
      @building_sections.each do |bldg_subsec|
        bldg_subsec.create_space_types(model, @total_floor_area, num_stories, @standard_template, @open_studio_standard)
      end
    end

    # build space types hash
    # @return [hash<string, array<hash<string, string>>]
    def build_space_type_hash
      space_type_hash = {}
      if @space_types
        space_type_list = []
        @space_types.each do |space_name, space_type|
          space_type_list << space_type[:space_type]
        end
        space_type_hash[xget_id] = space_type_list
      end
      @building_sections.each do |bldg_subsec|
        space_type_list = []
        bldg_subsec.space_types_floor_area.each do |space_type, hash|
          space_type_list << space_type
        end
        space_type_hash[bldg_subsec.xget_id] = space_type_list
      end
      return space_type_hash
    end

    # generate building space types floor area hash
    # @return [Hash]
    def bldg_space_types_floor_area_hash
      new_hash = {}
      if @building_sections.count > 0
        @building_sections.each do |bldg_subsec|
          bldg_subsec.space_types_floor_area.each do |space_type, hash|
            new_hash[space_type] = hash
          end
        end
        # if we have no sections we need to do the same just for the building
      elsif @building_sections.count == 0
        @space_types = get_space_types_from_building_type(@standards_building_type, @standard_template, true)
        puts " Space types: #{@space_types} selected for building type: #{@standards_building_type} and standard template: #{@standard_template}"
        space_types_floor_area = create_space_types(@model, @total_floor_area, num_stories, @standard_template, @open_studio_standard)
        space_types_floor_area.each do |space_type, hash|
          new_hash[space_type] = hash
        end
      end
      return new_hash
    end

    # set building and system type for building and sections
    def set_bldg_and_system_type_for_building_and_section
      @building_sections.each(&:set_bldg_and_system_type)

      building_occupancy_classification = xget_text('OccupancyClassification')
      if building_occupancy_classification.nil?
        largest_section = @building_sections.max_by {|s| s.get_floor_area }
        building_occupancy_classification = largest_section.occupancy_classification
      end

      set_bldg_and_system_type(building_occupancy_classification, @total_floor_area, num_stories, true)

      if @standards_building_type.nil?
        raise StandardError, "Building has building type `#{building_occupancy_classification}` which is not handled by the gem."
      end
    end


    # update the name of the building
    def update_name
      # update the name so it includes the standard_template string
      name_array = [@standard_template]
      name_array << get_building_type
      @building_sections.each do |bld_tp|
        name_array << bld_tp.standards_building_type
      end
      name_array << @name if !@name.nil? && !@name == ''
      @name = name_array.join('|').to_s
    end

    # set standard template
    def set_standard_template
      if @standard_to_be_used == CA_TITLE24
        # price is right rules
        deer_templates = ["DEER Pre-1975", "DEER 1985", "DEER 1996", "DEER 2003", "DEER 2007", "DEER 2011", "DEER 2014", "DEER 2015", "DEER 2017", "DEER 2020"]
        for template in deer_templates do
          year = template[-4..-1].to_i
          if @built_year <= year
            @standard_template = template
            return
          end
        end
        @standard_template = "DEER 2020"
      elsif @standard_to_be_used == ASHRAE90_1
        if @built_year < 1980
          @standard_template = 'DOE Ref Pre-1980'
        elsif @built_year >= 1980 && built_year < 2004
          @standard_template = 'DOE Ref 1980-2004'
        elsif @built_year >= 2004 && built_year < 2007
          @standard_template = '90.1-2004'
        elsif @built_year >= 2007 && built_year < 2010
          @standard_template = '90.1-2007'
        elsif @built_year >= 2010 && built_year < 2013
          @standard_template = '90.1-2010'
        elsif @built_year >= 2013
          @standard_template = '90.1-2013'
        end
        # TODO: add ASHRAE 2016 once it is available
      else
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Building.get_standard_template', "Unknown standard_to_be_used #{@standard_to_be_used}.")
        raise StandardError, "BuildingSync.Building.get_standard_template: Unknown standard_to_be_used #{@standard_to_be_used}."
      end
      OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Building.get_standard_template', "Using the following standard for default values #{@standard_template}.")
    end

    # get zones per space type
    # @param space_type [OpenStudio::Model::SpaceType]
    # @return [array<OpenStudio::Model::ThermalZone>]
    def get_zones_per_space_type(space_type)
      list_of_zones = []
      model_space_type = @model.getSpaceTypeByName(space_type.name.get).get
      model_space_type.spaces.each do |space|
        list_of_zones << space.thermalZone.get
      end
      return list_of_zones
    end

    # get year building was built
    # @return [Integer]
    def get_built_year
      return @built_year
    end

    # get @standard_template
    # @return [String]
    def get_standard_template
      return @standard_template
    end

    # get system type
    # @return [String]
    def get_system_type
      set_all
      if !@system_type.nil?
        return @system_type
      else
        return @building_sections[0].system_type
      end
    end

    # get stat file path
    # @param epw_file [String]
    # @return [String]
    def get_stat_file(epw_file)
      # Add SiteWaterMainsTemperature -- via parsing of STAT file.
      stat_file = "#{File.join(File.dirname(epw_file.path.to_s), File.basename(epw_file.path.to_s, '.*'))}.stat"
      unless File.exist? stat_file
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Building.get_stat_file', 'Could not find STAT file by filename, looking in the directory')
        stat_files = Dir["#{File.dirname(epw_file.path.to_s)}/*.stat"]
        if stat_files.size > 1
          OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Building.get_stat_file', 'More than one stat file in the EPW directory')
          return nil
        end
        if stat_files.empty?
          OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Building.get_stat_file', 'Cound not find the stat file in the EPW directory')
          return nil
        end

        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Building.get_stat_file', "Using STAT file: #{stat_files.first}")
        stat_file = stat_files.first
      end
      unless stat_file
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Building.get_stat_file', 'Could not find stat file')
        return nil
      end
      return stat_file
    end

    # set weather file and climate zone
    # @param climate_zone [String]
    # @param epw_file_path [String]
    # @param weather_argb [array]
    def set_weather_and_climate_zone(climate_zone, epw_file_path, *weather_argb)
      weather_station_name, weather_station_id, state_name, city_name = weather_argb

      # if weather file passed in
      if !epw_file_path.nil? && File.exist?(epw_file_path)
        puts "Using passed in weather file: #{epw_file_path}"
        @epw_file_path = epw_file_path

      # elsif climate zone passed in
      elsif !climate_zone.nil?
        puts "Using passed in climate_zone: #{climate_zone}"
        @epw_file_path = OpenstudioStandards::Weather.climate_zone_representative_weather_file_path(climate_zone)

      # elsif climate zone class attr set
      elsif !@climate_zone.nil?
        puts "Using building climate_zone: #{climate_zone}"
        @epw_file_path = OpenstudioStandards::Weather.climate_zone_representative_weather_file_path(@climate_zone)

      # elsif city and state passed in
      elsif !city_name.nil? && !state_name.nil?
        puts "Using passed in city_name and state_name: #{city_name}, #{state_name}"
        @epw_file_path = BuildingSync::BCLWeatherFileDownloader.download_weather_file_from_city_name(city_name, state_name)

      # elsif city and state class attr set
      elsif !@city_name.nil? && !@state_name.nil?
        puts "Using building's city_name and state_name: #{@city_name}, #{@state_name}"
        @epw_file_path = BuildingSync::BCLWeatherFileDownloader.download_weather_file_from_city_name(@city_name, @state_name)

      # we've got nothing to go off of
      else
        msg = "epw_file_path is nil and no way to set from Site or Building parameters."
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Building.set_weather_and_climate_zone', msg)
        raise StandardError, "BuildingSync.Building.set_weather_and_climate_zone: #{msg}"
      end

      # check files exists
      if !@epw_file_path
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Building.set_weather_and_climate_zone', "epw_file_path is false: #{@epw_file_path}")
        raise StandardError, "BuildingSync.Building.set_weather_and_climate_zone: epw_file_path is false: #{@epw_file_path}"
      end
      if !File.exist?(@epw_file_path)
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Building.set_weather_and_climate_zone', "epw_file_path does not exist: #{@epw_file_path}")
        raise StandardError, "BuildingSync.Building.set_weather_and_climate_zone: epw_file_path does not exist: #{@epw_file_path}"
      end

      OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Building.set_weather_and_climate_zone', "The path to the epw file is: #{@epw_file_path}")
    end

    # add site water mains temperature -- via parsing of STAT file.
    # @param stat_file [String]
    # @return [Boolean]
    def add_site_water_mains_temperature(stat_file)
      stat_model = ::EnergyPlus::StatFile.new(stat_file)
      water_temp = @model.getSiteWaterMainsTemperature
      water_temp.setAnnualAverageOutdoorAirTemperature(stat_model.mean_dry_bulb)
      water_temp.setMaximumDifferenceInMonthlyAverageOutdoorAirTemperatures(stat_model.delta_dry_bulb)
      OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Building.add_site_water_mains_temperature', "mean dry bulb is #{stat_model.mean_dry_bulb}")
      return true
    end

    # generate party walls
    def generate_party_walls
      party_walls_array = []
      if @party_wall_stories_north + @party_wall_stories_south + @party_wall_stories_east + @party_wall_stories_west > 0

        # loop through effective number of stories add orientation specific party walls per user arguments
        num_stories.ceil.times do |i|
          test_value = i + 1 - bar_hash[:num_stories_below_grade]

          array = []
          if @party_wall_stories_north >= test_value
            array << 'north'
          end
          if @party_wall_stories_south >= test_value
            array << 'south'
          end
          if @party_wall_stories_east >= test_value
            array << 'east'
          end
          if @party_wall_stories_west >= test_value
            array << 'west'
          end

          # populate party_wall_array for this story
          party_walls_array << array
        end
      end

      # calculate party walls if using party_wall_fraction method
      if @party_wall_fraction > 0 && !party_walls_array.empty?
        runner.registerWarning('Both orientaiton and fractional party wall values arguments were populated, will ignore fractional party wall input')
      elsif @party_wall_fraction > 0

        # orientation of long and short side of building will vary based on building rotation

        # full story ext wall area
        typical_length_facade_area = @length * floor_height
        typical_width_facade_area = @width * floor_height

        # top story ext wall area, may be partial story
        partial_story_multiplier = (1.0 - @num_stories_above_grade.ceil + @num_stories_above_grade)
        area_multiplier = partial_story_multiplier
        edge_multiplier = Math.sqrt(area_multiplier)
        top_story_length = @length * edge_multiplier
        top_story_width = @width * edge_multiplier
        top_story_length_facade_area = top_story_length * floor_height
        top_story_width_facade_area = top_story_width * floor_height

        total_exterior_wall_area = 2 * (@length + @width) * (@num_stories_above_grade.ceil - 1.0) * floor_height + 2 * (top_story_length + top_story_width) * floor_height
        target_party_wall_area = total_exterior_wall_area * @party_wall_fraction

        width_counter = 0
        width_area = 0.0
        facade_area = typical_width_facade_area
        until (width_area + facade_area >= target_party_wall_area) || (width_counter == @num_stories_above_grade.ceil * 2)
          # update facade area for top story
          if width_counter == @num_stories_above_grade.ceil - 1 || width_counter == @num_stories_above_grade.ceil * 2 - 1
            facade_area = top_story_width_facade_area
          else
            facade_area = typical_width_facade_area
          end

          width_counter += 1
          width_area += facade_area

        end
        width_area_remainder = target_party_wall_area - width_area

        length_counter = 0
        length_area = 0.0
        facade_area = typical_length_facade_area
        until (length_area + facade_area >= target_party_wall_area) || (length_counter == @num_stories_above_grade.ceil * 2)
          # update facade area for top story
          if length_counter == @num_stories_above_grade.ceil - 1 || length_counter == @num_stories_above_grade.ceil * 2 - 1
            facade_area = top_story_length_facade_area
          else
            facade_area = typical_length_facade_area
          end

          length_counter += 1
          length_area += facade_area
        end
        length_area_remainder = target_party_wall_area - length_area

        # get rotation and best fit to adjust orientation for fraction party wall
        rotation = @building_rotation % 360.0 # should result in value between 0 and 360
        card_dir_array = [0.0, 90.0, 180.0, 270.0, 360.0]
        # reverse array to properly handle 45, 135, 225, and 315
        best_fit = card_dir_array.reverse.min_by { |x| (x.to_f - rotation).abs }

        if ![90.0, 270.0].include? best_fit
          width_card_dir = ['east', 'west']
          length_card_dir = ['north', 'south']
        else
          # if rotation is closest to 90 or 270 then reverse which orientation is used for length and width
          width_card_dir = ['north', 'south']
          length_card_dir = ['east', 'west']
        end

        # if dont' find enough on short sides
        if width_area_remainder <= typical_length_facade_area

          num_stories.ceil.times do |i|
            if i + 1 <= @num_stories_below_grade
              party_walls_array << []
              next
            end
            if i + 1 - @num_stories_below_grade <= width_counter
              if i + 1 - @num_stories_below_grade <= width_counter - @num_stories_above_grade
                party_walls_array << width_card_dir
              else
                party_walls_array << [width_card_dir.first]
              end
            else
              party_walls_array << []
            end
          end

        else
          # use long sides instead
          num_stories.ceil.times do |i|
            if i + 1 <= @num_stories_below_grade
              party_walls_array << []
              next
            end
            if i + 1 - @num_stories_below_grade <= length_counter
              if i + 1 - @num_stories_below_grade <= length_counter - @num_stories_above_grade
                party_walls_array << length_card_dir
              else
                party_walls_array << [length_card_dir.first]
              end
            else
              party_walls_array << []
            end
          end
        end
        # TODO: - currently won't go past making two opposing sets of walls party walls. Info and registerValue are after create_bar in measure.rb
      end
      party_walls_array
    end

    # write parameters to xml file
    def prepare_final_xml
      @base_xml.elements["#{@ns}:OccupancyLevels/#{@ns}:OccupancyLevel/#{@ns}:OccupantQuantity"].text = @occupant_quantity if !@occupant_quantity.nil?
      @base_xml.elements["#{@ns}:SpatialUnits/#{@ns}:SpatialUnit/#{@ns}:NumberOfUnits"].text = @number_of_units if !@number_of_units.nil?

      # Add new element in the XML file
      add_user_defined_field_to_xml_file('OpenStudioModelName', @name)
      add_user_defined_field_to_xml_file('StandardTemplateYearOfConstruction', @built_year)
      add_user_defined_field_to_xml_file('StandardTemplate', @standard_template)
      add_user_defined_field_to_xml_file('BuildingRotation', @building_rotation)
      add_user_defined_field_to_xml_file('WindowWallRatio', @wwr)
      add_user_defined_field_to_xml_file('PartyWallStoriesNorth', @party_wall_stories_north)
      add_user_defined_field_to_xml_file('PartyWallStoriesSouth', @party_wall_stories_south)
      add_user_defined_field_to_xml_file('PartyWallStoriesEast', @party_wall_stories_east)
      add_user_defined_field_to_xml_file('PartyWallStoriesWest', @party_wall_stories_west)
      add_user_defined_field_to_xml_file('Width', @width)
      add_user_defined_field_to_xml_file('Length', @length)
      add_user_defined_field_to_xml_file('PartyWallFraction', @party_wall_fraction)
      if !@model.nil?
        add_user_defined_field_to_xml_file('ModelNumberThermalZones', @model.getThermalZones.size)
        add_user_defined_field_to_xml_file('ModelNumberSpaces', @model.getSpaces.size)
        add_user_defined_field_to_xml_file('ModelNumberStories', @model.getBuildingStorys.size)
        add_user_defined_field_to_xml_file('ModelNumberPeople', @model.getBuilding.numberOfPeople)
        add_user_defined_field_to_xml_file('ModelFloorArea(m2)', @model.getBuilding.floorArea)

        wf = @model.weatherFile.get
        add_user_defined_field_to_xml_file('ModelWeatherFileName', wf.nameString)
        add_user_defined_field_to_xml_file('ModelWeatherFileDataSource', wf.dataSource)
        add_user_defined_field_to_xml_file('ModelWeatherFileCity', wf.city)
        add_user_defined_field_to_xml_file('ModelWeatherFileStateProvinceRegion', wf.stateProvinceRegion)
        add_user_defined_field_to_xml_file('ModelWeatherFileLatitude', wf.latitude)
        add_user_defined_field_to_xml_file('ModelWeatherFileLongitude', wf.longitude)
      end
      prepare_final_xml_for_spatial_element
    end

    # get space types
    # @return [array<OpenStudio::Model::SpaceType>]
    def get_space_types
      return @model.getSpaceTypes
    end

    # get peak occupancy
    # @return [hash<string, float>]
    def get_peak_occupancy
      peak_occupancy = {}
      if @occupant_quantity
        peak_occupancy[xget_id] = @occupant_quantity.to_f
        return peak_occupancy
      end
      @building_sections.each do |section|
        peak_occupancy[section.xget_id] = section.get_peak_occupancy.to_f if section.get_peak_occupancy
      end
      return peak_occupancy
    end

    # get floor area
    # @return [hash<string, float>]
    def get_floor_area
      floor_area = {}
      if @total_floor_area
        floor_area[xget_id] = @total_floor_area.to_f
      end
      @building_sections.each do |section|
        if section.get_floor_area
          floor_area[section.xget_id] = section.get_floor_area
        end
      end
      return floor_area
    end

    def get_floor_to_floor_height
      largest_section = @building_sections.max_by {|s| s.get_floor_area }
      return nil if largest_section.nil?
      return largest_section.floor_to_floor_height
    end

    attr_reader :building_rotation, :name, :length, :width, :num_stories_above_grade, :num_stories_below_grade, :floor_height, :space, :wwr,
                :occupant_quantity, :number_of_units, :built_year, :year_major_remodel, :building_sections, :party_wall_fraction, :model, :epw_file_path, :climate_zone, :bar_division_method,
              :ns_to_ew_ratio
  end
end
