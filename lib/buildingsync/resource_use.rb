# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************

module BuildingSync
  # ResourceUse class
  class ResourceUse
    include BuildingSync::Helper
    include BuildingSync::XmlGetSet
    # initialize
    # @param @base_xml [REXML::Element]
    # @param ns [String]
    def initialize(base_xml, ns)
      @base_xml = base_xml
      @ns = ns

      help_element_class_type_check(base_xml, 'ResourceUse')
    end
  end
end
