require_relative '../model_articulation/facility'
require_relative '../model_maker'
module BuildingSync
  class ModelMakerLevelZero < ModelMaker
    def initialize(doc, ns)
      super

      @facility = []
    end

    def generate_baseline(dir)
      @doc.elements.each("/#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility") do |facility_element|
        @facility.push(Facility.new(facility_element, @ns))
      end

      if @facility.count == 0
        puts 'Error: There are no facilities in your BuildingSync file.'
      else
        puts "Info: #{@facility.count} facilities found in this BuildingSync file."
      end

      # @facilities.each(&:generate_baseline_osm)
      write_osm(dir)
    end

    private

    def write_osm(dir); end
  end
end
