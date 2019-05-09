require_relative 'building'
module BuildingSync
  class Site < SpecialElement

    # initialize
    def initialize(build_element, ns)
      # code to initialize
      # an array that contains all the buildings
      @buildings = []
      @climate_zone = nil
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
    end

    def read_climate_zone(build_element, ns)
      if build_element.elements["#{ns}:ClimateZoneType/#{ns}:ASHRAE"]
        @climate_zone = build_element.elements["#{ns}:ClimateZoneType/#{ns}:ASHRAE/#{ns}:ClimateZone"].text
      else
        @climate_zone = nil
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

    def generate_baseline_osm
      if @buildings.count == 0
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Site.generate_baseline_osm', 'There is no building attached to this site in your BuildingSync file.')
        raise 'Error: There is no building attached to this site in your BuildingSync file.'
      else if @buildings.count > 1
             OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Site.generate_baseline_osm', "There are more than one (#{@buildings.count}) buildings attached to this site in your BuildingSync file.")
             raise "Error: There are more than one (#{@buildings.count}) buildings attached to this site in your BuildingSync file."
           end
      end
      @buildings.each do |building|
        building.set_weater_and_climate_zone(@weather_file_name, @climate_zone)
        building.generate_baseline_osm
      end
    end

    def write_osm(dir)
      @buildings.each do |building|
        building.write_osm(dir)
      end
    end
  end
end

