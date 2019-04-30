require_relative '../model_articulation/facility'
require_relative '../model_maker'
module BuildingSync
  class ModelMakerLevelZero < ModelMaker
    def initialize(doc, ns)
      super

      @facility = []
    end

    def generate_baseline_osm
      @doc.elements.each("/#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility") do |facility_element|
        @facility.push(Facility.new(facility_element.to_s))
      end

      if @facility.count == 0
        puts 'Error: There are no facilities in your BuildingSync file.'
      else
        puts 'This is working fine.'
      end

      # @facilities.each(&:generate_baseline_osm)
    end

    def write_osm; end
  end
end
