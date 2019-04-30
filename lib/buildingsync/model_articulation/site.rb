require_relative 'building'
module BuildingSync
  class Site
    # an array that contains all the buildings
    @buildings = []

    # initialize
    def initialize(build_element)
      # code to initialize
      # TM: just use the XML snippet to search for the buildings on the site
      read_xml(build_element)
    end

    # adding a site to the facility
    def read_xml(build_element)
      # code to create a building
      build_element.elements.each("/#{@ns}:Buildings") do |buildings_element|
        buildingId = buildings_element.elements["#{@ns}:Building"].text.to_f
        next if buildingId.nil?
        @buildings.push(Building.new(REXML::Elements.new(buildings_element)))
      end
    end

    # set building form defaults for the first building
    def set_building_form_defaults
      @buildings[0].set_building_form_defaults
    end

    def check_building_faction
      @buildings.each.check_building_faction do |building|
        if building.check_building_faction == false
          return false
        end
      end
      true
    end
  end
end

