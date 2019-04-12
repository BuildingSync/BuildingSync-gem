module OpenStudio
  module ModelArticulation
    class BuildingSubsection
      type = null
      faction_area = null
      num_of_units = null

      # initialize
      def initialize(building_subsection_xml, standard, model)
        # code to initialize
      end

      # create geometry
      def create_geoemtry
        # creating the geometry
        #
        # deal with party walls. etc
        #
        # create bar
        #
        # check expected floor areas against actual
      end

      # create space types
      def create_space_types
        # create space types from subsection type
      end
    end
  end
end

