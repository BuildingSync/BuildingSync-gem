module OpenStudio
  module ModelArticulation
    class Site
      # an array that contains all the buildings
      @facilities = []

      # initialize
      def initialize(doc)
        # code to initialize
        @doc.elements.each("/#{@ns}:Audits/#{@ns}:Audit/#{@ns}:Sites/#{@ns}:Site/#{@ns}:Facilities") do |facilities_element|
          address = facilities_element.elements["#{@ns}:Address"].text.to_f
          next if address.nil?
          @facilities.push(facilities_element)
        end
      end

      def create_facilities
        # code to create a facility
        @facilities.each do |item|
          facility.new(@doc)
        end
      end
      # adding a site to the facility
      def create_building
        # code to create a building
      end
    end
  end
end

