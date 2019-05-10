# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2019, Alliance for Sustainable Energy, LLC.
# BuildingSync(R), Copyright (c) 2015-2019, Alliance for Sustainable Energy, LLC.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER(S) AND ANY CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER(S), ANY CONTRIBUTORS, THE
# UNITED STATES GOVERNMENT, OR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF
# THEIR EMPLOYEES, BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# *******************************************************************************
require 'rexml/document'

require_relative 'model_articulation/spatial_element'
require_relative 'makers/model_maker_level_zero'
require_relative 'makers/workflow_maker_phase_zero'

module BuildingSync
  class Translator
    # load the building sync file and chooses the correct workflow
    def initialize(xmlFilePath, outputDir, bWorkflow)
      @doc = nil
      @model_maker = nil
      @workflow_maker = nil
      @outputDir = outputDir

      # Open a log for the library
      logFile = OpenStudio::FileLogSink.new(OpenStudio::Path.new("#{outputDir}/in.log"))
      logFile.setLogLevel(OpenStudio::Debug)

      # parse the xml
      if !File.exist?(xmlFilePath)
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Translator.initialize', "File '#{xmlFilePath}' does not exist")
        raise "File '#{xmlFilePath}' does not exist" unless File.exist?(xmlFilePath)
      end

      File.open(xmlFilePath, 'r') do |file|
        @doc = REXML::Document.new(file)
      end

      # test for the namespace
      @ns = 'auc'
      @doc.root.namespaces.each_pair do |k, v|
        @ns = k if /bedes-auc/.match(v)
      end

      # validate the doc
      facilities = []
      @doc.elements.each("#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility/") { |facility| facilities << facility }
      # raise 'BuildingSync file must have exactly 1 facility' if facilities.size != 1
      if facilities.size != 1
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Translator.initialize', 'BuildingSync file must have exactly 1 facility')
        raise 'BuildingSync file must have exactly 1 facility'
      end

      # choose the correct model maker based on xml
      choose_model_maker

      # choose the correct workflow maker based on xml
      choose_workflow_maker if bWorkflow
    end

    def write_osm
      @model_maker.generate_baseline(@outputDir)
    end

    def writeOSWs
      @workflow_maker.writeOSWs(@outputDir)
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
