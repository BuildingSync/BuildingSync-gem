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
require 'rexml/xpath'

require_relative '../model_articulation/facility'
require_relative 'workflow_maker'
module BuildingSync
  # ModelMaker class
  class ModelMaker < ModelMakerBase
    # initialize the ModelMaker class
    # @param doc [REXML::Document]
    # @param ns [String]
    def initialize(doc, ns)
      super

      @facilities = []
      @facility = nil
      @facility_xml = nil
      @scenario_types = nil
      read_xml
    end

    # main read xml function that drives all of the reading
    def read_xml
      facility_path = "/#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility"
      facility_elements = REXML::XPath.match(@doc, facility_path)
      if facility_elements.size == 0
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.ModelMaker.read_xml', 'There are no facilities in your BuildingSync file.')
        raise 'Error: There are no facilities in your BuildingSync file.'
      elsif @facilities.count > 1
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.ModelMaker.read_xml', "There are more than one (#{@facilities.count})facilities in your BuildingSync file. Only one if supported right now")
        raise "Error: There are more than one (#{@facilities.count})facilities in your BuildingSync file. Only one if supported right now"
      else
        @facility_xml = facility_elements.first()
        @facility = Facility.new(@facility_xml, @ns)
      end
    end

    # get the facility object
    # @return [BldgSync::Facility] facility
    def get_facility
      return @facility
    end

    # generate the baseline model as osm model
    # @param dir [String]
    # @param epw_file_path [String]
    # @param standard_to_be_used [String] 'ASHRAE90.1' or 'CaliforniaTitle24' are supported options for now
    # @param ddy_file [String] path to the ddy file
    # @return [Boolean] true if successful
    def generate_baseline(dir, epw_file_path, standard_to_be_used, ddy_file = nil)
      @facility.set_all
      open_studio_standard = @facility.determine_open_studio_standard(standard_to_be_used)

      @facility.generate_baseline_osm(epw_file_path, dir, standard_to_be_used, ddy_file)
      return write_osm(dir)
    end

    # get the space types of the facility
    # @return [Vector<OpenStudio::Model::SpaceType>] vector of space types
    def get_space_types
      return @facility.get_space_types
    end

    # get model
    # @return [OpenStudio::Model] model
    def get_model
      return @facility.get_model
    end

    # writes the parameters determine during processing back to the BldgSync XML file
    def write_parameters_to_xml
      @facility.write_parameters_to_xml
    end

    private

    # write osm
    # @param dir [String]
    def write_osm(dir)
      @scenario_types = @facility.write_osm(dir)
    end
  end
end
