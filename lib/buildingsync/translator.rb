# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2020, Alliance for Sustainable Energy, LLC.
# BuildingSync(R), Copyright (c) 2015-2020, Alliance for Sustainable Energy, LLC.
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
require_relative 'makers/model_maker'
require_relative 'makers/workflow_maker'
require_relative 'selection_tool'
require_relative 'extension'

ASHRAE90_1 = 'ASHRAE90.1'.freeze
CA_TITLE24 = 'CaliforniaTitle24'.freeze

module BuildingSync
  class Translator
    # load the building sync file and initiate the model maker and workflow makers
    # @param xml_file_path [string]
    # @param output_dir [string]
    # @param epw_file_path [string]
    # @param standard_to_be_used [string]
    # @param validate_xml_file_against_schema [boolean]
    def initialize(xml_file_path, output_dir, epw_file_path = nil, standard_to_be_used = ASHRAE90_1, validate_xml_file_against_schema = true)
      @doc = nil
      @model_maker = nil
      @workflow_maker = nil
      @output_dir = output_dir
      @standard_to_be_used = standard_to_be_used
      @epw_path = epw_file_path
      @osm_baseline_path = nil
      @facilities = []

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

      if validate_xml_file_against_schema
        # we wil try to validate the file, but if it fails, we will not cancel the process, but log an error
        begin
          selection_tool = BuildingSync::SelectionTool.new(xml_file_path)
          if !selection_tool.validate_schema
            raise "File '#{xml_file_path}' does not valid against the BuildingSync schema"
          else
            OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Translator.initialize', "File '#{xml_file_path}' is valid against the BuildingSync schema")
            puts "File '#{xml_file_path}' is valid against the BuildingSync schema"
          end
        rescue StandardError
          OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Translator.initialize', "File '#{xml_file_path}' does not valid against the BuildingSync schema")
        end
      else
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Translator.initialize', "File '#{xml_file_path}' was not validated against the BuildingSync schema")
        puts "File '#{xml_file_path}' was not validated against the BuildingSync schema"
      end

      @doc = BuildingSync::Helper.read_xml_file_document(xml_file_path)

      # test for the namespace
      @ns = 'auc'
      @doc.root.namespaces.each_pair do |k, v|
        @ns = k if /bedes-auc/.match(v)
      end

      # validate the doc
      facilities_arr = []
      @doc.elements.each("#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility/") do |facility|
        facilities_arr << facility
        @facilities.push(Facility.new(facility, @ns))
      end

      # raise 'BuildingSync file must have exactly 1 facility' if facilities.size != 1
      if facilities_arr.size != 1
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Translator.initialize', 'BuildingSync file must have exactly 1 facility')
        raise 'BuildingSync file must have exactly 1 facility'
      end

      # we use only one model maker and one workflow maker that we set init here
      @model_maker = ModelMaker.new(@doc, @ns)
      @workflow_maker = WorkflowMaker.new(@doc, @ns)
    end

    # write osm - writing the model generated by the model maker in osm file format
    # @param ddy_file [string]
    def write_osm(ddy_file = nil)
      @model_maker.generate_baseline(@output_dir, @epw_path, @standard_to_be_used, ddy_file)
    end

    # gather results from simulated scenarios, for all or just the baseline scenario
    # @param dir [string]
    # @param year_val [int]
    # @param baseline_only [boolean]
    def gather_results(dir, year_val = Date.today.year, baseline_only = false)
      puts "dir: #{dir}"
      dir_split = dir.split(File::SEPARATOR)
      puts "dir_split: #{dir_split}"
      puts "dir_split[]: #{dir_split[dir_split.length - 1]}"
      if dir_split[dir_split.length - 1] == BASELINE
        dir = dir.gsub('/Baseline', '')
      end
      puts "dir: #{dir}"
      @workflow_maker.gather_results(dir, year_val, baseline_only)
    end

    # save xml that includes the results
    # @param file_name [string]
    def save_xml(file_name)
      @workflow_maker.save_xml(file_name)
    end

    # write osws - write all workflows into osw files
    def write_osws
      @workflow_maker.write_osws(@model_maker.get_facility, @output_dir)
    end

    # clear all measures
    def clear_all_measures
      @workflow_maker.clear_all_measures
    end

    # add measure path
    # @param measure_path [string]
    def add_measure_path(measure_path)
      @workflow_maker.add_measure_path(measure_path)
    end

    # insert EnergyPlus measure
    # @param measure_dir [string]
    # @param position [int]
    # @param args_hash [hash]
    def insert_energyplus_measure(measure_dir, position = 0, args_hash = {})
      @workflow_maker.insert_energyplus_measure(measure_dir, position, args_hash)
    end

    # insert model measure
    # @param measure_dir [string]
    # @param position [int]
    # @param args_hash [hash]
    def insert_model_measure(measure_dir, position = 0, args_hash = {})
      @workflow_maker.insert_model_measure(measure_dir, position, args_hash)
    end

    # insert reporting measure
    # @param measure_dir [string]
    # @param position [int]
    # @param args_hash [hash]
    def insert_reporting_measure(measure_dir, position = 0, args_hash = {})
      @workflow_maker.insert_reporting_measure(measure_dir, position, args_hash)
    end

    # get workflow from workflow maker
    def get_workflow
      @workflow_maker.get_workflow
    end

    # get space types from model
    def get_space_types
      return @model_maker.get_space_types
    end

    # get model from model maker
    def get_model
      return @model_maker.get_model
    end

    # run osm - running the baseline simulation
    # @param epw_name [string]
    # @param runner_options [hash]
    def run_osm(epw_name, runner_options = { run_simulations: true, verbose: false, num_parallel: 1, max_to_run: Float::INFINITY })
      file_name = 'in.osm'

      osm_baseline_dir = File.join(@output_dir, BASELINE)
      if !File.exist?(osm_baseline_dir)
        FileUtils.mkdir_p(osm_baseline_dir)
      end
      @osm_baseline_path = File.join(osm_baseline_dir, file_name)
      FileUtils.cp("#{@output_dir}/in.osm", osm_baseline_dir)
      puts "osm_baseline_path: #{@osm_baseline_path}"
      workflow = OpenStudio::WorkflowJSON.new
      workflow.setSeedFile(@osm_baseline_path)
      workflow.setWeatherFile(File.join('../../../weather', epw_name))
      # we need to add the report measure, too
      measure_step = OpenStudio::MeasureStep.new('openstudio_results')
      measure_steps = OpenStudio::MeasureStepVector.new
      measure_steps.push(measure_step)
      adding_workflow_failed = false
      if !workflow.setMeasureSteps(OpenStudio::MeasureType.new('ModelMeasure'), measure_steps)
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Translator.run_osm', "Could not add reporting measure to osw")
        adding_workflow_failed = true
      end

      osw_path = osm_baseline_path.gsub('.osm', '.osw')
      workflow.saveAs(File.absolute_path(osw_path.to_s))

      # this is a workaround if the above code fails
      if adding_workflow_failed
        # if this does not work we add it directly into the JSON file
        json_workflow = nil
        File.open(osw_path, 'r') do |file|
          json_workflow = JSON.parse(file.read)
          new_step = {}
          new_step['measure_dir_name'] = 'openstudio_results'
          # new_step['arguments'] = args_hash
          json_workflow['steps'].insert(0, new_step)
        end
        File.open(osw_path, 'w') do |file|
          file << JSON.generate(json_workflow)
        end
      end

      extension = OpenStudio::Extension::Extension.new
      runner = OpenStudio::Extension::Runner.new(extension.root_dir, nil, runner_options)
      return runner.run_osw(osw_path, osm_baseline_dir)
    end

    # run osws - running all scenario simulations
    # @param runner_options [hash]
    def run_osws(runner_options = {run_simulations: true, verbose: false, num_parallel: 7, max_to_run: Float::INFINITY})
      osw_files = []
      osw_sr_files = []
      Dir.glob("#{@output_dir}/**/in.osw") { |osw| osw_files << osw }
      Dir.glob("#{@output_dir}/SR/in.osw") { |osw| osw_sr_files << osw }

      runner = OpenStudio::Extension::Runner.new(dirname = Dir.pwd, bundle_without = [], options = runner_options)
      return runner.run_osws(osw_files - osw_sr_files)
    end

    # get failed scenarios
    def get_failed_scenarios
      return @workflow_maker.get_failed_scenarios
    end

    # write parameters to xml file
    # @param xml_file_path [string]
    def write_parameters_to_xml(xml_file_path = nil)
      @model_maker.write_parameters_to_xml
      save_xml(xml_file_path) if !xml_file_path.nil?
    end

    # osm file path of the baseline model
    attr_reader :osm_baseline_path
  end
end
