module OpenStudio
  module ModelArticulation
    class Building
      # an array that contains all the building subsections
      building_subsections = []
      standard = null

      # initialize
      def initialize(building_xml)
        # code to initialize
      end

      # adding a subsection to this building
      def create_building
        # code to create a subsection
        #
        # if aspect ratio, story height or wwr have argument value of 0 then use smart building type defaults
        #
        # check that sum of fractions for b,c, and d is less than 1.0 (so something is left for primary building type)
        #
        # set building rotation
        #
        # init subsections
        #
        # set building name
      end
    end
  end
end
