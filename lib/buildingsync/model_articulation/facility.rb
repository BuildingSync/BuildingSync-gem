module BuildingSync
    class Facility < SpatialElement
      # an array that contains all the sites
      @sites = []

      # initialize
      def initialize(facility_xml)
        # code to initialize
        create_site(facility_xml)
      end

      # adding a site to the facility
      def create_site(facility_xml)
        # code to create a site
        @doc.elements.each("/#{@ns}:Sites") do |site_element|
          address = site_element.elements["#{@ns}:Address"].text.to_f
          next if address.nil?
          # TM: what is the purpose of this address check?
          # TM: do we need anything else to create the site?
          @sites.push(site.new(site_element))
        end
      end

      # adding the typical HVAC system to the buildings in all sites of this facility
      def add_typical_HVAC
        # code to add typical HVAC systems
      end
    end
end
