# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2019, Alliance for Sustainable Energy, LLC.
# BuildingSync(R), Copyright (c) 2015-2019, Alliance for Sustainable Energy, LLC.
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
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
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
require_relative 'building_subsection'
require 'openstudio/extension/core/os_lib_helper_methods'
require 'openstudio/model_articulation/os_lib_model_generation_bricr'
require 'measures/changebuildinglocation/resources/epw'
require 'measures/changebuildinglocation/resources/stat_file'

module BuildingSync
  class Building < SpatialElement
    include OsLib_ModelGenerationBRICR
    include OsLib_HelperMethods
    include EnergyPlus

    # initialize
    def initialize(build_element, site_occupancy_type, site_total_floor_area, standard_to_be_used, ns)
      @building_subsections = []
      @standard_template = nil
      @single_floor_area = 0.0
      @building_rotation = 0.0
      @floor_height = 0.0
      @wwr = 0.0
      @name = nil
      @model = nil
      # variables not used during read xml for now
      @party_wall_stories_north = 0
      @party_wall_stories_south = 0
      @party_wall_stories_west = 0
      @party_wall_stories_east = 0
      @party_wall_fraction = 0

      # code to initialize
      read_xml(build_element, site_occupancy_type, site_total_floor_area, standard_to_be_used, ns)
    end

    def num_stories
      return @num_stories_above_grade + @num_stories_below_grade
    end

    def read_xml(build_element, site_occupancy_type, site_total_floor_area, standard_to_be_used, ns)
      # floor areas
      read_floor_areas(build_element, site_total_floor_area, ns)
      # standard template
      read_standard_template_based_on_year(build_element, ns, standard_to_be_used)
      # deal with stories above and below grade
      read_stories_above_and_below_grade(build_element, ns)
      # aspect ratio
      read_aspect_ratio(build_element, ns)
      # read occupancy
      @occupancy_type = read_occupancy_type(build_element, site_occupancy_type, ns)

      build_element.elements.each("#{ns}:Subsections/#{ns}:Subsection") do |subsection_element|
        @building_subsections.push(BuildingSubsection.new(subsection_element, @standard_template, @occupancy_type, @total_floor_area, ns))
      end

      # floor areas
      @total_floor_area = read_floor_areas(build_element, site_total_floor_area, ns)

      set_bldg_and_system_type(@occupancy_type, @total_floor_area, false)

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
      else
        footprint = @total_floor_area / num_stories.to_f
      end
      @width = Math.sqrt(footprint / @ns_to_ew_ratio)
      @length = footprint / @width
    end

    def read_standard_template_based_on_year(build_element, ns, standard_to_be_used)
      built_year = build_element.elements["#{ns}:YearOfConstruction"].text.to_f

      if build_element.elements["#{ns}:YearOfLastMajorRemodel"]
        major_remodel_year = build_element.elements["#{ns}:YearOfLastMajorRemodel"].text.to_f
        built_year = major_remodel_year if major_remodel_year > built_year
      end

      if standard_to_be_used == CA_TITLE24
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
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Building.read_standard_template_based_on_year', "Unknown standard_to_be_used #{standard_to_be_used}.")
      end
      OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Building.read_standard_template_based_on_year', "Using the follwing standard for default values #{@standard_template}.")
    end

    def read_stories_above_and_below_grade(build_element, nodesap)
      if build_element.elements["#{nodesap}:FloorsAboveGrade"]
        @num_stories_above_grade = build_element.elements["#{nodesap}:FloorsAboveGrade"].text.to_f
        if @num_stories_above_grade == 0
          @num_stories_above_grade = 1.0
        end
      else
        @num_stories_above_grade = 1.0 # setDefaultValue
      end

      if build_element.elements["#{nodesap}:FloorsBelowGrade"]
        @num_stories_below_grade = build_element.elements["#{nodesap}:FloorsBelowGrade"].text.to_f
      else
        @num_stories_below_grade = 0.0 # setDefaultValue
      end
    end

    def read_aspect_ratio(build_element, nodesap)
      if build_element.elements["#{nodesap}:AspectRatio"]
        @ns_to_ew_ratio = build_element.elements["#{nodesap}:AspectRatio"].text.to_f
      else
        @ns_to_ew_ratio = 0.0 # setDefaultValue
      end
    end

    def get_building_type
      # try to get the bldg type at the building level, if it is nil then look at the first subsection
      if @bldg_type.nil?
        return @building_subsections[0].bldg_type
      else
        return @bldg_type
      end
    end

    def read_building_form_defaults
      # if aspect ratio, story height or wwr have argument value of 0 then use smart building type defaults
      building_form_defaults = building_form_defaults(get_building_type)
      if @ns_to_ew_ratio == 0.0
        @ns_to_ew_ratio = building_form_defaults[:aspect_ratio]
        OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Building.read_building_form_defaults', "0.0 value for aspect ratio will be replaced with smart default for #{get_building_type} of #{building_form_defaults[:aspect_ratio]}.")
      end
      if @floor_height == 0.0
        @floor_height = OpenStudio.convert(building_form_defaults[:typical_story], 'ft', 'm').get
        OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Building.read_building_form_defaults', "0.0 value for floor height will be replaced with smart default for #{get_building_type}of #{building_form_defaults[:typical_story]}.")
      end
      # because of this can't set wwr to 0.0. If that is desired then we can change this to check for 1.0 instead of 0.0
      if @wwr == 0.0
        @wwr = building_form_defaults[:wwr]
        OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Building.read_building_form_defaults', "0.0 value for window to wall ratio will be replaced with smart default for #{get_building_type} of #{building_form_defaults[:wwr]}.")
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
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Building.check_building_faction',  'Primary Building Type fraction of floor area must be greater than 0. Please lower one or more of the fractions for Building Type B-D.')
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
      new_hash = {}
      @building_subsections.each do |bldg_subsec|
        bldg_subsec.space_types_floor_area.each do |space_type, hash|
          new_hash[space_type] = hash
        end
      end
      return new_hash
    end

    def initialize_model
      # let's create our new empty model
      if @model.nil?
        @model = OpenStudio::Model::Model.new
      end
    end

    def get_model
      return @model
    end

    def get_building_template
      return @standard_template
    end

    def get_system_type
      if !@system_type.nil?
        return @system_type
      else
        return @building_subsections[0].system_type
      end
    end

    def set_weater_and_climate_zone(weather_file_name, standard_to_be_used, climate_zone)
      initialize_model
      # create initial condition
      if @model.getWeatherFile.city != ''
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.set_weater_and_climate_zone', "The initial weather file is #{@model.getWeatherFile.city} and the model has #{@model.getDesignDays.size} design day objects")
      else
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.set_weater_and_climate_zone', "No weather file is set. The model has #{@model.getDesignDays.size} design day objects")
      end

      # find weather file
      weather_file = nil
      if climate_zone == "1A" || climate_zone == "1B"
        weather_file = "CZ01RV2.epw"
      elsif climate_zone == "2A" || climate_zone == "2B"
        weather_file = "CZ02RV2.epw"
      elsif climate_zone == "3A" || climate_zone == "3B" || climate_zone == "3C" || climate_zone == "Climate Zone 3"
        weather_file = "CZ03RV2.epw"
      elsif climate_zone == "4A" || climate_zone == "4B" || climate_zone == "4C"
        weather_file = "CZ04RV2.epw"
      elsif climate_zone == "5A" || climate_zone == "5B" || climate_zone == "5C"
        weather_file = "CZ05RV2.epw"
      elsif climate_zone == "6A" || climate_zone == "6B"
        weather_file = "CZ06RV2.epw"
      elsif climate_zone == "7"
        weather_file = "CZ07RV2.epw"
      elsif climate_zone == "8"
        weather_file = "CZ08RV2.epw"
      else
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Facility.set_weater_and_climate_zone', "Could not find a weather file for climate zone: #{climate_zone}")
      end

      # Parse the EPW manually because OpenStudio can't handle multiyear weather files (or DATA PERIODS with YEARS)
      epw_file = OpenStudio::Weather::Epw.load(File.expand_path("../../../spec/weather/#{weather_file}", File.dirname(__FILE__)))

      weather_file = @model.getWeatherFile
      weather_file.setCity(epw_file.city)
      weather_file.setStateProvinceRegion(epw_file.state)
      weather_file.setCountry(epw_file.country)
      weather_file.setDataSource(epw_file.data_type)
      weather_file.setWMONumber(epw_file.wmo.to_s)
      weather_file.setLatitude(epw_file.lat)
      weather_file.setLongitude(epw_file.lon)
      weather_file.setTimeZone(epw_file.gmt)
      weather_file.setElevation(epw_file.elevation)
      weather_file.setString(10, "file:///#{epw_file.filename}")

      weather_name = "#{epw_file.city}_#{epw_file.state}_#{epw_file.country}"
      weather_lat = epw_file.lat
      weather_lon = epw_file.lon
      weather_time = epw_file.gmt
      weather_elev = epw_file.elevation

      # Add or update site data
      site = @model.getSite
      site.setName(weather_name)
      site.setLatitude(weather_lat)
      site.setLongitude(weather_lon)
      site.setTimeZone(weather_time)
      site.setElevation(weather_elev)

      OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.set_weater_and_climate_zone', "city is #{epw_file.city}. State is #{epw_file.state}")

      # Add SiteWaterMainsTemperature -- via parsing of STAT file.
      stat_file = "#{File.join(File.dirname(epw_file.filename), File.basename(epw_file.filename, '.*'))}.stat"
      unless File.exist? stat_file
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.set_weater_and_climate_zone', 'Could not find STAT file by filename, looking in the directory')
        stat_files = Dir["#{File.dirname(epw_file.filename)}/*.stat"]
        if stat_files.size > 1
          OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Facility.set_weater_and_climate_zone', 'More than one stat file in the EPW directory')
          return false
        end
        if stat_files.empty?
          OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Facility.set_weater_and_climate_zone', 'Cound not find the stat file in the EPW directory')
          return false
        end

        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.set_weater_and_climate_zone', "Using STAT file: #{stat_files.first}")
        stat_file = stat_files.first
      end
      unless stat_file
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Facility.set_weater_and_climate_zone', 'Could not find stat file')
        return false
      end

      stat_model = ::EnergyPlus::StatFile.new(stat_file)
      water_temp = @model.getSiteWaterMainsTemperature
      water_temp.setAnnualAverageOutdoorAirTemperature(stat_model.mean_dry_bulb)
      water_temp.setMaximumDifferenceInMonthlyAverageOutdoorAirTemperatures(stat_model.delta_dry_bulb)
      OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.set_weater_and_climate_zone', "mean dry bulb is #{stat_model.mean_dry_bulb}")

      # Remove all the Design Day objects that are in the file
      @model.getObjectsByType('OS:SizingPeriod:DesignDay'.to_IddObjectType).each(&:remove)

      # find the ddy files
      ddy_file = "#{File.join(File.dirname(epw_file.filename), File.basename(epw_file.filename, '.*'))}.ddy"
      unless File.exist? ddy_file
        ddy_files = Dir["#{File.dirname(epw_file.filename)}/*.ddy"]
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

      # Set climate zone
      climateZones = @model.getClimateZones
      if climate_zone == 'Lookup From Stat File'

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
          OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Facility.set_weater_and_climate_zone', "Can't find ASHRAE climate zone in stat file.")
        else
          climate_zone = match_data[1].to_s.strip
        end

      end

      # set climate zone
      climateZones.clear
      if standard_to_be_used == ASHRAE90_1
        climateZones.setClimateZone('ASHRAE', climate_zone)
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.set_weater_and_climate_zone', "Setting Climate Zone to #{climateZones.getClimateZones('ASHRAE').first.value}")
      elsif standard_to_be_used == CA_TITLE24
        climate_zone = climate_zone.gsub('CEC', '').strip
        climate_zone = climate_zone.gsub('Climate Zone', '').strip
        climateZones.setClimateZone('CEC', climate_zone)
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.set_weater_and_climate_zone', "Setting Climate Zone to #{climate_zone}")
      end

      # add final condition
      OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.set_weater_and_climate_zone', "The final weather file is #{@model.getWeatherFile.city} and the model has #{@model.getDesignDays.size} design day objects.")
    end

    def generate_baseline_osm(standard_to_be_used)
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

      # set building rotation
      initial_rotation = @model.getBuilding.northAxis
      if building_rotation != initial_rotation
        @model.getBuilding.setNorthAxis(building_rotation)
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Building.generate_baseline_osm', "Set Building Rotation to #{@model.getBuilding.northAxis}")
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
      if ext_roof_area > expected_roof_area && single_floor_area == 0.0 # only test if using whole-building area input
        OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Building.generate_baseline_osm', 'Roof area larger than expected, may indicate problem with inter-floor surface intersection or matching.')
        return false
      end

      # report final condition of model
      OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Building.generate_baseline_osm', "The building finished with #{@model.getSpaces.size} spaces.")

      return true
    end

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
        typical_length_facade_area = length * floor_height
        typical_width_facade_area = width * floor_height

        # top story ext wall area, may be partial story
        partial_story_multiplier = (1.0 - @num_stories_above_grade.ceil + @num_stories_above_grade)
        area_multiplier = partial_story_multiplier
        edge_multiplier = Math.sqrt(area_multiplier)
        top_story_length = length * edge_multiplier
        top_story_width = width * edge_multiplier
        top_story_length_facade_area = top_story_length * floor_height
        top_story_width_facade_area = top_story_width * floor_height

        total_exterior_wall_area = 2 * (length + width) * (@num_stories_above_grade.ceil - 1.0) * floor_height + 2 * (top_story_length + top_story_width) * floor_height
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
        else # if rotation is closest to 90 or 270 then reverse which orientation is used for length and width
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

        else # use long sides instead

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

    def write_osm(dir)
      @model.save("#{dir}/in.osm", true)
    end

    attr_reader :building_rotation, :name, :length, :width, :num_stories_above_grade, :num_stories_below_grade, :floor_height, :space, :wwr
  end
end
