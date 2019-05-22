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
require_relative 'building'
module BuildingSync
  class Site < SpatialElement

    # initialize
    def initialize(build_element, ns)
      # code to initialize
      # an array that contains all the buildings
      @buildings = []
      @climate_zone_ashrae = nil
      @climate_zone_ca_t24 = nil
      @weather_file_name = nil
      # TM: just use the XML snippet to search for the buildings on the site
      read_xml(build_element, ns)
    end

    # adding a site to the facility
    def read_xml(build_element, ns)
      # check occupancy type at the site level
      @occupancy_type = read_occupancy_type(build_element, nil, ns)
      # check floor areas at the site level
      @total_floor_area = read_floor_areas(build_element, nil, ns)
      # read in the ASHRAE climate zone
      read_climate_zone(build_element, ns)
      # read in the weather station name
      read_weather_file_name(build_element, ns)
      # code to create a building
      build_element.elements.each("#{ns}:Buildings/#{ns}:Building") do |buildings_element|
        @buildings.push(Building.new(buildings_element, @occupancy_type, @total_floor_area, ns))
      end
      if @buildings.count == 0
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Site.generate_baseline_osm', 'There is no building attached to this site in your BuildingSync file.')
        raise 'Error: There is no building attached to this site in your BuildingSync file.'
      else if @buildings.count > 1
             OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Site.generate_baseline_osm', "There are more than one (#{@buildings.count}) buildings attached to this site in your BuildingSync file.")
             raise "Error: There are more than one (#{@buildings.count}) buildings attached to this site in your BuildingSync file."
           end
      end
    end

    def read_climate_zone(build_element, ns)
      if build_element.elements["#{ns}:ClimateZoneType/#{ns}:ASHRAE"]
        @climate_zone_ashrae = build_element.elements["#{ns}:ClimateZoneType/#{ns}:ASHRAE/#{ns}:ClimateZone"].text
      else
        @climate_zone_ashrae = nil
      end
      if build_element.elements["#{ns}:ClimateZoneType/#{ns}:CaliforniaTitle24"]
        @climate_zone_ca_t24 = build_element.elements["#{ns}:ClimateZoneType/#{ns}:CaliforniaTitle24/#{ns}:ClimateZone"].text
      else
        @climate_zone_ca_t24 = nil
      end
    end

    def read_weather_file_name(build_element, ns)
      if build_element.elements["#{ns}:WeatherStationName"]
        @weather_file_name = build_element.elements["#{ns}:WeatherStationName"].text
      else
        @weather_file_name = nil
      end
    end

    def get_model
      return @buildings[0].get_model
    end

    def get_building_template
      return @buildings[0].get_building_template
    end

    def get_system_type
      return @buildings[0].get_system_type
    end

    def get_building_type
      if @bldg_type.nil?
        return @buildings[0].get_building_type
      else
        return @bldg_type
      end
    end

    def generate_baseline_osm(standard_to_be_used)
      @buildings.each do |building|
        climate_zone = @climate_zone_ashrae
        # for now we use the california climate zone if it is available
        if !@climate_zone_ca_t24.nil?
          climate_zone = @climate_zone_ca_t24
        end
        building.set_weater_and_climate_zone(@weather_file_name, climate_zone)
        building.generate_baseline_osm(standard_to_be_used)
      end
    end

    def write_osm(dir)
      @buildings.each do |building|
        building.write_osm(dir)
      end
      scenario_types = {}
      scenario_types['system_type'] = get_system_type
      scenario_types['bldg_type'] = get_building_type
      scenario_types['template'] = get_building_template
      return scenario_types
    end
  end


end

