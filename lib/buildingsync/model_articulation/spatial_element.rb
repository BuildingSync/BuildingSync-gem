########################################################################################################################
#  BRICR, Copyright (c) 2017, Alliance for Sustainable Energy, LLC and The Regents of the University of California, through Lawrence 
#  Berkeley National Laboratory (subject to receipt of any required approvals from the U.S. Dept. of Energy). All rights reserved.
#
#  Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions 
#  are met:
#
#  (1) Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
#
#  (2) Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in 
#  the documentation and/or other materials provided with the distribution.
#
#  (3) The name of the copyright holder(s), any contributors, the United States Government, the United States Department of Energy, or 
#  any of their employees may not be used to endorse or promote products derived from this software without specific prior written 
#  permission from the respective party.
#
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER(S) AND ANY CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, 
#  BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL 
#  THE COPYRIGHT HOLDER(S), ANY CONTRIBUTORS, THE UNITED STATES GOVERNMENT, OR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF THEIR 
#  EMPLOYEES, BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED 
#  TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY 
#  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE 
#  USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
########################################################################################################################
require 'openstudio'
require 'fileutils'
require 'json'

module BuildingSync
  # base class for objects that will configure workflows based on building sync files
  class SpecialElement
    include OpenStudio
    def initialize
      @total_floor_area = nil
      @bldg_type = nil
      @system_type = nil
      @bar_division_method = nil
    end

    def read_floor_areas(build_element, ns)
      build_element.elements.each("#{ns}:FloorAreas/#{ns}:FloorArea") do |floor_area_element|
        floor_area = floor_area_element.elements["#{ns}:FloorAreaValue"].text.to_f
        next if floor_area.nil?

        floor_area_type = floor_area_element.elements["#{ns}:FloorAreaType"].text
        if floor_area_type == 'Gross'
          @total_floor_area = OpenStudio.convert(validate_positive_number_excluding_zero('gross_floor_area', floor_area), 'ft^2', 'm^2').get
        elsif floor_area_type == 'Heated and Cooled'
          @heated_and_cooled_floor_area = validate_positive_number_excluding_zero('@heated_and_cooled_floor_area', floor_area)
        elsif floor_area_type == 'Footprint'
          @footprint_floor_area = validate_positive_number_excluding_zero('@footprint_floor_area', floor_area)
        end

        raise 'Subsection does not define gross floor area' if @total_floor_area.nil?
      end
      @total_floor_area
    end

    def read_occupancy_type(xmlElement, occupancy_type, ns)
      occ_element = xmlElement.elements["#{ns}:OccupancyClassification"]
      if !occ_element.nil?
        return occ_element.text
      else
        return occupancy_type
      end
    end

    def set_bldg_and_system_type(occupancy_type, total_floor_area)
      if !occupancy_type.nil?
        if occupancy_type == 'Retail'
          @bldg_type = 'RetailStandalone'
          @bar_division_method = 'Multiple Space Types - Individual Stories Sliced'
          @system_type = 'PSZ-AC with gas coil heat'
        elsif occupancy_type == 'Office'
          @bar_division_method = 'Single Space Type - Core and Perimeter'
          if total_floor_area > 0 && total_floor_area < 20000
            @bldg_type = 'SmallOffice'
            @system_type = 'PSZ-AC with gas coil heat'
          elsif total_floor_area >= 20000 && total_floor_area < 75000
            @bldg_type = 'MediumOffice'
            @system_type = 'PVAV with reheat'
          else
            raise 'Office building size is beyond BuildingSync scope'
          end
        else
          raise "Building type '#{occupancy_type}' is beyond BuildingSync scope"
        end
      end
    end

    def validate_positive_number_excluding_zero(name, value)
      if value <= 0
        puts "Error: parameter #{name} must be positive and not zero."
      end
      return value
    end

    def validate_positive_number_including_zero(name, value)
      if value < 0
        puts "Error: parameter #{name} must be positive or zero."
      end
      return value
    end

    def validate_fraction; end
    attr_reader :total_floor_area, :bldg_type
  end
end
