require 'rexml/document'

require_relative 'model_articulation/spatial_element'
require_relative 'makers/model_maker_level_zero'
require_relative 'makers/workflow_maker_phase_zero'

module BuildingSync
  class Translator
    # load the building sync file and chooses the correct workflow
    def initialize(path)
      @doc = nil
      @model_maker = nil
      @workflow_maker = nil

      # parse the xml
      raise "File '#{path}' does not exist" unless File.exist?(path)
      File.open(path, 'r') do |file|
        @doc = REXML::Document.new(file)
      end

      # test for the namespace
      @ns = 'auc'
      @doc.root.namespaces.each_pair do |k,v|
        @ns = k if /bedes-auc/.match(v)
      end

      # validate the doc
      facilities = []
      @doc.elements.each("#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility/") { |facility| facilities << facility }
      raise 'BuildingSync file must have exactly 1 facility' if facilities.size != 1

      # choose the correct model maker based on xml
      choose_model_maker

      # choose the correct workflow maker based on xml
      choose_workflow_maker
    end

    def write_osm(dir)
      @model_maker.generate_baseline(dir)
    end

    def writeOSWs(dir)
      @workflow_maker.writeOSWs(dir)
    end

    private

    def choose_model_maker
      # for now there is only one model maker
      @model_maker = ModelMakerLevelZero.new(@doc, @ns)
    end

    def choose_workflow_maker
      # for now there is only one workflow maker
      @workflow_maker = PhaseZeroWorkflowMaker.new(@doc, @ns)
    end
  end
end
