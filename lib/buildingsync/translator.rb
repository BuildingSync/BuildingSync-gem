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
require_relative 'selection_tool'
require_relative 'extension'

ASHRAE90_1 = 'ASHRAE90.1'.freeze
CA_TITLE24 = 'CaliforniaTitle24'.freeze

module BuildingSync
  class Translator
    # load the building sync file and chooses the correct workflow
    def initialize(xml_file_path, output_dir, epw_file_path = nil, standard_to_be_used = ASHRAE90_1, validate_xml_file_against_schema = true)
      @doc = nil
      @model_maker = nil
      @workflow_maker = nil
      @output_dir = output_dir
      @scenario_types = nil
      @standard_to_be_used = standard_to_be_used
      @epw_path = epw_file_path
      @osm_baseline_path = nil

      # to further reduce the log messages we can change the log level with this command
      # OpenStudio::Logger.instance.standardOutLogger.setLogLevel(OpenStudio::Error)
      # Open a log for the library
      logFile = OpenStudio::FileLogSink.new(OpenStudio::Path.new("#{output_dir}/in.log"))
      logFile.setLogLevel(OpenStudio::Info)

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

      File.open(xml_file_path, 'r') do |file|
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
    end

    def write_osm(ddy_file = nil)
      @model_maker.generate_baseline(@output_dir, @epw_path, @standard_to_be_used, ddy_file)
    end

    def gather_results(dir, baseline_only = false)
      puts "dir: #{dir}"
      dir_split = dir.split(File::SEPARATOR)
      puts "dir_split: #{dir_split}"
      puts "dir_split[]: #{dir_split[dir_split.length - 1]}"
      if(dir_split[dir_split.length - 1] == "Baseline")
        dir = dir.gsub('/Baseline','')
      end
      puts "dir: #{dir}"
      @model_maker.gather_results(dir, baseline_only)
    end

    def save_xml(filename)
      @model_maker.saveXML(filename)
    end

    def write_osws
      @model_maker.write_osws(@output_dir)
    end

    def clear_all_measures
      @model_maker.clear_all_measures
    end

    def add_measure_path(measure_path)
      @model_maker.add_measure_path(measure_path)
    end

    def insert_energyplus_measure(measure_dir, position = 0, args_hash = {})
      @model_maker.insert_energyplus_measure(measure_dir, position, args_hash)
    end

    def insert_model_measure(measure_dir, position = 0, args_hash = {})
      @model_maker.insert_model_measure(measure_dir, position, args_hash)
    end

    def insert_reporting_measure(measure_dir, position = 0, args_hash = {})
      @model_maker.insert_reporting_measure(measure_dir, position, args_hash)
    end

    def get_workflow
      @model_maker.get_workflow
    end

    def get_space_types
      return @model_maker.get_space_types
    end

    def get_model
      return @model_maker.get_model
    end

    def run_osm(epw_name)
      file_name = 'in.osm'

      osm_baseline_dir = File.join(@output_dir, 'Baseline')
      if !File.exist?(osm_baseline_dir)
        FileUtils.mkdir_p(osm_baseline_dir)
      end
      @osm_baseline_path = File.join(osm_baseline_dir, file_name)
      FileUtils.cp("#{@output_dir}/in.osm", osm_baseline_dir)
      puts "osm_baseline_path: #{@osm_baseline_path}"
      workflow = OpenStudio::WorkflowJSON.new
      workflow.setSeedFile(@osm_baseline_path)
      workflow.setWeatherFile(File.join('../../../weather', epw_name))
      # add open studio results measure
    #  common_measures_instance = OpenStudio::CommonMeasures::Extension.new
    #  measure = BCLMeasure.new(File.expand_path(common_measures_instance.root_dir, 'lib/measures/openstudio_results'))
    #  measure.addAttribute(Attribute.new("__SKIP__", false))
    #  args_hash = {
    #      "__SKIP__": false,
    #      "building_summary_section": true,
    #      "annual_overview_section": true,
    #      "monthly_overview_section": true,
    #      "utility_bills_rates_section": true,
    #      "envelope_section_section": true,
    #      "space_type_breakdown_section": true,
    #      "space_type_details_section": true,
    #      "interior_lighting_section": true,
    #      "plug_loads_section": true,
    #      "exterior_light_section": true,
    #      "water_use_section": true,
    #      "hvac_load_profile": true,
    #      "zone_condition_section": true,
    #      "zone_summary_section": true,
    #      "zone_equipment_detail_section": true,
    #      "air_loops_detail_section": true,
    #      "plant_loops_detail_section": true,
    #      "outdoor_air_section": true,
    #      "cost_summary_section": true,
    #      "source_energy_section": true,
    #      "schedules_overview_section": true,
    #      "reg_monthly_details": true
    #  }
    #  new_step = {}
    #  new_step['measure_dir_name'] = "openstudio_results"
    #  new_step['arguments'] = args_hash
    #  workflow.addMeasure(measure)

      osw_path = osm_baseline_path.gsub('.osm', '.osw')
      workflow.saveAs(File.absolute_path(osw_path.to_s))

      extension = OpenStudio::Extension::Extension.new
      runner_options = { run_simulations: true, verbose: false}
      runner = OpenStudio::Extension::Runner.new(extension.root_dir, nil, runner_options)
      return runner.run_osw(osw_path, osm_baseline_dir)
    end

    def run_osws()
      osw_files = []
      osw_sr_files = []
      Dir.glob("#{@output_dir}/**/*.osw") { |osw| osw_files << osw }
      Dir.glob("#{@output_dir}/SR/*.osw") { |osw| osw_sr_files << osw }


      extension = OpenStudio::Extension::Extension.new
      runner_options = { run_simulations: true, verbose: false, num_parallel: 7, max_to_run: Float::INFINITY}
      runner = OpenStudio::Extension::Runner.new(extension.root_dir, nil, runner_options)
      puts "osw_files - osw_sr_files #{osw_files - osw_sr_files}"
      return runner.run_osws(osw_files - osw_sr_files)
    end

    private

    def choose_model_maker
      # for now there is only one model maker
      @model_maker = ModelMakerLevelZero.new(@doc, @ns)
    end

    public
    attr_reader :osm_baseline_path
  end
end
