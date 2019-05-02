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

    # set building form defaults for the first building
    def read_building_form_defaults
      @buildings[0].read_building_form_defaults
    end

    def check_building_faction
      @buildings.each do |building|
        if building.check_building_faction == false
          return false
        end
      end
      true
    end

    attr_reader :buildings
  end
end

