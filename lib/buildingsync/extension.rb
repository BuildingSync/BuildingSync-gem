# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************

require 'openstudio/model_articulation/version'
require 'openstudio/extension'

module BuildingSync
  # Extension class
  class Extension < OpenStudio::Extension::Extension
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
  end
end
