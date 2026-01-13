# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************

module BuildingSync
  # Utility class
  class Utility
    include BuildingSync::Helper
    include BuildingSync::XmlGetSet
    # @param base_xml [REXML::Element]
    # @param ns [String]
    def initialize(base_xml, ns)
      @base_xml = base_xml
      @ns = ns
      help_element_class_type_check(base_xml, 'Utility')
    end

    # @return [Array<REXML::Element>]
    def get_rate_schedules
      rs = []
      @base_xml.elements.each("#{@ns}:RateSchedules/#{@ns}:RateSchedule") do |rate_schedule|
        rs << rate_schedule
      end
      return rs
    end

    # @return [Array<String>]
    def get_utility_meter_numbers
      return xget_plurals_text_value('UtilityMeterNumber')
    end
  end
end
