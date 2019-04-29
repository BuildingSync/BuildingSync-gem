module BuildingSync
  class Facility
    # an array that contains all the sites
    @sites = []

    # initialize
    def initialize(facility_xml)
      # code to initialize
      create_site(facility_xml)

    end

    # adding a site to the facility
    def create_site(facility_xml)
      facility_xml.elements.each("/#{@ns}:Sites/#{@ns}:Site") do |site_element|
        @sites.push(Site.new(site_element))
      end
    end

    # adding the typical HVAC system to the buildings in all sites of this facility
    def add_typical_HVAC
      # code to add typical HVAC systems
    end
  end
end
