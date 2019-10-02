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
require 'openstudio/model_articulation/os_lib_model_generation_bricr'
require 'openstudio-standards'
module BuildingSync
  class BuildingSection < SpatialElement
    include OsLib_ModelGenerationBRICR
    include OpenstudioStandards

    # initialize
    def initialize(section_element, occ_type, bldg_total_floor_area, ns)
      @fraction_area = nil
      @bldg_type = {}
      @occupancy_classification = nil
      @floor_area_value = nil
      @typical_occupant_usage_value_hours = nil
      @typical_occupant_usage_value_weeks = nil
      @occupant_quantity = nil
      @section_type = nil

      # code to initialize
      read_xml(section_element, occ_type, bldg_total_floor_area, ns)
    end

    def read_xml(section_element, occ_type, bldg_total_floor_area, ns)
      # floor areas
      @total_floor_area = read_floor_areas(section_element, bldg_total_floor_area, ns)
      # based on the occupancy type set building type, system type and bar division method
      read_bldg_system_type_based_on_occupancy_type(section_element, occ_type, ns)
      read_building_section_type(section_element, ns)
      read_building_section_other_detail(section_element, ns)
    end

    def read_bldg_system_type_based_on_occupancy_type(section_element, occ_type, ns)
      @occupancy_type = read_occupancy_type(section_element, occ_type, ns)
      set_bldg_and_system_type(@occupancy_type, @total_floor_area, false)
    end

    def read_building_section_type(section_element, ns)
      if section_element.elements["#{ns}:SectionType"]
        @section_type = section_element.elements["#{ns}:SectionType"].text
      else
        @section_type = nil
      end
    end

    def read_building_section_other_detail(section_element, ns)
      if section_element.elements["#{ns}:OccupancyClassification"]
        @occupancy_classification = section_element.elements["#{ns}:OccupancyClassification"].text
      else
        @occupancy_classification = nil
      end

      if section_element.elements["#{ns}:TypicalOccupantUsages"]
        section_element.elements.each("#{ns}:TypicalOccupantUsages/#{ns}:TypicalOccupantUsage") do |occ_usage|
          if occ_usage.elements["#{ns}:TypicalOccupantUsageUnits"].text == 'Hours per week'
            @typical_occupant_usage_value_hours = occ_usage.elements["#{ns}:TypicalOccupantUsageValue"].text
          elsif occ_usage.elements["#{ns}:TypicalOccupantUsageUnits"].text == 'Weeks per year'
            @typical_occupant_usage_value_weeks = occ_usage.elements["#{ns}:TypicalOccupantUsageValue"].text
          end
        end
      end
    end

    attr_reader :bldg_type, :space_types_floor_area, :occupancy_classification, :typical_occupant_usage_value_weeks, :typical_occupant_usage_value_hours, :occupancy_type, :section_type
    attr_accessor :fraction_area
  end
end
