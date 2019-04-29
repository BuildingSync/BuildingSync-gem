module BuildingSync
    class Site
      # an array that contains all the buildings
      @building = []

      # initialize
      def initialize(build_element)
        # code to initialize
        # TM: just use the XML snippet to search for the buildings on the site
        create_building(build_element)
      end

      # adding a site to the facility
      def create_building(build_element)
        # code to create a building
        build_element.elements.each("/#{@ns}:Buildings") do |buildings_element|
          buildingId = buildings_element.elements["#{@ns}:Building"].text.to_f
          next if buildingId.nil?
          # TM: change here to initialize the building directly as we do for facilities and sites
          @building.push(Building.new(buildings_element))
        end
      end
    end
end

