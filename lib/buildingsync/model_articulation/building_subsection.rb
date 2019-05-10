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
require_relative '../helpers/os_lib_model_generation_bricr'
require 'openstudio-standards'
module BuildingSync
  class BuildingSubsection < SpatialElement
    include OsLib_ModelGenerationBRICR
    include OpenstudioStandards

    # initialize
    def initialize(subSectionElement, standard_template, occType, ns)
      @subsection_element = nil
      @standard = nil
      @fraction_area = nil
      @bldg_type = {}
      @space_types = {}
      @space_types_floor_area = {}
      # code to initialize
      read_xml(subSectionElement, standard_template, occType, ns)
    end

    def read_xml(subSectionElement, standard_template, occType, ns)
      # floor areas
      read_floor_areas(subSectionElement, nil, ns)
      # based on the occupancy type set building type, system type and bar division method
      read_bldg_system_type_based_on_occupancy_type(subSectionElement, occType, ns)

      @space_types = get_space_types_from_building_type(@bldg_type, standard_template, true)

      @subsection_element = subSectionElement

      # Make the standard applier
      @standard = Standard.build("#{standard_template}_#{@bldg_type}")
    end

    def read_bldg_system_type_based_on_occupancy_type(subSectionElement, occType, ns)
      @occupancy_type = read_occupancy_type(subSectionElement, occType, ns)
      set_bldg_and_system_type(@occupancy_type, @total_floor_area)
    end

    # create space types
    def create_space_types(model, total_bldg_floor_area)
      # create space types from subsection type
     # mapping building_type name is needed for a few methods
      building_type = @standard.model_get_lookup_name(@occupancy_type)
      # create space_type_map from array
      sum_of_ratios = 0.0
      @space_types.each do |space_type_name, hash|
        # create space type
        space_type = OpenStudio::Model::SpaceType.new(model)
        space_type.setStandardsBuildingType(@occupancy_type)
        space_type.setStandardsSpaceType(space_type_name)
        space_type.setName("#{@occupancy_type} #{space_type_name}")

        # set color
        test = @standard.space_type_apply_rendering_color(space_type) # this uses openstudio-standards
        if !test
          OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Building.generate_baseline_osm',"Warning: Could not find color for #{space_type.name}")
        end
        # extend hash to hold new space type object
        hash[:space_type] = space_type

        # add to sum_of_ratios counter for adjustment multiplier
        sum_of_ratios += hash[:ratio]
      end

      # store multiplier needed to adjust sum of ratios to equal 1.0
      @ratio_adjustment_multiplier = 1.0 / sum_of_ratios

      @space_types.each do |space_type_name, hash|
        ratio_of_bldg_total = hash[:ratio] * @ratio_adjustment_multiplier * fraction_area
        final_floor_area = ratio_of_bldg_total * total_bldg_floor_area # I think I can just pass ratio but passing in area is cleaner
        @space_types_floor_area[hash[:space_type]] = {floor_area: final_floor_area }
      end
    end
    attr_reader :bldg_type, :space_types_floor_area
    attr_accessor :fraction_area
  end
end
