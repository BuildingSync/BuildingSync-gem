require 'fileutils'
require 'json'

module BuildingSync
  # base class for objects that will configure model maker based on building sync files
  class ModelMaker
    def initialize(doc, ns)
      @doc = doc
      @ns = ns
    end

    def generate_baseline; end

    def write_osm; end
  end
end
