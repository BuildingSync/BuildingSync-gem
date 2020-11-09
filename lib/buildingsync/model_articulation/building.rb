# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2020, Alliance for Sustainable Energy, LLC.
# BuildingSync(R), Copyright (c) 2015-2020, Alliance for Sustainable Energy, LLC.
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
require_relative 'building_section'
require_relative 'location_element'
require_relative '../../../lib/buildingsync/get_bcl_weather_file'
require 'date'
require 'openstudio/extension/core/os_lib_helper_methods'
require 'openstudio/extension/core/os_lib_model_generation'

module BuildingSync
  # Building class
  class Building < LocationElement
    include OsLib_HelperMethods
    include EnergyPlus
    include OsLib_ModelGeneration

    # initialize
    # @param building_element [REXML::Element]
    # @param site_occupancy_type [String]
    # @param site_total_floor_area [String]
    # @param ns [String]
    def initialize(building_element, site_occupancy_type, site_total_floor_area, ns)
      @building_sections = []
      @building_sections_whole_building = []
      @model = nil
      @primary_contact_id = nil
      @id = nil
      @all_set = false

      # parameter to read and write.
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
      @ownership = nil
      @occupancy_classification = nil
      @year_major_remodel = nil
      @year_of_last_energy_audit = nil
      @year_last_commissioning = nil
      @building_automation_system = nil
      @historical_landmark = nil
      @percent_occupied_by_owner = nil
      @occupant_quantity = nil
      @number_of_units = nil
      @fraction_area = 1.0
      # code to initialize
      read_xml(building_element, site_occupancy_type, site_total_floor_area, ns)
    end

    # returns number of stories
    # @return [Integer]
    def num_stories
      return @num_stories_above_grade + @num_stories_below_grade
    end

    # read xml
    # @param building_element [REXML::Element]
    # @param site_occupancy_type [String]
    # @param site_total_floor_area [String]
    # @param ns [String]
    def read_xml(building_element, site_occupancy_type, site_total_floor_area, ns)
      # building ID
      if building_element.attributes['ID']
        @id = building_element.attributes['ID']
      end

      # read location specific values
      read_location_values(building_element, ns)
      # floor areas
      read_floor_areas(building_element, site_total_floor_area, ns)
      # standard template
      read_built_remodel_year(building_element, ns)
      # deal with stories above and below grade
      read_stories_above_and_below_grade(building_element, ns)
      # aspect ratio
      read_aspect_ratio(building_element, ns)
      # read occupancy
      @occupancy_type = read_occupancy_type(building_element, site_occupancy_type, ns)

      building_element.elements.each("#{ns}:Sections/#{ns}:Section") do |section_element|
        section = BuildingSection.new(section_element, @occupancy_type, @total_floor_area, ns)
        if section.section_type == 'Whole building'
          @building_sections_whole_building.push(section)
        elsif section.section_type == 'Space function' || section.section_type.nil?
          @building_sections.push(section)
        else
          puts "Unknown section type found:#{section.section_type}:"
        end
      end

      # floor areas
      @total_floor_area = read_floor_areas(building_element, site_total_floor_area, ns)

      # generate building name
      read_building_name(building_element, ns)

      read_ownership(building_element, ns)
      read_other_building_details(building_element, ns)
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

    # read built and/or remodel year
    # @param building_element [REXML::Element]
    # @param ns [String]
    def read_built_remodel_year(building_element, ns)
      if !building_element.elements["#{ns}:YearOfConstruction"]
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Building.read_standard_template_based_on_year', 'Year of Construction is blank in your BuildingSync file.')
        raise 'Error : Year of Construction is blank in your BuildingSync file.'
      end

      @built_year = building_element.elements["#{ns}:YearOfConstruction"].text.to_i

      if building_element.elements["#{ns}:YearOfLastMajorRemodel"]
        @year_major_remodel = building_element.elements["#{ns}:YearOfLastMajorRemodel"].text.to_i
        @built_year = @year_major_remodel if @year_major_remodel > @built_year
      end

      if building_element.elements["#{ns}:YearOfLastEnergyAudit"]
        @year_of_last_energy_audit = building_element.elements["#{ns}:YearOfLastEnergyAudit"].text.to_i
      end

      if building_element.elements["#{ns}:RetrocommissioningDate"]
        @year_last_commissioning = Date.parse building_element.elements["#{ns}:RetrocommissioningDate"].text
      else
        @year_last_commissioning = nil
      end
    end

    # read stories above and below grade
    # @param building_element [REXML::Element]
    # @param ns [String]
    def read_stories_above_and_below_grade(building_element, ns)
      if building_element.elements["#{ns}:FloorsAboveGrade"]
        @num_stories_above_grade = building_element.elements["#{ns}:FloorsAboveGrade"].text.to_f
      elsif building_element.elements["#{ns}:ConditionedFloorsAboveGrade"]
        @num_stories_above_grade = building_element.elements["#{ns}:ConditionedFloorsAboveGrade"].text.to_f
      else
        @num_stories_above_grade = 1.0 # setDefaultValue
      end

      if @num_stories_above_grade == 0
        @num_stories_above_grade = 1.0
      end

      if building_element.elements["#{ns}:FloorsBelowGrade"]
        @num_stories_below_grade = building_element.elements["#{ns}:FloorsBelowGrade"].text.to_f
      elsif building_element.elements["#{ns}:ConditionedFloorsBelowGrade"]
        @num_stories_below_grade = building_element.elements["#{ns}:ConditionedFloorsBelowGrade"].text.to_f
      else
        @num_stories_below_grade = 0.0 # setDefaultValue
      end
      if @num_stories_below_grade > 1.0
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Building.read_stories_above_and_below_grade', "Number of stories below grade is larger than 1: #{@num_stories_below_grade}, currently only one basement story is supported.")
        raise "Error : Number of stories below grade is larger than 1: #{@num_stories_below_grade}, currently only one basement story is supported."
      end
    end

    # read aspect ratio
    # @param building_element [REXML::Element]
    # @param ns [String]
    def read_aspect_ratio(building_element, ns)
      if building_element.elements["#{ns}:AspectRatio"]
        @ns_to_ew_ratio = building_element.elements["#{ns}:AspectRatio"].text.to_f
      else
        @ns_to_ew_ratio = 0.0 # setDefaultValue
      end
    end

    # read city and state name
    # @param building_element [REXML::Element]
    # @param ns [String]
    def read_city_and_state_name(building_element, ns)
      if building_element.elements["#{ns}:Address/#{ns}:City"]
        @city_name = building_element.elements["#{ns}:Address/#{ns}:City"].text
      else
        @city_name = nil
      end
      if building_element.elements["#{ns}:Address/#{ns}:State"]
        @state_name = building_element.elements["#{ns}:Address/#{ns}:State"].text
      else
        @state_name = nil
      end
    end

    # get building type
    # @return [String]
    def get_building_type
      set_all
      # try to get the bldg type at the building level, if it is nil then look at the first section
      if !@bldg_type.nil?
        return @bldg_type
      else
        if @building_sections.count == 0
          OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Building.get_building_type', 'There is no occupancy type attached to this building in your BuildingSync file.')
          raise 'Error: There is no occupancy type attached to this building in your BuildingSync file.'
        else
          return @building_sections[0].bldg_type
        end
      end
    end

    # get climate zone
    # @param standard_to_be_used [String]
    # @return [String]
    def get_climate_zone(standard_to_be_used = nil)
      if standard_to_be_used == ASHRAE90_1
        return @climate_zone_ashrae
      elsif standard_to_be_used == CA_TITLE24
        return @climate_zone_ca_t24
      else
        return @climate_zone
      end
    end

    # set building form defaults
    def set_building_form_defaults
      # if aspect ratio, story height or wwr have argument value of 0 then use smart building type defaults
      building_form_defaults = building_form_defaults(get_building_type)
      if @ns_to_ew_ratio == 0.0 && !building_form_defaults.nil?
        @ns_to_ew_ratio = building_form_defaults[:aspect_ratio]
        OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Building.read_building_form_defaults', "0.0 value for aspect ratio will be replaced with smart default for #{get_building_type} of #{building_form_defaults[:aspect_ratio]}.")
      end
      if @floor_height == 0.0 && !building_form_defaults.nil?
        @floor_height = OpenStudio.convert(building_form_defaults[:typical_story], 'ft', 'm').get
        OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Building.read_building_form_defaults', "0.0 value for floor height will be replaced with smart default for #{get_building_type}of #{building_form_defaults[:typical_story]}.")
      end
      # because of this can't set wwr to 0.0. If that is desired then we can change this to check for 1.0 instead of 0.0
      if @wwr == 0.0 && !building_form_defaults.nil?
        @wwr = building_form_defaults[:wwr]
        OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Building.read_building_form_defaults', "0.0 value for window to wall ratio will be replaced with smart default for #{get_building_type} of #{building_form_defaults[:wwr]}.")
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
          puts "section with ID: #{section.id} and type: '#{section.section_type}' has fraction: #{section.fraction_area}"
          next if section.fraction_area.nil?
          building_fraction -= section.fraction_area
        end
        if building_fraction.round(3) < 0.0
          puts "building fraction is #{building_fraction}"
          OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Building.check_building_faction', 'Primary Building Type fraction of floor area must be greater than 0. Please lower one or more of the fractions for Building Type B-D.')
          raise 'ERROR: Primary Building Type fraction of floor area must be greater than 0. Please lower one or more of the fractions for Building Type B-D.'
        end
      end
    end

    # read ownership
    # @param building_element [REXML::Element]
    # @param ns [String]
    def read_ownership(building_element, ns)
      if building_element.elements["#{ns}:Ownership"]
        @ownership = building_element.elements["#{ns}:Ownership"].text
      else
        @ownership = nil
      end

      if building_element.elements["#{ns}:OccupancyClassification"]
        @occupancy_classification = building_element.elements["#{ns}:OccupancyClassification"].text
      else
        @occupancy_classification = nil
      end
    end

    # read other building details
    # @param building_element [REXML::Element]
    # @param ns [String]
    def read_other_building_details(building_element, ns)
      if building_element.elements["#{ns}:PrimaryContactID"]
        @primary_contact_id = building_element.elements["#{ns}:PrimaryContactID"].text
      else
        @primary_contact_id = nil
      end

      if building_element.elements["#{ns}:BuildingAutomationSystem"]
        @building_automation_system = building_element.elements["#{ns}:BuildingAutomationSystem"].text.to_bool
      else
        @building_automation_system = nil
      end

      if building_element.elements["#{ns}:HistoricalLandmark"]
        @historical_landmark = building_element.elements["#{ns}:HistoricalLandmark"].text.to_bool
      else
        @historical_landmark = nil
      end

      if building_element.elements["#{ns}:PercentOccupiedByOwner"]
        @percent_occupied_by_owner = building_element.elements["#{ns}:PercentOccupiedByOwner"].text
      else
        @percent_occupied_by_owner = nil
      end

      if building_element.elements["#{ns}:OccupancyLevels/#{ns}:OccupancyLevel/#{ns}:OccupantQuantity"]
        @occupant_quantity = building_element.elements["#{ns}:OccupancyLevels/#{ns}:OccupancyLevel/#{ns}:OccupantQuantity"].text
      else
        @occupant_quantity = nil
      end

      if building_element.elements["#{ns}:SpatialUnits/#{ns}:SpatialUnit/#{ns}:NumberOfUnits"]
        @number_of_units = building_element.elements["#{ns}:SpatialUnits/#{ns}:SpatialUnit/#{ns}:NumberOfUnits"].text
      else
        @number_of_units = nil
      end
    end

    # read building name
    # @param building_element [REXML::Element]
    # @param ns [String]
    def read_building_name(building_element, ns)
      name_array = []
      name_element = building_element.elements["#{ns}:PremisesName"]
      if !name_element.nil?
        name_array << name_element.text
      end
      @name = name_array.join('|').to_s
    end

    # create building space types
    # @param model [OpenStudio::Model]
    def create_bldg_space_types(model)
      @building_sections.each do |bldg_subsec|
        bldg_subsec.create_space_types(model, @total_floor_area, @standard_template, @open_studio_standard)
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
        zone_hash[@id] = zone_list
      end
      @building_sections.each do |bldg_subsec|
        zone_list = []
        bldg_subsec.space_types_floor_area.each do |space_type, hash|
          zone_list.concat(get_zones_per_space_type(space_type))
        end
        zone_hash[bldg_subsec.id] = zone_list
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
        space_type_hash[@id] = space_type_list
      end
      @building_sections.each do |bldg_subsec|
        space_type_list = []
        bldg_subsec.space_types_floor_area.each do |space_type, hash|
          space_type_list << space_type
        end
        space_type_hash[bldg_subsec.id] = space_type_list
      end
      return space_type_hash
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

    # generate building space types floor area hash
    # @return [hash]
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
        @space_types = get_space_types_from_building_type(@bldg_type, @standard_template, true)
        puts " Space types: #{@space_types} selected for building type: #{@bldg_type} and standard template: #{@standard_template}"
        space_types_floor_area = create_space_types(@model, @total_floor_area, @standard_template, @open_studio_standard)
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

    # get model
    # @return [OpenStudio::Model]
    def get_model
      # in case the model was not initialized before we create a new model if it is nil
      initialize_model
      return @model
    end

    # set building and system type for building and sections
    def set_bldg_and_system_type_for_building_and_section
      @building_sections.each(&:set_bldg_and_system_type)

      set_bldg_and_system_type(@occupancy_type, @total_floor_area, false)
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
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.BuildingSection.read_xml', e.message)
      end
      OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.BuildingSection.read_xml', "Building Standard with template: #{@standard_template}_#{building_type}") if !@open_studio_standard.nil?
      return @open_studio_standard
    end

    # update the name of the building
    def update_name
      # update the name so it includes the standard_template string
      name_array = [@standard_template]
      name_array << get_building_type
      @building_sections.each do |bld_tp|
        name_array << bld_tp.bldg_type
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
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Facility.get_standard_template', "Unknown standard_to_be_used #{standard_to_be_used}.")
      end
      OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.get_standard_template', "Using the following standard for default values #{@standard_template}.")
    end

    # get year building was built
    # @return [Integer]
    def get_built_year
      return @built_year
    end

    # get building template
    # @return [String]
    def get_building_template
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

      # here we check if there is an valid EPW file, if there is we use that file otherwise everything will be generated from climate zone
      if !epw_file_path.nil? && File.exist?(epw_file_path)
        puts "case 1: epw file exists #{epw_file_path} and climate_zone is: #{climate_zone}"
        set_weather_and_climate_zone_from_epw(climate_zone, epw_file_path, standard_to_be_used, latitude, longitude, ddy_file)
      elsif climate_zone.nil?
        weather_station_id = weather_argb[1]
        state_name = weather_argb[2]
        city_name = weather_argb[3]
        puts "case 2: climate_zone is nil #{climate_zone}"
        if !weather_station_id.nil?
          puts "case 2.1: weather_station_id is not nil #{weather_station_id}"
          epw_file_path = BuildingSync::GetBCLWeatherFile.new.download_weather_file_from_weather_id(weather_station_id)
        elsif !city_name.nil? && !state_name.nil?
          puts "case 2.2: SITE LEVEL city_name and state_name is not nil #{city_name} #{state_name}"
          epw_file_path = BuildingSync::GetBCLWeatherFile.new.download_weather_file_from_city_name(state_name, city_name)
        elsif !@city_name.nil? && !@state_name.nil?
          puts "case 2.3: BUILDING LEVEL city_name and state_name is not nil #{@city_name} #{@state_name}"
          epw_file_path = BuildingSync::GetBCLWeatherFile.new.download_weather_file_from_city_name(@state_name, @city_name)
        end

        # Ensure a file path gets set, else raise error
        if epw_file_path.nil?
          OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Building.set_weather_and_climate_zone', 'epw_file_path is nil and no way to set from Site or Building parameters.')
          raise 'Error : epw_file_path is nil and no way to set from Site or Building parameters.'
        elsif !File.exist?(epw_file_path)
          OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Building.set_weather_and_climate_zone', 'epw_file_path file does not exist.')
          raise 'Error : epw_file_path file does not exist.'
        end

        set_weather_and_climate_zone_from_epw(climate_zone, epw_file_path, standard_to_be_used, latitude, longitude)
      else
        puts "case 3: climate zone #{climate_zone} lat #{latitude} long #{longitude}"
        set_weather_and_climate_zone_from_climate_zone(climate_zone, standard_to_be_used, latitude, longitude)
      end

      # setting the current year, so we do not get these annoying log messages:
      # [openstudio.model.YearDescription] <1> 'UseWeatherFile' is not yet a supported option for YearDescription
      year_description = @model.getYearDescription
      year_description.setCalendarYear(::Date.today.year)

      # add final condition
      OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.set_weather_and_climate_zone', "The final weather file is #{@model.getWeatherFile.city} and the model has #{@model.getDesignDays.size} design day objects.")
    end

    # set weather file and climate zone from climate zone
    # @param climate_zone [String]
    # @param standard_to_be_used [String]
    # @param latitude [String]
    # @param longitude [String]
    def set_weather_and_climate_zone_from_climate_zone(climate_zone, standard_to_be_used, latitude, longitude)
      climate_zone_standard_string = climate_zone
      OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.set_weather_and_climate_zone_from_climate_zone', "climate zone: #{climate_zone}")
      if standard_to_be_used == CA_TITLE24 && !climate_zone.nil?
        climate_zone_standard_string = "CEC T24-CEC#{climate_zone.gsub('Climate Zone', '').strip}"
      elsif standard_to_be_used == ASHRAE90_1 && !climate_zone.nil?
        climate_zone_standard_string = "ASHRAE 169-2006-#{climate_zone.gsub('Climate Zone', '').strip}"
      elsif climate_zone.nil?
        climate_zone_standard_string = ''
      end

      if !@open_studio_standard.nil? && !@open_studio_standard.model_add_design_days_and_weather_file(@model, climate_zone_standard_string, nil)
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Building.set_weater_and_climate_zone', "Cannot add design days and weather file for climate zone: #{climate_zone}, no epw file provided")
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

      OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.set_weater_and_climate_zone', "city is #{weather_file.city}. State is #{weather_file.stateProvinceRegion}")

      set_climate_zone(climate_zone, standard_to_be_used)
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
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.set_climate_zone', "Setting Climate Zone to #{climate_zones.getClimateZones('ASHRAE').first.value}")
        puts "setting ASHRAE climate zone to: #{climate_zone}"
        return true
      elsif standard_to_be_used == CA_TITLE24 && !climate_zone.nil?
        climate_zone = climate_zone.gsub('CEC', '').strip
        climate_zone = climate_zone.gsub('Climate Zone', '').strip
        climate_zone = climate_zone.delete('A').strip
        climate_zone = climate_zone.delete('B').strip
        climate_zone = climate_zone.delete('C').strip
        climate_zones.setClimateZone('CEC', climate_zone)
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.set_climate_zone', "Setting Climate Zone to #{climate_zone}")
        puts "setting CA_TITLE24 climate zone to: #{climate_zone}"
        return true
      end
      puts "could not set climate_zone #{climate_zone}"
      OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Facility.set_climate_zone', "Cannot set the #{climate_zone} in context of this standard #{standard_to_be_used}")
      return false
    end

    # set weather file and climate zone from EPW file
    # @param climate_zone [String]
    # @param epw_file_path [String]
    # @param standard_to_be_used [String]
    # @param latitude [String]
    # @param longitude [String]
    # @param ddy_file [String]
    def set_weather_and_climate_zone_from_epw(climate_zone, epw_file_path, standard_to_be_used, latitude, longitude, ddy_file = nil)
      epw_file = OpenStudio::EpwFile.new(epw_file_path)

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
      weather_file.setString(10, "file:///#{epw_file.path}")

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

      OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.set_weater_and_climate_zone', "city is #{epw_file.city}. State is #{epw_file.stateProvinceRegion}")

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
          OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Facility.set_weater_and_climate_zone', 'More than one ddy file in the EPW directory')
          return false
        end
        if ddy_files.empty?
          OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Facility.set_weater_and_climate_zone', 'could not find the ddy file in the EPW directory')
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
        if d.name.get =~ ddy_list
          OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.set_weater_and_climate_zone', "Adding object #{d.name}")

          # add the object to the existing model
          @model.addObject(d.clone)
        end
      end
    end

    # get stat file path
    # @param epw_file [String]
    # @return [String]
    def get_stat_file(epw_file)
      # Add SiteWaterMainsTemperature -- via parsing of STAT file.
      stat_file = "#{File.join(File.dirname(epw_file.path.to_s), File.basename(epw_file.path.to_s, '.*'))}.stat"
      unless File.exist? stat_file
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.set_weater_and_climate_zone', 'Could not find STAT file by filename, looking in the directory')
        stat_files = Dir["#{File.dirname(epw_file.path.to_s)}/*.stat"]
        if stat_files.size > 1
          OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Facility.set_weater_and_climate_zone', 'More than one stat file in the EPW directory')
          return nil
        end
        if stat_files.empty?
          OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Facility.set_weater_and_climate_zone', 'Cound not find the stat file in the EPW directory')
          return nil
        end

        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.set_weater_and_climate_zone', "Using STAT file: #{stat_files.first}")
        stat_file = stat_files.first
      end
      unless stat_file
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Facility.set_weater_and_climate_zone', 'Could not find stat file')
        return nil
      end
      return stat_file
    end

    # add site water mains temperature -- via parsing of STAT file.
    # @param stat_file [String]
    # @return [Boolean]
    def add_site_water_mains_temperature(stat_file)
      stat_model = ::EnergyPlus::StatFile.new(stat_file)
      water_temp = @model.getSiteWaterMainsTemperature
      water_temp.setAnnualAverageOutdoorAirTemperature(stat_model.mean_dry_bulb)
      water_temp.setMaximumDifferenceInMonthlyAverageOutdoorAirTemperatures(stat_model.delta_dry_bulb)
      OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.set_weater_and_climate_zone', "mean dry bulb is #{stat_model.mean_dry_bulb}")
      return true
    end

    # generate baseline model in osm file format
    # @param standard_to_be_used [String]
    def generate_baseline_osm(standard_to_be_used)
      # this is code refactored from the "create_bar_from_building_type_ratios" measure
      # first we check is there is any data at all in this facility, aka if there is a site in the list

      # TODO: we have not really defined a good logic what happens with multiple sites, versus multiple buildings, here we just take the first building on the first site
      set_building_form_defaults

      # checking that the factions add up
      check_building_fraction

      # set building rotation
      initial_rotation = @model.getBuilding.northAxis
      if @building_rotation != initial_rotation
        @model.getBuilding.setNorthAxis(building_rotation)
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Building.generate_baseline_osm', "Set Building Rotation to #{@model.getBuilding.northAxis}")
      end
      @model.getBuilding.setName(name)

      create_bldg_space_types(@model)

      # create envelope
      # populate bar_hash and create envelope with data from envelope_data_hash and user arguments
      bar_hash = {}
      bar_hash[:length] = @length
      bar_hash[:width] = @width
      bar_hash[:num_stories_below_grade] = num_stories_below_grade.to_i
      bar_hash[:num_stories_above_grade] = num_stories_above_grade.to_i
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

      runner = OpenStudio::Ruleset::OSRunner.new
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
        bar_hash[:stories]["key #{i}"] = {story_party_walls: party_walls, story_min_multiplier: 1, story_included_in_building_area: true, below_partial_story: below_partial_story, bottom_story_ground_exposed_floor: true, top_story_exterior_exposed_roof: true}
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
    # @param ns [String]
    # @param building [:Building]
    def write_parameters_to_xml(building, ns)
      building.elements["#{ns}:PremisesName"].text = @name if !@name.nil?
      building.elements["#{ns}:YearOfConstruction"].text = @built_year if !@built_year.nil?
      building.elements["#{ns}:Ownership"].text = @ownership if !@ownership.nil?
      building.elements["#{ns}:OccupancyClassification"].text = @occupancy_classification if !@occupancy_classification.nil?
      building.elements["#{ns}:YearOfLastMajorRemodel"].text = @year_major_remodel if !@year_major_remodel.nil?
      building.elements["#{ns}:YearOfLastEnergyAudit"].text = @year_of_last_energy_audit if !@year_of_last_energy_audit.nil?
      building.elements["#{ns}:RetrocommissioningDate"].text = @year_last_commissioning if !@year_last_commissioning.nil?
      building.elements["#{ns}:BuildingAutomationSystem"].text = @building_automation_system if !@building_automation_system.nil?
      building.elements["#{ns}:HistoricalLandmark"].text = @historical_landmark if !@historical_landmark.nil?
      building.elements["#{ns}:OccupancyLevels/#{ns}:OccupancyLevel/#{ns}:OccupantQuantity"].text = @occupant_quantity if !@occupant_quantity.nil?
      building.elements["#{ns}:SpatialUnits/#{ns}:SpatialUnit/#{ns}:NumberOfUnits"].text = @number_of_units if !@number_of_units.nil?
      building.elements["#{ns}:PercentOccupiedByOwner"].text = @percent_occupied_by_owner if !@percent_occupied_by_owner.nil?

      # Add new element in the XML file
      add_user_defined_field_to_xml_file(building, ns, 'StandardTemplate', @standard_template)
      add_user_defined_field_to_xml_file(building, ns, 'BuildingRotation', @building_rotation)
      add_user_defined_field_to_xml_file(building, ns, 'FloorHeight', @floor_height)
      add_user_defined_field_to_xml_file(building, ns, 'WindowWallRatio', @wwr)
      add_user_defined_field_to_xml_file(building, ns, 'PartyWallStoriesNorth', @party_wall_stories_north)
      add_user_defined_field_to_xml_file(building, ns, 'PartyWallStoriesSouth', @party_wall_stories_south)
      add_user_defined_field_to_xml_file(building, ns, 'PartyWallStoriesEast', @party_wall_stories_east)
      add_user_defined_field_to_xml_file(building, ns, 'PartyWallStoriesWest', @party_wall_stories_west)
      add_user_defined_field_to_xml_file(building, ns, 'Width', @width)
      add_user_defined_field_to_xml_file(building, ns, 'Length', @length)
      add_user_defined_field_to_xml_file(building, ns, 'PartyWallFraction', @party_wall_fraction)
      add_user_defined_field_to_xml_file(building, ns, 'FractionArea', @fraction_area)

      write_parameters_to_xml_for_spatial_element(building, ns)
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
        peak_occupancy[@id] = @occupant_quantity.to_f
        return peak_occupancy
      end
      @building_sections.each do |section|
        peak_occupancy[section.id] = section.get_peak_occupancy.to_f if section.get_peak_occupancy
      end
      return peak_occupancy
    end

    # get floor area
    # @return [hash<string, float>]
    def get_floor_area
      floor_area = {}
      if @total_floor_area
        floor_area[@id] = @total_floor_area.to_f
      end
      @building_sections.each do |section|
        if section.get_floor_area
          floor_area[section.id] = section.get_floor_area
        end
      end
      return floor_area
    end

    attr_reader :building_rotation, :name, :length, :width, :num_stories_above_grade, :num_stories_below_grade, :floor_height, :space, :wwr, :year_of_last_energy_audit, :ownership,
                :occupancy_classification, :primary_contact_id, :year_last_commissioning, :building_automation_system, :historical_landmark, :percent_occupied_by_owner,
                :occupant_quantity, :number_of_units, :built_year, :year_major_remodel, :building_sections
  end
end
