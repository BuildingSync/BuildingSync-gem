# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
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
  end
end
