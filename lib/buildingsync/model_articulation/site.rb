# frozen_string_literal: true

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
require_relative 'building'
module BuildingSync
  # Site class
  class Site < LocationElement
    # initialize
    # @param base_xml [REXML::Element] an element corresponding to a single auc:Site
    # @param ns [String] namespace, likely 'auc'
    def initialize(base_xml, ns)
      super(base_xml, ns)
      @base_xml = base_xml
      @ns = ns

      @building = nil
      @all_set = false

      # using the XML snippet to search for the buildings on the site
      read_xml
    end

    # read xml
    def read_xml
      # first we check if the number of buildings is ok
      building_xml_temp = @base_xml.get_elements("#{@ns}:Buildings/#{@ns}:Building")

      if building_xml_temp.nil? || building_xml_temp.empty?
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Site.read_xml', "Site with ID: #{xget_id} has no Building elements.  Cannot initialize Site.")
        raise StandardError, "Site with ID: #{xget_id} has no Building elements.  Cannot initialize Site."
      elsif building_xml_temp.size > 1
        @building_xml = building_xml_temp.first
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Site.read_xml', "Site ID: #{xget_id}. There is more than one (#{building_xml_temp.size}) Building elements.  Only the first Building will be considered (ID: #{@building_xml.attributes['ID']}.")
      else
        @building_xml = building_xml_temp.first
      end

      # read other data
      @total_floor_area = read_floor_areas(nil)
      read_location_values

      @building = BuildingSync::Building.new(@building_xml, xget_text('OccupancyClassification'), @total_floor_area, @ns)
    end

    # set all function to set all parameters for each building
    def set_all
      if !@all_set
        @all_set = true
        @building.set_all
      end
    end

    # build zone hash that stores zone lists for buildings and building sections
    # @return [hash<string, array<OpenStudio::Model::ThermalZone>>]
    def build_zone_hash
      return @building.build_zone_hash
    end

    # get the model
    # @return [OpenStudio::Model]
    def get_model
      return @building.get_model
    end

    # get space types
    # @return [array<OpenStudio::Model::SpaceType>]
    def get_space_types
      return @building.get_space_types
    end

    # get peak occupancy
    # @return [hash<string, float>]
    def get_peak_occupancy
      return @building.get_peak_occupancy
    end

    # get floor area
    # @return [hash<string, float>]
    def get_floor_area
      return @building.get_floor_area
    end

    # get building sections
    # @return [array<BuildingSection>]
    def get_building_sections
      return @building.building_sections
    end

    # determine the open studio standard and call the set_all function
    # @param standard_to_be_used [String]
    # @return [Standard]
    def determine_open_studio_standard(standard_to_be_used)
      set_all
      return @building.determine_open_studio_standard(standard_to_be_used)
    end

    # determine the open studio system standard and call the set_all function
    # @return [Standard]
    def determine_open_studio_system_standard
      set_all
      return Standard.build(get_standard_template)
    end

    # get @standard_template
    # @return [String]
    def get_standard_template
      return @building.get_standard_template
    end

    # get space types from hash
    # @param id [String]
    # @return [hash<string, array<hash<string, string>>]
    def get_space_types_from_hash(id)
      return @building.build_space_type_hash[id]
    end

    # get system type
    # @return [String]
    def get_system_type
      return @building.get_system_type
    end

    # get building type
    # @return [String]
    def get_building_type
      if @standards_building_type.nil?
        return @building.get_building_type
      else
        return @standards_building_type
      end
    end

    # get climate zone
    # @return [String]
    def get_climate_zone
      if @climate_zone.nil?
        return @building.get_climate_zone
      else
        return @climate_zone
      end
    end

    # get building
    # @return [Array<BuildingSync::Building>]
    def get_building
      return @building
    end

    # get full path to epw file
    # @return [String]
    def get_epw_file_path
      return @building.get_epw_file_path
    end

    # generate baseline model in osm file format
    # @param epw_file_path [String]
    # @param standard_to_be_used [String]
    # @param ddy_file [String]
    def generate_baseline_osm(epw_file_path, standard_to_be_used, ddy_file = nil)
      set_all
      @climate_zone = @climate_zone_ashrae
      # for now we use the california climate zone if it is available
      @climate_zone = @climate_zone_ca_t24 if !@climate_zone_ca_t24.nil? && standard_to_be_used == CA_TITLE24
      @climate_zone = @building.get_climate_zone(standard_to_be_used) if @climate_zone.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Site.generate_baseline_osm', 'Could not find a climate zone in the BuildingSync file.') if @climate_zone.nil?
      lat = @building.xget_text('Latitude').nil? ? xget_text('Latitude') : @building.xget_text('Latitude')
      long = @building.xget_text('Longitude').nil? ? xget_text('Longitude') : @building.xget_text('Longitude')
      weather_station_name = @building.xget_text('WeatherStationName').nil? ? xget_text('WeatherStationName') : @building.xget_text('WeatherStationName')
      weather_station_id = @building.xget_text('WeatherDataStationID').nil? ? xget_text('WeatherDataStationID') : @building.xget_text('WeatherDataStationID')
      @building.set_weather_and_climate_zone(@climate_zone, epw_file_path, standard_to_be_used, lat, long, ddy_file, weather_station_name, weather_station_id, @state_name, @city_name)
      @building.generate_baseline_osm
    end

    # write model to osm file
    # @param dir [String]
    # @return [hash<string, string>]
    def write_osm(dir)
      @building.write_osm(dir)
      scenario_types = {}
      scenario_types['system_type'] = get_system_type
      scenario_types['bldg_type'] = get_building_type
      scenario_types['template'] = get_standard_template
      return scenario_types
    end

    # write parameters to xml file
    # @param site [Site]
    # @param ns [String]
    def prepare_final_xml
      @base_xml.elements["#{@ns}:ClimateZoneType/#{@ns}:ASHRAE/#{@ns}:ClimateZone"].text = @climate_zone_ashrae if !@climate_zone_ashrae.nil?
      @base_xml.elements["#{@ns}:ClimateZoneType/#{@ns}:CaliforniaTitle24/#{@ns}:ClimateZone"].text = @climate_zone_ca_t24 if !@climate_zone_ca_t24.nil?

      @base_xml.elements["#{@ns}:Address/#{@ns}:City"].text = @city_name if !@city_name.nil?
      @base_xml.elements["#{@ns}:Address/#{@ns}:State"].text = @state_name if !@state_name.nil?

      # TODO: probably set these as UDFs from actual openstudio model
      @base_xml.elements["#{@ns}:WeatherStationName"].text = @weather_file_name if !@weather_file_name.nil?
      @base_xml.elements["#{@ns}:WeatherDataStationID"].text = @weather_station_id if !@weather_station_id.nil?

      prepare_final_xml_for_spatial_element

      @building.prepare_final_xml
    end
  end
end
