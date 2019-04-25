module OpenStudio
  module ModelArticulation
    class Facility < WorkflowMaker
      # an array that contains all the sites
      @sites = []

      # initialize
      def initialize(facility_xml)
        # code to initialize

        @doc.elements.each("/#{@ns}:Audits/#{@ns}:Audit/#{@ns}:Sites") do |site_element|
          address = site_element.elements["#{@ns}:Address"].text.to_f
          next if address.nil?
          @sites.push(site_element)
        end
      end
      # adding a site to the facility
      def create_site
        # code to create a site
        @sites.each do |item|
          site.new(@doc)
        end
      end

      # adding the typical HVAC system to the buildings in all sites of this facility
      def add_typical_HVAC
        # code to add typical HVAC systems
      end
    end
  end
  end
