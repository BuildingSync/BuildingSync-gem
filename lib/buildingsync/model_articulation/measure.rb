# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************
require 'buildingsync/helpers/helper'
require 'buildingsync/helpers/xml_get_set'

module BuildingSync
  # Measure class
  class Measure
    include BuildingSync::Helper
    include BuildingSync::XmlGetSet
    # initialize
    # @param @base_xml [REXML::Element]
    # @param ns [String]
    def initialize(base_xml, ns)
      @base_xml = base_xml
      @ns = ns

      help_element_class_type_check(base_xml, 'Measure')
    end
  end
end
