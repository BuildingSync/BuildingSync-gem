# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2019, Alliance for Sustainable Energy, LLC.
# All rights reserved.
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

require 'openstudio/model_articulation/version'

module BuildingSync
  class Extension < OpenStudio::Extension::Extension
    # specify to run the baseline simulation only or not
    SIMULATE_BASELINE_ONLY = false

    # specify to include the model calibration or not
    DO_MODEL_CALIBRATION = false

    # collect results
    DO_GET_RESULTS = false

    # number of parallel BuildingSync files to run
    NUM_BUILDINGS_PARALLEL = 2

    # overwrite the value of the constant defined in the openstudio-extension-gem
    DO_SIMULATIONS = true

    # Override the base class
    # The Extension class contains both the instance of the BuildingSync file (in XML) and the
    # helper methods from the OpenStudio::Extension gem to support managing measures that are related
    # to BuildingSync.
    def initialize
      # Initialize the root directory for use in the extension class. This must be done, otherwise the
      # root_dir will be the root_dir in the OpenStudio Extension Gem.
      super
      @root_dir = File.absolute_path(File.join(File.dirname(__FILE__), '..', '..'))
    end

    # Read in an existing buildingsync file
    #
    # @param buildingsync_file [string]: path to BuildingSync XML
    def self.from_file(buildingsync_file)
      bsync = Extension.new
      bsync.read_from_xml(buildingsync_file)
      return bsync
    end

    # read the XML from file
    def read_from_xml(buildingsync_file)
      return nil
    end

    # write OSW file
    # This method will write a single OSW from the BuildingSync file. The OSW will not include any of the scenarios
    # other than the baseline.
    def to_osw
      return nil
    end

    # write multiple OSW files
    # This method will write out multiple OSW files from the BuildingSync file. The OSWs will be constructed based
    # on the various scenarios that are in the BuildingSync file
    def to_osws
      return nil
    end
  end
end
