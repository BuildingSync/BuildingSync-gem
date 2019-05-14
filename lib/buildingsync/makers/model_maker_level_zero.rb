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
require_relative '../model_articulation/facility'
require_relative 'workflow_maker_phase_zero'
module BuildingSync
  class ModelMakerLevelZero < PhaseZeroWorkflowMaker
    def initialize(doc, ns)
      super

      @facilities = []
    end

    def generate_baseline(dir)
      @doc.elements.each("/#{@ns}:BuildingSync/#{@ns}:Facilities/#{@ns}:Facility") do |facility_element|
        @facilities.push(Facility.new(facility_element, @ns))
      end

      if @facilities.count == 0
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.ModelMakerLevelZero.generate_baseline', 'There are no facilities in your BuildingSync file.')
        raise 'Error: There are no facilities in your BuildingSync file.'
      else if @facilities.count > 1
             OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.ModelMakerLevelZero.generate_baseline', "There are more than one (#{@facilities.count})facilities in your BuildingSync file. Only one if supported right now")
             raise "Error: There are more than one (#{@facilities.count})facilities in your BuildingSync file. Only one if supported right now"
           end
      end

      @facilities.each(&:generate_baseline_osm)
      return write_osm(dir)
    end

    private

    def write_osm(dir)
      @facilities.each do |facility|
        @@facility = facility.write_osm(dir)
      end
    end
  end
end
