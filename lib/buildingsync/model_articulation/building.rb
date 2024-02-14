# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2022, Alliance for Sustainable Energy, LLC.
# BuildingSync(R), Copyright (c) 2015-2022, Alliance for Sustainable Energy, LLC.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER(S) AND ANY CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER(S), ANY CONTRIBUTORS, THE
# UNITED STATES GOVERNMENT, OR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF
# THEIR EMPLOYEES, BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# *******************************************************************************
require 'date'

require 'openstudio/extension/core/os_lib_helper_methods'
require 'openstudio/extension/core/os_lib_model_generation'

require 'buildingsync/model_articulation/building_section'
require 'buildingsync/model_articulation/location_element'
require 'buildingsync/get_bcl_weather_file'

module BuildingSync
  # Building class
  class Building < LocationElement
    include OsLib_HelperMethods
    include EnergyPlus
    include OsLib_ModelGeneration

    # initialize
    # @param building_element [REXML::Element] an element corresponding to a single auc:Building
    # @param site_occupancy_classification [String]
    # @param site_total_floor_area [String]
    # @param ns [String] namespace, likely 'auc'
    def initialize(base_xml, site_occupancy_classification, site_total_floor_area, ns)
      super(base_xml, ns)
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
      @floor_height = 0.0
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
      check_occupancy_classification(site_occupancy_classification)
      set_built_year

      # deal with stories above and below grade
      read_stories_above_and_below_grade
      # aspect ratio
      set_ns_to_ew_ratio

      # Create the BuildingSections
      @base_xml.elements.each("#{@ns}:Sections/#{@ns}:Section") do |section_element|
        section = BuildingSection.new(section_element, xget_text('OccupancyClassification'), @total_floor_area, num_stories, @ns)
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
      # ONLY if it is not already defined
      if !site_occupancy_classification.nil?
        xset_or_create('OccupancyClassification', site_occupancy_classification, false)
      end
      if xget_text('OccupancyClassification').nil?
        raise StandardError, "Building ID: #{xget_id}. OccupancyClassification must be defined at either the Site or Building level."
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

      if @base_xml.elements["#{@ns}:FloorsBelowGrade"]
        @num_stories_below_grade = @base_xml.elements["#{@ns}:FloorsBelowGrade"].text.to_f
      elsif @base_xml.elements["#{@ns}:ConditionedFloorsBelowGrade"]
        @num_stories_below_grade = @base_xml.elements["#{@ns}:ConditionedFloorsBelowGrade"].text.to_f
      else
        @num_stories_below_grade = 0.0 # setDefaultValue
      end

      if @num_stories_below_grade > 1.0
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Building.read_stories_above_and_below_grade', "Number of stories below grade is larger than 1: #{@num_stories_below_grade}, currently only one basement story is supported.")
        raise StandardError, "Building ID: #{xget_id}. Number of stories below grade is > 1 (#{num_stories_below_grade}).  Currently, only one story below grade is supported."
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
      building_form_defaults = building_form_defaults(get_building_type)
      if @ns_to_ew_ratio == 0.0 && !building_form_defaults.nil?
        @ns_to_ew_ratio = building_form_defaults[:aspect_ratio]
        OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Building.set_building_form_defaults', "0.0 value for aspect ratio will be replaced with smart default for #{get_building_type} of #{building_form_defaults[:aspect_ratio]}.")
      end
      if @floor_height == 0.0 && !building_form_defaults.nil?
        @floor_height = OpenStudio.convert(building_form_defaults[:typical_story], 'ft', 'm').get
        OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Building.set_building_form_defaults', "0.0 value for floor height will be replaced with smart default for #{get_building_type} of #{building_form_defaults[:typical_story]}.")
      end
      # because of this can't set wwr to 0.0. If that is desired then we can change this to check for 1.0 instead of 0.0
      if @wwr == 0.0 && !building_form_defaults.nil?
        @wwr = building_form_defaults[:wwr]
        OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Building.set_building_form_defaults', "0.0 value for window to wall ratio will be replaced with smart default for #{get_building_type} of #{building_form_defaults[:wwr]}.")
      end
    end

    # check building fraction
    def check_building_fraction
      # check that sum of fractions for b,c, and d is less than 1.0 (so something is left for primary building type)
      building_fraction = 1.0
      if @building_sections.count > 0
        # first we check if the building sections do have a fraction
        if @building_sections.count > 1
          areas = []
          floor_area = 0
          @building_sections.each do |section|
            if section.fraction_area.nil?
              areas.push(section.total_floor_area)
              floor_area += section.total_floor_area
            end
          end
          i = 0
          @building_sections.each do |section|
            section.fraction_area = areas[i] / @total_floor_area
            i += 1
          end
        elsif @building_sections.count == 1
          # only if we have just one section the section fraction is set to the building fraction (1)
          @building_sections[0].fraction_area = building_fraction
        end
        @building_sections.each do |section|
          puts "section with ID: #{section.xget_id} and type: '#{section.xget_text('SectionType')}' has fraction: #{section.fraction_area}"
          next if section.fraction_area.nil?
          building_fraction -= section.fraction_area
        end
        if building_fraction.round(3) < 0.0
          puts "building fraction is #{building_fraction}"
          OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Building.check_building_fraction', 'Primary Building Type fraction of floor area must be greater than 0. Please lower one or more of the fractions for Building Type B-D.')
          raise 'ERROR: Primary Building Type fraction of floor area must be greater than 0. Please lower one or more of the fractions for Building Type B-D.'
        end
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

    # build zone hash that stores zone lists for buildings and building sections
    # @return [[hash<string, array<Zone>>]]
    def build_zone_hash
      zone_hash = {}
      if @space_types
        zone_list = []
        @space_types.each do |space_name, space_type|
          zone_list.concat(get_zones_per_space_type(space_type[:space_type]))
        end
        zone_hash[xget_id] = zone_list
      end
      @building_sections.each do |bldg_subsec|
        zone_list = []
        bldg_subsec.space_types_floor_area.each do |space_type, hash|
          zone_list.concat(get_zones_per_space_type(space_type))
        end
        zone_hash[bldg_subsec.xget_id] = zone_list
      end
      return zone_hash
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

    # in initialize an empty model
    def initialize_model
      # let's create our new empty model
      @model = OpenStudio::Model::Model.new if @model.nil?
    end

    # set building and system type for building and sections
    def set_bldg_and_system_type_for_building_and_section
      @building_sections.each(&:set_bldg_and_system_type)

      set_bldg_and_system_type(xget_text('OccupancyClassification'), @total_floor_area, num_stories, true)
    end

    # determine the open studio standard and call the set_all function
    # @param standard_to_be_used [String]
    # @return [Standard]
    def determine_open_studio_standard(standard_to_be_used)
      set_all
      begin
        set_standard_template(standard_to_be_used, get_built_year)
        building_type = get_building_type
        @open_studio_standard = Standard.build("#{@standard_template}_#{building_type}")
        update_name
      rescue StandardError => e
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Building.determine_open_studio_standard', e.message[0..20])
        raise StandardError, "BuildingSync.Building.determine_open_studio_standard: #{e.message[0..20]}"
      end
      OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Building.determine_open_studio_standard', "Building Standard with template: #{@standard_template}_#{building_type}") if !@open_studio_standard.nil?
      return @open_studio_standard
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
    # @param standard_to_be_used [String]
    # @param built_year [Integer]
    def set_standard_template(standard_to_be_used, built_year)
      if standard_to_be_used == CA_TITLE24
        if built_year < 1978
          @standard_template = 'CBES Pre-1978'
        elsif built_year >= 1978 && built_year < 1992
          @standard_template = 'CBES T24 1978'
        elsif built_year >= 1992 && built_year < 2001
          @standard_template = 'CBES T24 1992'
        elsif built_year >= 2001 && built_year < 2005
          @standard_template = 'CBES T24 2001'
        elsif built_year >= 2005 && built_year < 2008
          @standard_template = 'CBES T24 2005'
        else
          @standard_template = 'CBES T24 2008'
        end
      elsif standard_to_be_used == ASHRAE90_1
        if built_year < 1980
          @standard_template = 'DOE Ref Pre-1980'
        elsif built_year >= 1980 && built_year < 2004
          @standard_template = 'DOE Ref 1980-2004'
        elsif built_year >= 2004 && built_year < 2007
          @standard_template = '90.1-2004'
        elsif built_year >= 2007 && built_year < 2010
          @standard_template = '90.1-2007'
        elsif built_year >= 2010 && built_year < 2013
          @standard_template = '90.1-2010'
        elsif built_year >= 2013
          @standard_template = '90.1-2013'
        end
        # TODO: add ASHRAE 2016 once it is available
      else
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Building.get_standard_template', "Unknown standard_to_be_used #{standard_to_be_used}.")
        raise StandardError, "BuildingSync.Building.get_standard_template: Unknown standard_to_be_used #{standard_to_be_used}."
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

    # get model
    # @return [OpenStudio::Model]
    def get_model
      # in case the model was not initialized before we create a new model if it is nil
      initialize_model
      return @model
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
    # @param standard_to_be_used [String]
    # @param latitude [String]
    # @param longitude [String]
    # @param ddy_file [String]
    # @param weather_argb [array]
    def set_weather_and_climate_zone(climate_zone, epw_file_path, standard_to_be_used, latitude, longitude, ddy_file, *weather_argb)
      initialize_model

      determine_climate_zone(standard_to_be_used) if climate_zone.nil?

      # here we check if there is an valid EPW file, if there is we use that file otherwise everything will be generated from climate zone
      if !epw_file_path.nil? && File.exist?(epw_file_path)
        @epw_file_path = epw_file_path
        puts "case 1: epw file exists #{epw_file_path} and climate_zone is: #{climate_zone}"
        set_weather_and_climate_zone_from_epw(climate_zone, standard_to_be_used, latitude, longitude, ddy_file)
      elsif climate_zone.nil? && @climate_zone.nil?
        weather_station_id = weather_argb[1]
        state_name = weather_argb[2]
        city_name = weather_argb[3]
        puts 'case 2: climate_zone is nil at the Site and Building level'
        if !weather_station_id.nil?
          puts "case 2.1: weather_station_id is not nil #{weather_station_id}"
          @epw_file_path = BuildingSync::GetBCLWeatherFile.new.download_weather_file_from_weather_id(weather_station_id)
        elsif !city_name.nil? && !state_name.nil?
          puts "case 2.2: SITE LEVEL city_name and state_name is not nil #{city_name} #{state_name}"
          @epw_file_path = BuildingSync::GetBCLWeatherFile.new.download_weather_file_from_city_name(state_name, city_name)
        elsif !@city_name.nil? && !@state_name.nil?
          puts "case 2.3: BUILDING LEVEL city_name and state_name is not nil #{@city_name} #{@state_name}"
          @epw_file_path = BuildingSync::GetBCLWeatherFile.new.download_weather_file_from_city_name(@state_name, @city_name)
        end

      else
        puts "case 3: SITE LEVEL climate zone #{climate_zone} BUILDING LEVEL climate zone #{@climate_zone}."
        puts "lat #{latitude} long #{longitude}"
        if climate_zone.nil?
          climate_zone = @climate_zone
          puts "Climate Zone set at the Building level: #{climate_zone}"
        else
          puts "Climate Zone set at the Site level: #{climate_zone}"
        end
        @epw_file_path = set_weather_and_climate_zone_from_climate_zone(climate_zone, standard_to_be_used, latitude, longitude)
        @epw_file_path = @epw_file_path.to_s
      end

      # Ensure a file path gets set, else raise error
      if @epw_file_path.nil?
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Building.set_weather_and_climate_zone', 'epw_file_path is nil and no way to set from Site or Building parameters.')
        raise StandardError, 'BuildingSync.Building.set_weather_and_climate_zone: epw_file_path is nil and no way to set from Site or Building parameters.'
      elsif !@epw_file_path
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Building.set_weather_and_climate_zone', "epw_file_path is false: #{@epw_file_path}")
        raise StandardError, "BuildingSync.Building.set_weather_and_climate_zone: epw_file_path is false: #{@epw_file_path}"
      elsif !File.exist?(@epw_file_path)
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Building.set_weather_and_climate_zone', "epw_file_path does not exist: #{@epw_file_path}")
        raise StandardError, "BuildingSync.Building.set_weather_and_climate_zone: epw_file_path does not exist: #{@epw_file_path}"
      end

      # setting the current year, so we do not get these annoying log messages:
      # [openstudio.model.YearDescription] <1> 'UseWeatherFile' is not yet a supported option for YearDescription
      year_description = @model.getYearDescription
      year_description.setCalendarYear(::Date.today.year)

      # add final condition
      OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Building.set_weather_and_climate_zone', "The final weather file is #{@model.getWeatherFile.city} and the model has #{@model.getDesignDays.size} design day objects.")
      OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Building.set_weather_and_climate_zone', "The path to the epw file is: #{@epw_file_path}")
    end

    # set weather file and climate zone from climate zone
    # @param climate_zone [String]
    # @param standard_to_be_used [String]
    # @param latitude [String]
    # @param longitude [String]
    def set_weather_and_climate_zone_from_climate_zone(climate_zone, standard_to_be_used, latitude, longitude)
      OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Building.set_weather_and_climate_zone_from_climate_zone', "Cannot add design days and weather file for climate zone: #{climate_zone}, no epw file provided")
      climate_zone_standard_string = climate_zone
      puts climate_zone
      puts standard_to_be_used
      OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Building.set_weather_and_climate_zone_from_climate_zone', "climate zone: #{climate_zone}")
      if standard_to_be_used == CA_TITLE24 && !climate_zone.nil?
        climate_zone_standard_string = "CEC T24-CEC#{climate_zone.gsub('Climate Zone', '').strip}"
      elsif standard_to_be_used == ASHRAE90_1 && !climate_zone.nil?
        climate_zone_standard_string = "ASHRAE 169-2006-#{climate_zone.gsub('Climate Zone', '').strip}"
      elsif climate_zone.nil?
        climate_zone_standard_string = ''
      end

      puts @open_studio_standard
      puts @open_studio_standard.class
      puts climate_zone_standard_string

      # set the model's weather file
      begin
        # Note: in future open_studio_standard verisions, model_add_design_days_and_weather_file is replaced with
        # model_set_building_location. I know if it's on purpose, but it can both "fail" (return False), or error out
        successfully_set_weather_file = @open_studio_standard.model_add_design_days_and_weather_file(@model, climate_zone_standard_string, nil)
      rescue
        raise StandardError, "Could not set weather file because climate zone '#{climate_zone_standard_string}' is not in default weather map."
      end

      # overwrite latitude and longitude if available
      if !latitude.nil? || !longitude.nil?
        site = @model.getSite
        if !latitude.nil?
          site.setLatitude(latitude.to_f)
        end
        if !longitude.nil?
          site.setLongitude(longitude.to_f)
        end
      end

      weather_file = @model.getWeatherFile

      OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Building.set_weather_and_climate_zone_from_climate_zone', "city is #{weather_file.city}. State is #{weather_file.stateProvinceRegion}")

      set_climate_zone(climate_zone, standard_to_be_used)
      return weather_file.path.get
    end

    # set climate zone
    # @param climate_zone [String]
    # @param standard_to_be_used [String]
    # @param stat_file [String]
    # @return [Boolean]
    def set_climate_zone(climate_zone, standard_to_be_used, stat_file = nil)
      # Set climate zone
      if climate_zone.nil?
        OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Building.set_climate_zone', 'Climate Zone is nil, trying to get it from stat file')
        # get climate zone from stat file
        text = nil
        File.open(stat_file) do |f|
          text = f.read.force_encoding('iso-8859-1')
        end

        # Get Climate zone.
        # - Climate type "3B" (ASHRAE Standard 196-2006 Climate Zone)**
        # - Climate type "6A" (ASHRAE Standards 90.1-2004 and 90.2-2004 Climate Zone)**
        regex = /Climate type \"(.*?)\" \(ASHRAE Standards?(.*)\)\*\*/
        match_data = text.match(regex)
        if match_data.nil?
          OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Building.set_climate_zone', "Can't find ASHRAE climate zone in stat file.")
        else
          climate_zone = match_data[1].to_s.strip
        end
      end

      climate_zones = @model.getClimateZones
      # set climate zone
      climate_zones.clear
      if standard_to_be_used == ASHRAE90_1 && !climate_zone.nil?
        climate_zones.setClimateZone('ASHRAE', climate_zone)
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Building.set_climate_zone', "Setting Climate Zone to #{climate_zones.getClimateZones('ASHRAE').first.value}")
        puts "setting ASHRAE climate zone to: #{climate_zone}"
        return true
      elsif standard_to_be_used == CA_TITLE24 && !climate_zone.nil?
        climate_zone = climate_zone.gsub('CEC', '').strip
        climate_zone = climate_zone.gsub('Climate Zone', '').strip
        climate_zone = climate_zone.delete('A').strip
        climate_zone = climate_zone.delete('B').strip
        climate_zone = climate_zone.delete('C').strip
        climate_zones.setClimateZone('CEC', climate_zone)
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Building.set_climate_zone', "Setting Climate Zone to #{climate_zone}")
        puts "setting CA_TITLE24 climate zone to: #{climate_zone}"
        return true
      end
      puts "could not set climate_zone #{climate_zone}"
      OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Building.set_climate_zone', "Cannot set the #{climate_zone} in context of this standard #{standard_to_be_used}")
      return false
    end

    # set weather file and climate zone from EPW file
    # @param climate_zone [String]
    # @param standard_to_be_used [String]
    # @param latitude [String]
    # @param longitude [String]
    # @param ddy_file [String]
    def set_weather_and_climate_zone_from_epw(climate_zone, standard_to_be_used, latitude, longitude, ddy_file = nil)
      epw_file = OpenStudio::EpwFile.new(@epw_file_path)

      weather_lat = epw_file.latitude
      if !latitude.nil?
        weather_lat = latitude.to_f
      end
      weather_lon = epw_file.longitude
      if !longitude.nil?
        weather_lon = longitude.to_f
      end

      weather_file = @model.getWeatherFile
      weather_file.setCity(epw_file.city)
      weather_file.setStateProvinceRegion(epw_file.stateProvinceRegion)
      weather_file.setCountry(epw_file.country)
      weather_file.setDataSource(epw_file.dataSource)
      weather_file.setWMONumber(epw_file.wmoNumber.to_s)
      weather_file.setLatitude(weather_lat)
      weather_file.setLongitude(weather_lon)
      weather_file.setTimeZone(epw_file.timeZone)
      weather_file.setElevation(epw_file.elevation)
      weather_file.setString(10, epw_file.path.to_s)

      weather_name = "#{epw_file.city}_#{epw_file.stateProvinceRegion}_#{epw_file.country}"
      weather_time = epw_file.timeZone
      weather_elev = epw_file.elevation

      # Add or update site data
      site = @model.getSite
      site.setName(weather_name)
      site.setLatitude(weather_lat)
      site.setLongitude(weather_lon)
      site.setTimeZone(weather_time)
      site.setElevation(weather_elev)

      OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Building.set_weather_and_climate_zone_from_epw', "city is #{epw_file.city}. State is #{epw_file.stateProvinceRegion}")

      stat_file = get_stat_file(epw_file)
      add_site_water_mains_temperature(stat_file) if !stat_file.nil?

      set_climate_zone(climate_zone, standard_to_be_used, stat_file)

      # Remove all the Design Day objects that are in the file
      @model.getObjectsByType('OS:SizingPeriod:DesignDay'.to_IddObjectType).each(&:remove)

      # find the ddy files
      ddy_file = "#{File.join(File.dirname(epw_file.path.to_s), File.basename(epw_file.path.to_s, '.*'))}.ddy" if ddy_file.nil?
      unless File.exist? ddy_file
        ddy_files = Dir["#{File.dirname(epw_file.path.to_s)}/*.ddy"]
        if ddy_files.size > 1
          OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Building.set_weather_and_climate_zone_from_epw', 'More than one ddy file in the EPW directory')
          return false
        end
        if ddy_files.empty?
          OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Building.set_weather_and_climate_zone_from_epw', 'could not find the ddy file in the EPW directory')
          return false
        end

        ddy_file = ddy_files.first
      end

      unless ddy_file
        runner.registerError "Could not find DDY file for #{ddy_file}"
        return error
      end

      ddy_model = OpenStudio::EnergyPlus.loadAndTranslateIdf(ddy_file).get
      ddy_model.getObjectsByType('OS:SizingPeriod:DesignDay'.to_IddObjectType).each do |d|
        # grab only the ones that matter
        ddy_list = /(Htg 99.6. Condns DB)|(Clg .4. Condns WB=>MDB)|(Clg .4% Condns DB=>MWB)/
        if d.name.get.match?(ddy_list)
          OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Building.set_weather_and_climate_zone_from_epw', "Adding object #{d.name}")

          # add the object to the existing model
          @model.addObject(d.clone)
        end
      end
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

    # generate baseline model in osm file format
    def generate_baseline_osm
      # checking that the fractions add up
      check_building_fraction

      # set building rotation
      initial_rotation = @model.getBuilding.northAxis
      if @building_rotation != initial_rotation
        @model.getBuilding.setNorthAxis(building_rotation)
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Building.generate_baseline_osm', "Set Building Rotation to #{@model.getBuilding.northAxis}")
      end
      if !@name.nil?
        @model.getBuilding.setName(@name)
      end

      create_bldg_space_types(@model)

      # create envelope
      # populate bar_hash and create envelope with data from envelope_data_hash and user arguments
      bar_hash = {}
      bar_hash[:length] = @length
      bar_hash[:width] = @width
      bar_hash[:num_stories_below_grade] = num_stories_below_grade.to_i
      bar_hash[:num_stories_above_grade] = num_stories_above_grade.to_i
      bar_hash[:floor_height] = floor_height
      bar_hash[:center_of_footprint] = OpenStudio::Point3d.new(0, 0, 0)
      bar_hash[:bar_division_method] = 'Multiple Space Types - Individual Stories Sliced'
      # default for now 'Multiple Space Types - Individual Stories Sliced', 'Multiple Space Types - Simple Sliced', 'Single Space Type - Core and Perimeter'
      bar_hash[:make_mid_story_surfaces_adiabatic] = false
      bar_hash[:space_types] = bldg_space_types_floor_area_hash
      bar_hash[:building_wwr_n] = wwr
      bar_hash[:building_wwr_s] = wwr
      bar_hash[:building_wwr_e] = wwr
      bar_hash[:building_wwr_w] = wwr

      runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)
      # remove non-resource objects not removed by removing the building
      remove_non_resource_objects(runner, @model)

      # party_walls_array to be used by orientation specific or fractional party wall values
      party_walls_array = generate_party_walls # this is an array of arrays, where each entry is effective building story with array of directions

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
            OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Building.generate_baseline_osm', "#{space_type.name} doesn't have the expected floor area (actual #{OpenStudio.toNeatString(actual_ip, 0, true)} ft^2, target #{OpenStudio.toNeatString(target_ip, 0, true)} ft^2)")
            return false
          else
            # will see this if use Single Space type division method on multi-use building or single building type without whole building space type
            OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Building.generate_baseline_osm', "WARNING: #{space_type.name} doesn't have the expected floor area (actual #{OpenStudio.toNeatString(actual_ip, 0, true)} ft^2, target #{OpenStudio.toNeatString(target_ip, 0, true)} ft^2)")
          end
        end
      end

      # test for excessive exterior roof area (indication of problem with intersection and or surface matching)
      ext_roof_area = @model.getBuilding.exteriorSurfaceArea - @model.getBuilding.exteriorWallArea
      expected_roof_area = total_floor_area / num_stories.to_f
      if ext_roof_area > expected_roof_area # only test if using whole-building area input
        OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Building.generate_baseline_osm', 'Roof area larger than expected, may indicate problem with inter-floor surface intersection or matching.')
        return false
      end

      # report final condition of model
      OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Building.generate_baseline_osm', "The building finished with #{@model.getSpaces.size} spaces.")

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

    # write baseline model to osm file
    # @param dir [String]
    def write_osm(dir)
      @model.save("#{dir}/in.osm", true)
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
      add_user_defined_field_to_xml_file('FloorHeight', @floor_height)
      add_user_defined_field_to_xml_file('WindowWallRatio', @wwr)
      add_user_defined_field_to_xml_file('PartyWallStoriesNorth', @party_wall_stories_north)
      add_user_defined_field_to_xml_file('PartyWallStoriesSouth', @party_wall_stories_south)
      add_user_defined_field_to_xml_file('PartyWallStoriesEast', @party_wall_stories_east)
      add_user_defined_field_to_xml_file('PartyWallStoriesWest', @party_wall_stories_west)
      add_user_defined_field_to_xml_file('Width', @width)
      add_user_defined_field_to_xml_file('Length', @length)
      add_user_defined_field_to_xml_file('PartyWallFraction', @party_wall_fraction)
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

    attr_reader :building_rotation, :name, :length, :width, :num_stories_above_grade, :num_stories_below_grade, :floor_height, :space, :wwr,
                :occupant_quantity, :number_of_units, :built_year, :year_major_remodel, :building_sections
  end
end
