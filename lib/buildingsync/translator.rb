# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
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
        @schema_version = '2.4.0'
      end

      # test for the namespace
      ns = 'auc'
      doc.root.namespaces.each_pair do |k, v|
        ns = k if /bedes-auc/.match(v)
      end

      if validate_xml_file_against_schema
        validate_xml
      else
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Translator.initialize', "File '#{xml_file_path}' was not validated against the BuildingSync schema version #{@schema_version}")
        puts "File '#{xml_file_path}' was not validated against the BuildingSync schema version #{@schema_version}"
      end

      super(doc, ns, @standard_to_be_used)
    end

    # Validate the xml file against the schema
    # using the SelectionTool
    def validate_xml
      # we wil try to validate the file, but if it fails, we will not cancel the process, but log an error

      selection_tool = BuildingSync::SelectionTool.new(@xml_file_path, @schema_version)
      if !selection_tool.validate_schema
        raise "File '#{@xml_file_path}' does not valid against the BuildingSync schema"
      else
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Translator.initialize', "File '#{@xml_file_path}' is valid against the BuildingSync schema version #{@schema_version}")
        puts "File '#{@xml_file_path}' is valid against the BuildingSync schema"
      end
    rescue StandardError => error
      puts "ERROR: #{error}"
      OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Translator.initialize', "File '#{@xml_file_path}' does not validate against the BuildingSync schema version #{@schema_version}")
    end

    def write_baseline_osw()
      super(@output_dir, @epw_path)
    end

    def run_baseline_osw()
      super(@output_dir)
    end

    def write_report_osws()
      super(@output_dir)
    end

    def run_report_osws()
      super(@output_dir)
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
