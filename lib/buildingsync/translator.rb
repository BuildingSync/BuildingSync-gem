# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2021, Alliance for Sustainable Energy, LLC.
# BuildingSync(R), Copyright (c) 2015-2021, Alliance for Sustainable Energy, LLC.
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
require 'buildingsync/constants'
require 'buildingsync/generator'

require_relative 'model_articulation/spatial_element'
require_relative 'makers/workflow_maker'
require_relative 'selection_tool'
require_relative 'extension'

module BuildingSync
  # Translator class
  class Translator < WorkflowMaker
    include BuildingSync::Helper
    # load the building sync file
    # @param xml_file_path [String]
    # @param output_dir [String]
    # @param epw_file_path [String] if provided, full/path/to/my.epw
    # @param standard_to_be_used [String]
    # @param validate_xml_file_against_schema [Boolean]
    def initialize(xml_file_path, output_dir, epw_file_path = nil, standard_to_be_used = ASHRAE90_1, validate_xml_file_against_schema = true)
      @schema_version = nil
      @xml_file_path = xml_file_path
      @output_dir = output_dir
      @standard_to_be_used = standard_to_be_used
      @epw_path = epw_file_path

      @results_gathered = false
      @final_xml_prepared = false

      # to further reduce the log messages we can change the log level with this command
      # OpenStudio::Logger.instance.standardOutLogger.setLogLevel(OpenStudio::Error)
      # Open a log for the library
      log_file = OpenStudio::FileLogSink.new(OpenStudio::Path.new("#{output_dir}/in.log"))
      log_file.setLogLevel(OpenStudio::Info)

      # parse the xml
      if !File.exist?(xml_file_path)
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Translator.initialize', "File '#{xml_file_path}' does not exist")
        raise "File '#{xml_file_path}' does not exist" unless File.exist?(xml_file_path)
      end

      doc = help_load_doc(xml_file_path)

      @schema_version = doc.root.attributes['version']
      if @schema_version.nil?
        @schema_version = '2.0.0'
      end

      # test for the namespace
      ns = 'auc'
      doc.root.namespaces.each_pair do |k, v|
        ns = k if /bedes-auc/.match(v)
      end

      if validate_xml_file_against_schema
        validate_xml
      else
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Translator.initialize', "File '#{xml_file_path}' was not validated against the BuildingSync schema")
        puts "File '#{xml_file_path}' was not validated against the BuildingSync schema"
      end

      super(doc, ns)
    end

    # Validate the xml file against the schema
    # using the SelectionTool
    def validate_xml
      # we wil try to validate the file, but if it fails, we will not cancel the process, but log an error

      selection_tool = BuildingSync::SelectionTool.new(@xml_file_path, @schema_version)
      if !selection_tool.validate_schema
        raise "File '#{@xml_file_path}' does not valid against the BuildingSync schema"
      else
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Translator.initialize', "File '#{@xml_file_path}' is valid against the BuildingSync schema")
        puts "File '#{@xml_file_path}' is valid against the BuildingSync schema"
      end
    rescue StandardError
      OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Translator.initialize', "File '#{@xml_file_path}' does not valid against the BuildingSync schema")
    end

    # @see WorkflowMaker.setup_and_sizing_run
    # @param ddy_file [String]
    def setup_and_sizing_run(ddy_file = nil)
      super(@output_dir, @epw_path, @standard_to_be_used, ddy_file)
    end

    # write osws - write all workflows into osw files
    def write_osws(only_cb_modeled = false)
      super(@output_dir, only_cb_modeled)
    end

    # gather results from simulated scenarios, for all or just the baseline scenario
    # @param year_val [Integer] year to use when processing monthly results as TimeSeries elements
    # @param baseline_only [Boolean] whether to only process the Baseline (or current building modeled) Scenario
    def gather_results(year_val = Date.today.year, baseline_only = false)
      @results_gathered = true
      return super(year_val, baseline_only)
    end

    # run osws - running all scenario simulations
    # @param runner_options [hash]
    def run_osws(only_cb_modeled = false, runner_options = { run_simulations: true, verbose: false, num_parallel: 7, max_to_run: Float::INFINITY })
      super(@output_dir, only_cb_modeled, runner_options)
    end

    # write parameters to xml file
    def prepare_final_xml
      if @results_gathered
        super
      else
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Translator.prepare_final_xml', 'All results have not yet been gathered.')
        super
      end
      @final_xml_prepared = true
    end

    # save xml that includes the results
    # @param file_name [String]
    def save_xml(file_name = 'results.xml')
      output_file = File.join(@output_dir, file_name)
      if @final_xml_prepared
        super(output_file)
      else
        puts 'Prepare final file before attempting to save (translator.prepare_final_xml)'
      end
    end

    attr_accessor :doc, :results_gathered, :final_xml_prepared, :ns
  end
end
