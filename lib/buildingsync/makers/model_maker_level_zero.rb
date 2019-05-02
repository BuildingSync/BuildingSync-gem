require_relative '../model_articulation/facility'
require_relative '../model_maker'
module BuildingSync
  class ModelMakerLevelZero < ModelMaker
    def initialize(doc, ns)
      super

      @facilities = []
    end

    def generate_baseline(dir)
      @doc.elements.each("/#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility") do |facility_element|
        @facilities.push(Facility.new(facility_element, @ns))
      end

      if @facilities.count == 0
        puts 'Error: There are no facilities in your BuildingSync file.'
      else
        puts "Info: #{@facilities.count} facilities found in this BuildingSync file."
      end

      @facilities.each(&:generate_baseline_osm)
      write_osm(dir)
    end

    private

    def write_osm(dir)
      @facilities.each do |facility|
        facility.model.save("#{dir}/#{Test}.osm", true)
      end
    end
  end
end
