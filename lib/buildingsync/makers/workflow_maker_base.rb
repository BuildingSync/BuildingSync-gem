# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2022, Alliance for Sustainable Energy, LLC.
# BuildingSync(R), Copyright (c) 2015-2022, Alliance for Sustainable Energy, LLC.
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

require 'fileutils'
require 'json'

module BuildingSync
  # base class for objects that will configure workflows based on building sync files
  class WorkflowMakerBase
    # initialize
    # @param doc [REXML::Document]
    # @param ns [String]
    def initialize(doc, ns)
      if !doc.is_a?(REXML::Document)
        raise StandardError, "doc must be an REXML::Document.  Passed object of class: #{doc.class}"
      end

      if !ns.is_a?(String)
        raise StandardError, "ns must be String.  Passed object of class: #{ns.class}"
      end

      @doc = doc
      @ns = ns
      @workflow = nil
    end

    def get_prefix
      if @ns == ''
        return ''
      else
        return "#{@ns}:"
      end
    end

    # TODO: add a schema validation and re-ordering mechanism for XML elements
    # Format, add declaration, and write xml to disk
    # @param filename [String] full path including filename, i.e. output/path/results.xml
    def save_xml(filename)
      # first we make sure all directories exist
      FileUtils.mkdir_p(File.dirname(filename))

      # Setup formatting
      formatter = REXML::Formatters::Pretty.new
      formatter.compact = true

      # Setup document declaration
      decl = REXML::XMLDecl.new
      decl.encoding = REXML::XMLDecl::DEFAULT_ENCODING # UTF-8
      @doc << decl

      # Write file
      File.open(filename, 'w') do |file|
        formatter.write(@doc, file)
      end
    end

    # set only one measure path
    # @param workflow [Hash] a hash of the openstudio workflow
    # @param measures_dir [String]
    def set_measure_path(workflow, measures_dir)
      workflow['measure_paths'] = [measures_dir]
    end

    # set multiple measure paths
    # @param measures_dir_array [Array]
    def set_measure_paths(measures_dir_array)
      @workflow['measure_paths'] = measures_dir_array
    end

    # clear all measures from the list in the workflow
    def clear_all_measures
      @workflow.delete('steps')
      @workflow['steps'] = []
    end

    # add measure path
    # @param measures_dir [String]
    # @return [Boolean]
    def add_measure_path(measures_dir)
      @workflow['measure_paths'].each do |dir|
        if dir == measures_dir
          return false
        end
      end
      @workflow['measure_paths'] << measures_dir
      return true
    end

    # set measure argument
    # @param workflow [Hash] a hash of the openstudio workflow
    # @param measure_dir_name [String] the directory name for the measure, as it appears
    #   in any of the gems, i.e. openstudio-common-measures-gem/lib/measures/[measure_dir_name]
    # @param argument_name [String]
    # @param argument_value [String]
    # @return [Boolean]
    def set_measure_argument(workflow, measure_dir_name, argument_name, argument_value)
      result = false
      workflow['steps'].each do |step|
        if step['measure_dir_name'] == measure_dir_name
          step['arguments'][argument_name] = argument_value
          result = true
        end
      end

      if !result
        raise "Could not set '#{argument_name}' to '#{argument_value}' for measure '#{measure_dir_name}'"
      end

      return result
    end

    # Adds a new measure to the workflow ONLY if it doesn't already exist
    # @param workflow [Hash] a hash of the openstudio workflow
    # @param measure_dir_name [String] the directory name for the measure, as it appears
    #   in any of the gems, i.e. openstudio-common-measures-gem/lib/measures/[measure_dir_name]
    # @return [Boolean] whether or not a new measure was added
    def add_new_measure(workflow, measure_dir_name)
      # first we check if the measure already exists
      workflow['steps'].each do |step|
        if step['measure_dir_name'] == measure_dir_name
          return false
        end
      end
      # if it does not exist we add it
      new_step = {}
      new_step['measure_dir_name'] = measure_dir_name
      workflow['steps'].unshift(new_step)
      return true
    end
  end
end
