# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************

module BuildingSync
  # AuditDate class
  class AuditDate
    include BuildingSync::Helper
    include BuildingSync::XmlGetSet
    # @param base_xml [REXML::Element]
    # @param ns [String]
    def initialize(base_xml, ns)
      @base_xml = base_xml
      @ns = ns

      help_element_class_type_check(base_xml, 'AuditDate')
    end
  end
end
