require_relative 'site'
require_relative '../Helpers/os_lib_model_generation_bricr'
require_relative '../Helpers/os_lib_geometry'

module BuildingSync
  class Facility
    include OsLib_ModelGenerationBRICR
    include OsLib_Geometry

    # initialize
    def initialize(facility_xml, ns)
      # code to initialize
      # an array that contains all the sites
      @sites = []
      # reading the xml
      read_xml(facility_xml, ns)
    end

    # adding a site to the facility
    def read_xml(facility_xml, ns)
      # puts facility_xml.to_a
      facility_xml.elements.each("#{ns}:Sites/#{ns}:Site") do |site_element|
        @sites.push(Site.new(site_element, ns))
      end
    end

    # adding the typical HVAC system to the buildings in all sites of this facility
    def create_building_system
      # TODO: code to add typical HVAC systems
    end

    # generating the OpenStudio model based on the imported BuildingSync Data
    def generate_baseline_osm
      if @sites.count == 0
        puts 'Error: There are no sites attached to this facility in your BuildingSync file.'
        raise 'Error: There are no sites attached to this facility in your BuildingSync file.'
      else if @sites.count > 1
             puts "Error: There are more than one (#{@sites.count}) sites attached to this facility in your BuildingSync file."
             raise "Error: There are more than one (#{@sites.count}) sites attached to this facility in your BuildingSync file."
           else
             puts "Info: There is/are #{@sites.count} sites in this facility."
           end
      end
      @sites.each(&:generate_baseline_osm)
    end

    def write_osm(dir)
      @sites.each do |site|
        site.write_osm(dir)
      end
    end
  end
end
