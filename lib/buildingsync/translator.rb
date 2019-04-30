require 'rexml/document'

require_relative 'model_articulation/spatial_element'
require_relative 'translators/translator_level_zero'

module BuildingSync
  class Translator
    # load the building sync file and chooses the correct workflow
    def initialize(path)
      @doc = nil
      @translator = nil

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
      choose_translator
    end

    def writeOSWs(dir)
      @translator.writeOSWs(dir)
    end

    private

    def choose_translator
      # for now there is only one workflow maker
      @translator = TranslatorLevelZero.new(@doc)
    end
  end
end
