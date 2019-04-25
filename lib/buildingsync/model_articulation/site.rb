module OpenStudio
  module ModelArticulation
    class Site
      # an array that contains all the buildings
      @building = []

      # initialize
      def initialize(doc)
        # code to initialize
        @doc.elements.each("/#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility/#{@ns}:Sites/#{@ns}:Site/#{@ns}:Buildings") do |buildings_element|
          buildingId = buildings_element.elements["#{@ns}:Building"].text.to_f
          next if buildingId.nil?
          @building.push(buildings_element)
        end
      end

      # adding a site to the facility
      def create_building
        # code to create a building
        @building.each do |singleBuilding|
          building.new(singleBuilding)
        end
      end
    end
  end
end

