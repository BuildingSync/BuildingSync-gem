
require 'rexml/document'

require_relative 'model_articulation/spatial_element'
require_relative 'translators/translator_level_zero'
#require_relative 'workflows/phase_zero_workflow_maker'

module BuildingSync
  class Translator
    # load the building sync file and chooses the correct workflow
    def initialize(path)
      @doc = nil
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

      # choose the correct workflow maker based on xml
      chooseWorkflowMaker
    end

    def writeOSWs(dir)
      @workflow_maker.writeOSWs(dir)
    end

    def gatherResults(dir)
      @workflow_maker.gatherResults(dir)
    end

    def failed_scenarios()
      @workflow_maker.failed_scenarios
    end

    def saveXML(filename)
      @workflow_maker.saveXML(filename)
    end

    private

    def chooseWorkflowMaker
      # for now there is only one workflow maker
      @workflow_maker = TranslatorLevelZero.new(@doc, @ns)
    end
  end
end
