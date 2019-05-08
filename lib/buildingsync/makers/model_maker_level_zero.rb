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
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.ModelMakerLevelZero.generate_baseline', 'There are no facilities in your BuildingSync file.')
        raise 'Error: There are no facilities in your BuildingSync file.'
      else if @facilities.count > 1
             OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.ModelMakerLevelZero.generate_baseline', "There are more than one (#{@facilities.count})facilities in your BuildingSync file. Only one if supported right now")
             raise "Error: There are more than one (#{@facilities.count})facilities in your BuildingSync file. Only one if supported right now"
           end
      end

      @facilities.each(&:generate_baseline_osm)
      write_osm(dir)
    end

    private

    def write_osm(dir)
      @facilities.each do |facility|
        facility.write_osm(dir)
      end
    end
  end
end
