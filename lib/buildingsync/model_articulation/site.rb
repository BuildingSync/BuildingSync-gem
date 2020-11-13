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
    # @param site_xml [REXML::Element] an element corresponding to a single auc:Site
    # @param ns [String] namespace, likely 'auc'
    def initialize(site_xml, ns)
      super(site_xml, ns)
      @site_xml = site_xml
      @ns = ns

      # an array that contains all the buildings
      @buildings = []
      @largest_building = nil
      @premises_notes = nil
      @all_set = false


      # using the XML snippet to search for the buildings on the site
      read_xml
    end

    # read xml
    def read_xml
      # first we check if the number of buildings is ok
      number_of_buildings = 0
      @site_xml.elements.each("#{@ns}:Buildings/#{@ns}:Building") do |buildings_element|
        number_of_buildings += 1
      end
      if number_of_buildings == 0
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Site.read_xml', 'There is no building attached to this site in your BuildingSync file.')
        raise 'Error: There is no building attached to this site in your BuildingSync file.'
      elsif number_of_buildings > 1
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Site.read_xml', "There is more than one (#{number_of_buildings}) building attached to this site in your BuildingSync file.")
        raise "Error: There is more than one (#{number_of_buildings}) building attached to this site in your BuildingSync file."
      end
      # check occupancy type at the site level
      @bldgsync_occupancy_type = read_bldgsync_occupancy_type(nil)
      # check floor areas at the site level
      @total_floor_area = read_floor_areas(nil)
      # read location specific values
      read_location_values
      # code to create a building
      @site_xml.elements.each("#{@ns}:Buildings/#{@ns}:Building") do |buildings_element|
        @buildings.push(Building.new(buildings_element, @bldgsync_occupancy_type, @total_floor_area, @ns))
      end
    end

    # set all function to set all parameters for each building
    def set_all
      if !@all_set
        @all_set = true
        @buildings.each(&:set_all)
      end
    end

    # build zone hash that stores zone lists for buildings and building sections
    # @return [hash<string, array<OpenStudio::Model::ThermalZone>>]
    def build_zone_hash
      return get_largest_building.build_zone_hash
    end

    # get the model
    # @return [OpenStudio::Model]
    def get_model
      return get_largest_building.get_model
    end

    # get space types
    # @return [array<OpenStudio::Model::SpaceType>]
    def get_space_types
      return get_largest_building.get_space_types
    end

    # get peak occupancy
    # @return [hash<string, float>]
    def get_peak_occupancy
      return get_largest_building.get_peak_occupancy
    end

    # get floor area
    # @return [hash<string, float>]
    def get_floor_area
      return get_largest_building.get_floor_area
    end

    # get building sections
    # @return [array<BuildingSection>]
    def get_building_sections
      return get_largest_building.building_sections
    end

    # determine the open studio standard and call the set_all function
    # @param standard_to_be_used [String]
    # @return [Standard]
    def determine_open_studio_standard(standard_to_be_used)
      set_all
      return get_largest_building.determine_open_studio_standard(standard_to_be_used)
    end

    # determine the open studio system standard and call the set_all function
    # @return [Standard]
    def determine_open_studio_system_standard
      set_all
      return Standard.build(get_building_template)
    end

    # get building template
    # @return [String]
    def get_building_template
      return get_largest_building.get_building_template
    end

    # get space types from hash
    # @param id [String]
    # @return [hash<string, array<hash<string, string>>]
    def get_space_types_from_hash(id)
      return get_largest_building.build_space_type_hash[id]
    end

    # get system type
    # @return [String]
    def get_system_type
      return get_largest_building.get_system_type
    end

    # get building type
    # @return [String]
    def get_building_type
      if @bldg_type.nil?
        return get_largest_building.get_building_type
      else
        return @bldg_type
      end
    end

    # get climate zone
    # @return [String]
    def get_climate_zone
      if @climate_zone.nil?
        return get_largest_building.get_climate_zone
      else
        return @climate_zone
      end
    end

    # get building objects
    # @return [array<Building>]
    def get_building_objects
      return @buildings
    end

    # get full path to epw file
    # @return [String]
    def get_epw_file_path
      return get_largest_building.get_epw_file_path
    end

    # get the largest building, if there are more than one building, we look for the one with the largest total florr area
    # @return [Building]
    def get_largest_building
      return @largest_building if !@largest_building.nil?
      return @buildings[0] if @buildings.count == 1
      OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Site.generate_baseline_osm', "There are more than one (#{@buildings.count}) buildings attached to this site in your BuildingSync file.")
      @largest_building = nil
      largest_floor_area = -Float::INFINITY
      @buildings.each do |building|
        if largest_floor_area < building.total_floor_area
          largest_floor_area = building.total_floor_area
          @largest_building = building
        end
      end
      OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Site.generate_baseline_osm', "The building (#{@largest_building.name}) with the largest floor area (#{largest_floor_area}) was selected.")
      puts "BuildingSync.Site.generate_baseline_osm: The building (#{@largest_building.name}) with the largest floor area (#{largest_floor_area}) m^2 was selected."
      return @largest_building
    end

    # generate baseline model in osm file format
    # @param epw_file_path [String]
    # @param standard_to_be_used [String]
    # @param ddy_file [String]
    def generate_baseline_osm(epw_file_path, standard_to_be_used, ddy_file = nil)
      set_all
      building = get_largest_building
      @climate_zone = @climate_zone_ashrae
      # for now we use the california climate zone if it is available
      @climate_zone = @climate_zone_ca_t24 if !@climate_zone_ca_t24.nil? && standard_to_be_used == CA_TITLE24
      @climate_zone = building.get_climate_zone(standard_to_be_used) if @climate_zone.nil?
      OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Site.generate_baseline_osm', 'Could not find a climate zone in the BuildingSync file.') if @climate_zone.nil?
      building.set_weather_and_climate_zone(@climate_zone, epw_file_path, standard_to_be_used, @latitude, @longitude, ddy_file, @weather_file_name, @weather_station_id, @state_name, @city_name)
      building.generate_baseline_osm(standard_to_be_used)
    end

    # write model to osm file
    # @param dir [String]
    # @return [hash<string, string>]
    def write_osm(dir)
      building = get_largest_building
      building.write_osm(dir)
      scenario_types = {}
      scenario_types['system_type'] = get_system_type
      scenario_types['bldg_type'] = get_building_type
      scenario_types['template'] = get_building_template
      return scenario_types
    end

    # write parameters to xml file
    # @param site [Site]
    # @param ns [String]
    def write_parameters_to_xml
      @site_xml.elements["#{@ns}:ClimateZoneType/#{@ns}:ASHRAE/#{@ns}:ClimateZone"].text = @climate_zone_ashrae if !@climate_zone_ashrae.nil?
      @site_xml.elements["#{@ns}:ClimateZoneType/#{@ns}:CaliforniaTitle24/#{@ns}:ClimateZone"].text = @climate_zone_ca_t24 if !@climate_zone_ca_t24.nil?
      @site_xml.elements["#{@ns}:WeatherStationName"].text = @weather_file_name if !@weather_file_name.nil?
      @site_xml.elements["#{@ns}:WeatherDataStationID"].text = @weather_station_id if !@weather_station_id.nil?
      @site_xml.elements["#{@ns}:Address/#{@ns}:City"].text = @city_name if !@city_name.nil?
      @site_xml.elements["#{@ns}:Address/#{@ns}:State"].text = @state_name if !@state_name.nil?
      @site_xml.elements["#{@ns}:Address/#{@ns}:StreetAddressDetail/#{@ns}:Simplified/#{@ns}:StreetAddress"].text = @street_address if !@street_address.nil?
      @site_xml.elements["#{@ns}:Address/#{@ns}:PostalCode"].text = @postal_code if !@postal_code.nil?
      @site_xml.elements["#{@ns}:Latitude"].text = @latitude if !@latitude.nil?
      @site_xml.elements["#{@ns}:Longitude"].text = @longitude if !@longitude.nil?

      write_parameters_to_xml_for_spatial_element

      @site_xml.elements.each("#{@ns}:Buildings/#{@ns}:Building") do |buildings_element|
        @buildings[0].write_parameters_to_xml
      end
    end
  end
end
