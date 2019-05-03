require_relative 'building'
module BuildingSync
  class Site
    # an array that contains all the buildings
    @buildings = []

    # initialize
    def initialize(build_element, ns)
      # code to initialize
      @buildings = []
      # TM: just use the XML snippet to search for the buildings on the site
      read_xml(build_element, ns)
    end

    # adding a site to the facility
    def read_xml(build_element, nodeSap)
      # code to create a building
      build_element.elements.each("#{nodeSap}:Buildings/#{nodeSap}:Building") do |buildings_element|
        @buildings.push(Building.new(buildings_element, nodeSap))
      end
    end

    def generate_baseline_osm
      if @buildings.count == 0
        puts 'Error: There is no building attached to this site in your BuildingSync file.'
        raise 'Error: There is no building attached to this site in your BuildingSync file.'
      else if @buildings.count > 1
             puts "Error: There are more than one (#{@buildings.count}) buildings attached to this site in your BuildingSync file."
             raise "Error: There are more than one (#{@buildings.count}) buildings attached to this site in your BuildingSync file."
           else
             puts "Info: There is/are #{@buildings.count} buildings in this site."
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

