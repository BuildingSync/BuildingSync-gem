require_relative 'building'
module BuildingSync
  class Site < SpecialElement

    # initialize
    def initialize(build_element, ns)
      # code to initialize
      # an array that contains all the buildings
      @buildings = []
      # TM: just use the XML snippet to search for the buildings on the site
      read_xml(build_element, ns)
    end

    # adding a site to the facility
    def read_xml(build_element, ns)
      # check occupancy type at the site level
      @occupancy_type = read_occupancy_type(build_element, nil, ns)
      # check floor areas at the site level
      @total_floor_area = read_floor_areas(build_element, nil, ns)
      # code to create a building
      build_element.elements.each("#{ns}:Buildings/#{ns}:Building") do |buildings_element|
        @buildings.push(Building.new(buildings_element, @occupancy_type, @total_floor_area, ns))
      end
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
      @buildings.each(&:generate_baseline_osm)
    end

    def write_osm(dir)
      @buildings.each do |building|
        building.write_osm(dir)
      end
    end
  end
end

