# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2020, Alliance for Sustainable Energy, LLC.
# BuildingSync(R), Copyright (c) 2015-2020, Alliance for Sustainable Energy, LLC.
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
require 'openstudio'
require 'fileutils'
require 'json'
require 'openstudio/extension/core/os_lib_model_generation'

module BuildingSync
  # base class for objects that will configure workflows based on building sync files
  class SpatialElement

    def initialize
      @total_floor_area = nil
      @bldg_type = nil
      @system_type = nil
      @bar_division_method = nil
      @space_types = {}
      @fraction_area = nil
      @space_types_floor_area = nil
      @conditioned_floor_area_heated_only = nil
      @conditioned_floor_area_cooled_only = nil
      @conditioned_floor_area_heated_cooled = nil
      @conditioned_below_grade_floor_area = nil
      @custom_conditioned_above_grade_floor_area = nil
      @custom_conditioned_below_grade_floor_area = nil
    end

    def read_floor_areas(build_element, parent_total_floor_area, ns)
      build_element.elements.each("#{ns}:FloorAreas/#{ns}:FloorArea") do |floor_area_element|
        next if !floor_area_element.elements["#{ns}:FloorAreaValue"]
        floor_area = floor_area_element.elements["#{ns}:FloorAreaValue"].text.to_f
        next if floor_area.nil?

        floor_area_type = floor_area_element.elements["#{ns}:FloorAreaType"].text
        if floor_area_type == 'Gross'
          @total_floor_area = OpenStudio.convert(validate_positive_number_excluding_zero('gross_floor_area', floor_area), 'ft^2', 'm^2').get
        elsif floor_area_type == 'Heated and Cooled'
          @conditioned_floor_area_heated_cooled = OpenStudio.convert(validate_positive_number_excluding_zero('@heated_and_cooled_floor_area', floor_area), 'ft^2', 'm^2').get
        elsif floor_area_type == 'Footprint'
          @footprint_floor_area = OpenStudio.convert(validate_positive_number_excluding_zero('@footprint_floor_area', floor_area), 'ft^2', 'm^2').get
        elsif floor_area_type == 'Conditioned'
          @conditioned_floor_area_heated_cooled = OpenStudio.convert(validate_positive_number_excluding_zero('@conditioned_floor_area_heated_cooled', floor_area), 'ft^2', 'm^2').get
        elsif floor_area_type == 'Heated Only'
          @conditioned_floor_area_heated_only = OpenStudio.convert(validate_positive_number_excluding_zero('@heated_only_floor_area', floor_area), 'ft^2', 'm^2').get
        elsif floor_area_type == 'Cooled Only'
          @conditioned_floor_area_cooled_only = OpenStudio.convert(validate_positive_number_excluding_zero('@cooled_only_floor_area', floor_area), 'ft^2', 'm^2').get
        elsif floor_area_type == 'Custom'
          if floor_area_element.elements["#{ns}:FloorAreaCustomName"].text == 'Conditioned above grade'
            @custom_conditioned_above_grade_floor_area = OpenStudio.convert(validate_positive_number_excluding_zero('@custom_conditioned_above_grade_floor_area', floor_area), 'ft^2', 'm^2').get
          elsif floor_area_element.elements["#{ns}:FloorAreaCustomName"].text == 'Conditioned below grade'
            @custom_conditioned_below_grade_floor_area = OpenStudio.convert(validate_positive_number_excluding_zero('@custom_conditioned_below_grade_floor_area', floor_area), 'ft^2', 'm^2').get
          end
        else
          OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.SpatialElement.generate_baseline_osm', "Unsupported floor area type found: #{floor_area_type}")
        end
      end

      if @total_floor_area.nil? || @total_floor_area == 0
        # if the total floor area is null, we try to calculate the total area, from various conditioned areas
        running_floor_area = 0
        if !@conditioned_floor_area_cooled_only.nil? && @conditioned_floor_area_cooled_only > 0
          running_floor_area += @conditioned_floor_area_cooled_only
        end
        if !@conditioned_floor_area_heated_only.nil? && @conditioned_floor_area_heated_only > 0
          running_floor_area += @conditioned_floor_area_heated_only
        end
        if !@conditioned_floor_area_heated_cooled.nil? && @conditioned_floor_area_heated_cooled > 0
          running_floor_area += @conditioned_floor_area_heated_cooled
        end
        if running_floor_area > 0
          @total_floor_area = running_floor_area
        else
          # if the conditions floor areas are null, we look at the conditioned above and below grade areas
          if !@custom_conditioned_above_grade_floor_area.nil? && @custom_conditioned_above_grade_floor_area > 0
            running_floor_area += @custom_conditioned_above_grade_floor_area
          end
          if !@custom_conditioned_below_grade_floor_area.nil? && @custom_conditioned_below_grade_floor_area > 0
            running_floor_area += @custom_conditioned_below_grade_floor_area
          end
          if running_floor_area > 0
            @total_floor_area = running_floor_area
          end
        end
      end

      # if we did not find any area we get the parent one
      if @total_floor_area.nil? || @total_floor_area == 0
        return parent_total_floor_area
      else
        return @total_floor_area
      end
    end

    def read_occupancy_type(xml_element, occupancy_type, ns)
      occ_element = xml_element.elements["#{ns}:OccupancyClassification"]
      if !occ_element.nil?
        return occ_element.text
      else
        return occupancy_type
      end
    end

    # create hash of space types and generic ratios of building floor area
    def get_space_types_from_building_type(building_type, template, whole_building = true)

      hash = {}

      # TODO: - Confirm that these work for all standards

      if building_type == 'SecondarySchool'
        hash['Auditorium'] = { ratio: 0.0504, space_type_gen: true, default: false }
        hash['Cafeteria'] = { ratio: 0.0319, space_type_gen: true, default: false }
        hash['Classroom'] = { ratio: 0.3528, space_type_gen: true, default: true }
        hash['Corridor'] = { ratio: 0.2144, space_type_gen: true, default: false }
        hash['Gym'] = { ratio: 0.1646, space_type_gen: true, default: false }
        hash['Kitchen'] = { ratio: 0.0110, space_type_gen: true, default: false }
        hash['Library'] = { ratio: 0.0429, space_type_gen: true, default: false } # not in prototype
        hash['Lobby'] = { ratio: 0.0214, space_type_gen: true, default: false }
        hash['Mechanical'] = { ratio: 0.0349, space_type_gen: true, default: false }
        hash['Office'] = { ratio: 0.0543, space_type_gen: true, default: false }
        hash['Restroom'] = { ratio: 0.0214, space_type_gen: true, default: false }
      elsif building_type == 'PrimarySchool'
        hash['Cafeteria'] = { ratio: 0.0458, space_type_gen: true, default: false }
        hash['Classroom'] = { ratio: 0.5610, space_type_gen: true, default: true }
        hash['Corridor'] = { ratio: 0.1633, space_type_gen: true, default: false }
        hash['Gym'] = { ratio: 0.0520, space_type_gen: true, default: false }
        hash['Kitchen'] = { ratio: 0.0244, space_type_gen: true, default: false }
        # TODO: - confirm if Library is 0.0 for all templates
        hash['Library'] = { ratio: 0.0, space_type_gen: true, default: false }
        hash['Lobby'] = { ratio: 0.0249, space_type_gen: true, default: false }
        hash['Mechanical'] = { ratio: 0.0367, space_type_gen: true, default: false }
        hash['Office'] = { ratio: 0.0642, space_type_gen: true, default: false }
        hash['Restroom'] = { ratio: 0.0277, space_type_gen: true, default: false }
      elsif building_type == 'SmallOffice'
        # TODO: - populate Small, Medium, and Large office for whole_building false
        if whole_building
          hash['WholeBuilding - Sm Office'] = { ratio: 1.0, space_type_gen: true, default: true }
        else
          hash['SmallOffice - Breakroom'] = { ratio: 0.99, space_type_gen: true, default: false }
          hash['SmallOffice - ClosedOffice'] = { ratio: 0.99, space_type_gen: true, default: false }
          hash['SmallOffice - Conference'] = { ratio: 0.99, space_type_gen: true, default: false }
          hash['SmallOffice - Corridor'] = { ratio: 0.99, space_type_gen: true, default: false }
          hash['SmallOffice - Elec/MechRoom'] = { ratio: 0.99, space_type_gen: true, default: false }
          hash['SmallOffice - IT_Room'] = { ratio: 0.99, space_type_gen: true, default: false }
          hash['SmallOffice - Lobby'] = { ratio: 0.99, space_type_gen: true, default: false }
          hash['SmallOffice - OpenOffice'] = { ratio: 0.99, space_type_gen: true, default: true }
          hash['SmallOffice - Restroom'] = { ratio: 0.99, space_type_gen: true, default: false }
          hash['SmallOffice - Stair'] = { ratio: 0.99, space_type_gen: true, default: false }
          hash['SmallOffice - Storage'] = { ratio: 0.99, space_type_gen: true, default: false }
          hash['SmallOffice - Classroom'] = { ratio: 0.99, space_type_gen: true, default: false }
          hash['SmallOffice - Dining'] = { ratio: 0.99, space_type_gen: true, default: false }
          hash['WholeBuilding - Sm Office'] = { ratio: 0.0, space_type_gen: true, default: false }
        end
      elsif building_type == 'MediumOffice'
        if whole_building
          hash['WholeBuilding - Md Office'] = { ratio: 1.0, space_type_gen: true, default: true }
        else
          hash['MediumOffice - Breakroom'] = { ratio: 0.99, space_type_gen: true, default: false }
          hash['MediumOffice - ClosedOffice'] = { ratio: 0.99, space_type_gen: true, default: false }
          hash['MediumOffice - Conference'] = { ratio: 0.99, space_type_gen: true, default: false }
          hash['MediumOffice - Corridor'] = { ratio: 0.99, space_type_gen: true, default: false }
          hash['MediumOffice - Elec/MechRoom'] = { ratio: 0.99, space_type_gen: true, default: false }
          hash['MediumOffice - IT_Room'] = { ratio: 0.99, space_type_gen: true, default: false }
          hash['MediumOffice - Lobby'] = { ratio: 0.99, space_type_gen: true, default: false }
          hash['MediumOffice - OpenOffice'] = { ratio: 0.99, space_type_gen: true, default: true }
          hash['MediumOffice - Restroom'] = { ratio: 0.99, space_type_gen: true, default: false }
          hash['MediumOffice - Stair'] = { ratio: 0.99, space_type_gen: true, default: false }
          hash['MediumOffice - Storage'] = { ratio: 0.99, space_type_gen: true, default: false }
          hash['MediumOffice - Classroom'] = { ratio: 0.99, space_type_gen: true, default: false }
          hash['MediumOffice - Dining'] = { ratio: 0.99, space_type_gen: true, default: false }
          hash['WholeBuilding - Md Office'] = { ratio: 0.0, space_type_gen: true, default: false }
        end
      elsif building_type == 'LargeOffice'
        if ['DOE Ref Pre-1980', 'DOE Ref 1980-2004'].include?(template)
          if whole_building
            hash['WholeBuilding - Lg Office'] = { ratio: 1.0, space_type_gen: true, default: true }
          else
            hash['BreakRoom'] = { ratio: 0.99, space_type_gen: true, default: false }
            hash['ClosedOffice'] = { ratio: 0.99, space_type_gen: true, default: false }
            hash['Conference'] = { ratio: 0.99, space_type_gen: true, default: false }
            hash['Corridor'] = { ratio: 0.99, space_type_gen: true, default: false }
            hash['Elec/MechRoom'] = { ratio: 0.99, space_type_gen: true, default: false }
            hash['IT_Room'] = { ratio: 0.99, space_type_gen: true, default: false }
            hash['Lobby'] = { ratio: 0.99, space_type_gen: true, default: false }
            hash['OpenOffice'] = { ratio: 0.99, space_type_gen: true, default: true }
            hash['PrintRoom'] = { ratio: 0.99, space_type_gen: true, default: false }
            hash['Restroom'] = { ratio: 0.99, space_type_gen: true, default: false }
            hash['Stair'] = { ratio: 0.99, space_type_gen: true, default: false }
            hash['Storage'] = { ratio: 0.99, space_type_gen: true, default: false }
            hash['Vending'] = { ratio: 0.99, space_type_gen: true, default: false }
            hash['WholeBuilding - Lg Office'] = { ratio: 0.0, space_type_gen: true, default: false }
          end
        else
          if whole_building
            hash['WholeBuilding - Lg Office'] = { ratio: 0.9737, space_type_gen: true, default: true }
            hash['OfficeLarge Data Center'] = { ratio: 0.0094, space_type_gen: true, default: false }
            hash['OfficeLarge Main Data Center'] = { ratio: 0.0169, space_type_gen: true, default: false }
          else
            hash['BreakRoom'] = { ratio: 0.99, space_type_gen: true, default: false }
            hash['ClosedOffice'] = { ratio: 0.99, space_type_gen: true, default: false }
            hash['Conference'] = { ratio: 0.99, space_type_gen: true, default: false }
            hash['Corridor'] = { ratio: 0.99, space_type_gen: true, default: false }
            hash['Elec/MechRoom'] = { ratio: 0.99, space_type_gen: true, default: false }
            hash['IT_Room'] = { ratio: 0.99, space_type_gen: true, default: false }
            hash['Lobby'] = { ratio: 0.99, space_type_gen: true, default: false }
            hash['OpenOffice'] = { ratio: 0.99, space_type_gen: true, default: true }
            hash['PrintRoom'] = { ratio: 0.99, space_type_gen: true, default: false }
            hash['Restroom'] = { ratio: 0.99, space_type_gen: true, default: false }
            hash['Stair'] = { ratio: 0.99, space_type_gen: true, default: false }
            hash['Storage'] = { ratio: 0.99, space_type_gen: true, default: false }
            hash['Vending'] = { ratio: 0.99, space_type_gen: true, default: false }
            hash['WholeBuilding - Lg Office'] = { ratio: 0.0, space_type_gen: true, default: false }
            hash['OfficeLarge Data Center'] = { ratio: 0.0, space_type_gen: true, default: false }
            hash['OfficeLarge Main Data Center'] = { ratio: 0.0, space_type_gen: true, default: false }
          end
        end
      elsif building_type == 'SmallHotel'
        if ['DOE Ref Pre-1980', 'DOE Ref 1980-2004'].include?(template)
          hash['Corridor'] = { ratio: 0.1313, space_type_gen: true, default: false }
          hash['Elec/MechRoom'] = { ratio: 0.0038, space_type_gen: true, default: false }
          hash['ElevatorCore'] = { ratio: 0.0113, space_type_gen: true, default: false }
          hash['Exercise'] = { ratio: 0.0081, space_type_gen: true, default: false }
          hash['GuestLounge'] = { ratio: 0.0406, space_type_gen: true, default: false }
          hash['GuestRoom'] = { ratio: 0.6313, space_type_gen: true, default: true }
          hash['Laundry'] = { ratio: 0.0244, space_type_gen: true, default: false }
          hash['Mechanical'] = { ratio: 0.0081, space_type_gen: true, default: false }
          hash['Meeting'] = { ratio: 0.0200, space_type_gen: true, default: false }
          hash['Office'] = { ratio: 0.0325, space_type_gen: true, default: false }
          hash['PublicRestroom'] = { ratio: 0.0081, space_type_gen: true, default: false }
          hash['StaffLounge'] = { ratio: 0.0081, space_type_gen: true, default: false }
          hash['Stair'] = { ratio: 0.0400, space_type_gen: true, default: false }
          hash['Storage'] = { ratio: 0.0325, space_type_gen: true, default: false }
        else
          hash['Corridor'] = { ratio: 0.1313, space_type_gen: true, default: false }
          hash['Elec/MechRoom'] = { ratio: 0.0038, space_type_gen: true, default: false }
          hash['ElevatorCore'] = { ratio: 0.0113, space_type_gen: true, default: false }
          hash['Exercise'] = { ratio: 0.0081, space_type_gen: true, default: false }
          hash['GuestLounge'] = { ratio: 0.0406, space_type_gen: true, default: false }
          hash['GuestRoom123Occ'] = { ratio: 0.4081, space_type_gen: true, default: true }
          hash['GuestRoom123Vac'] = { ratio: 0.2231, space_type_gen: true, default: false }
          hash['Laundry'] = { ratio: 0.0244, space_type_gen: true, default: false }
          hash['Mechanical'] = { ratio: 0.0081, space_type_gen: true, default: false }
          hash['Meeting'] = { ratio: 0.0200, space_type_gen: true, default: false }
          hash['Office'] = { ratio: 0.0325, space_type_gen: true, default: false }
          hash['PublicRestroom'] = { ratio: 0.0081, space_type_gen: true, default: false }
          hash['StaffLounge'] = { ratio: 0.0081, space_type_gen: true, default: false }
          hash['Stair'] = { ratio: 0.0400, space_type_gen: true, default: false }
          hash['Storage'] = { ratio: 0.0325, space_type_gen: true, default: false }
        end
      elsif building_type == 'LargeHotel'
        hash['Banquet'] = { ratio: 0.0585, space_type_gen: true, default: false }
        hash['Basement'] = { ratio: 0.1744, space_type_gen: false, default: false }
        hash['Cafe'] = { ratio: 0.0166, space_type_gen: true, default: false }
        hash['Corridor'] = { ratio: 0.1736, space_type_gen: true, default: false }
        hash['GuestRoom'] = { ratio: 0.4099, space_type_gen: true, default: true }
        hash['Kitchen'] = { ratio: 0.0091, space_type_gen: true, default: false }
        hash['Laundry'] = { ratio: 0.0069, space_type_gen: true, default: false }
        hash['Lobby'] = { ratio: 0.1153, space_type_gen: true, default: false }
        hash['Mechanical'] = { ratio: 0.0145, space_type_gen: true, default: false }
        hash['Retail'] = { ratio: 0.0128, space_type_gen: true, default: false }
        hash['Storage'] = { ratio: 0.0084, space_type_gen: true, default: false }
      elsif building_type == 'Warehouse'
        hash['Bulk'] = { ratio: 0.6628, space_type_gen: true, default: true }
        hash['Fine'] = { ratio: 0.2882, space_type_gen: true, default: false }
        hash['Office'] = { ratio: 0.0490, space_type_gen: true, default: false }
      elsif building_type == 'RetailStandalone'
        hash['Back_Space'] = { ratio: 0.1656, space_type_gen: true, default: false }
        hash['Entry'] = { ratio: 0.0052, space_type_gen: true, default: false }
        hash['Point_of_Sale'] = { ratio: 0.0657, space_type_gen: true, default: false }
        hash['Retail'] = { ratio: 0.7635, space_type_gen: true, default: true }
      elsif building_type == 'RetailStripmall'
        hash['Strip mall - type 1'] = { ratio: 0.25, space_type_gen: true, default: false }
        hash['Strip mall - type 2'] = { ratio: 0.25, space_type_gen: true, default: false }
        hash['Strip mall - type 3'] = { ratio: 0.50, space_type_gen: true, default: true }
      elsif building_type == 'QuickServiceRestaurant'
        hash['Dining'] = { ratio: 0.5, space_type_gen: true, default: true }
        hash['Kitchen'] = { ratio: 0.5, space_type_gen: true, default: false }
      elsif building_type == 'FullServiceRestaurant'
        hash['Dining'] = { ratio: 0.7272, space_type_gen: true, default: true }
        hash['Kitchen'] = { ratio: 0.2728, space_type_gen: true, default: false }
      elsif building_type == 'MidriseApartment'
        hash['Apartment'] = { ratio: 0.8727, space_type_gen: true, default: true }
        hash['Corridor'] = { ratio: 0.0991, space_type_gen: true, default: false }
        hash['Office'] = { ratio: 0.0282, space_type_gen: true, default: false }
      elsif building_type == 'HighriseApartment'
        hash['Apartment'] = { ratio: 0.8896, space_type_gen: true, default: true }
        hash['Corridor'] = { ratio: 0.0991, space_type_gen: true, default: false }
        hash['Office'] = { ratio: 0.0113, space_type_gen: true, default: false }
      elsif building_type == 'Hospital'
        hash['Basement'] = { ratio: 0.1667, space_type_gen: false, default: false }
        hash['Corridor'] = { ratio: 0.1741, space_type_gen: true, default: false }
        hash['Dining'] = { ratio: 0.0311, space_type_gen: true, default: false }
        hash['ER_Exam'] = { ratio: 0.0099, space_type_gen: true, default: false }
        hash['ER_NurseStn'] = { ratio: 0.0551, space_type_gen: true, default: false }
        hash['ER_Trauma'] = { ratio: 0.0025, space_type_gen: true, default: false }
        hash['ER_Triage'] = { ratio: 0.0050, space_type_gen: true, default: false }
        hash['ICU_NurseStn'] = { ratio: 0.0298, space_type_gen: true, default: false }
        hash['ICE_Open'] = { ratio: 0.0275, space_type_gen: true, default: false }
        hash['ICU_PatRm'] = { ratio: 0.0115, space_type_gen: true, default: false }
        hash['Kitchen'] = { ratio: 0.0414, space_type_gen: true, default: false }
        hash['Lab'] = { ratio: 0.0236, space_type_gen: true, default: false }
        hash['Lobby'] = { ratio: 0.0657, space_type_gen: true, default: false }
        hash['NurseStn'] = { ratio: 0.1723, space_type_gen: true, default: false }
        hash['Office'] = { ratio: 0.0286, space_type_gen: true, default: false }
        hash['OR'] = { ratio: 0.0273, space_type_gen: true, default: false }
        hash['PatCorridor'] = { ratio: 0.0, space_type_gen: true, default: false } # not in prototype
        hash['PatRoom'] = { ratio: 0.0845, space_type_gen: true, default: true }
        hash['PhysTherapy'] = { ratio: 0.0217, space_type_gen: true, default: false }
        hash['Radiology'] = { ratio: 0.0217, space_type_gen: true, default: false }
      elsif building_type == 'Outpatient'
        hash['Anesthesia'] = { ratio: 0.0026, space_type_gen: true, default: false }
        hash['BioHazard'] = { ratio: 0.0014, space_type_gen: true, default: false }
        hash['Cafe'] = { ratio: 0.0103, space_type_gen: true, default: false }
        hash['CleanWork'] = { ratio: 0.0071, space_type_gen: true, default: false }
        hash['Conference'] = { ratio: 0.0082, space_type_gen: true, default: false }
        hash['DresingRoom'] = { ratio: 0.0021, space_type_gen: true, default: false }
        hash['Elec/MechRoom'] = { ratio: 0.0109, space_type_gen: true, default: false }
        hash['ElevatorPumpRoom'] = { ratio: 0.0022, space_type_gen: true, default: false }
        hash['Exam'] = { ratio: 0.1029, space_type_gen: true, default: true }
        hash['Hall'] = { ratio: 0.1924, space_type_gen: true, default: false }
        hash['IT_Room'] = { ratio: 0.0027, space_type_gen: true, default: false }
        hash['Janitor'] = { ratio: 0.0672, space_type_gen: true, default: false }
        hash['Lobby'] = { ratio: 0.0152, space_type_gen: true, default: false }
        hash['LockerRoom'] = { ratio: 0.0190, space_type_gen: true, default: false }
        hash['Lounge'] = { ratio: 0.0293, space_type_gen: true, default: false }
        hash['MedGas'] = { ratio: 0.0014, space_type_gen: true, default: false }
        hash['MRI'] = { ratio: 0.0107, space_type_gen: true, default: false }
        hash['MRI_Control'] = { ratio: 0.0041, space_type_gen: true, default: false }
        hash['NurseStation'] = { ratio: 0.0189, space_type_gen: true, default: false }
        hash['Office'] = { ratio: 0.1828, space_type_gen: true, default: false }
        hash['OR'] = { ratio: 0.0346, space_type_gen: true, default: false }
        hash['PACU'] = { ratio: 0.0232, space_type_gen: true, default: false }
        hash['PhysicalTherapy'] = { ratio: 0.0462, space_type_gen: true, default: false }
        hash['PreOp'] = { ratio: 0.0129, space_type_gen: true, default: false }
        hash['ProcedureRoom'] = { ratio: 0.0070, space_type_gen: true, default: false }
        hash['Reception'] = { ratio: 0.0365, space_type_gen: true, default: false }
        hash['Soil Work'] = { ratio: 0.0088, space_type_gen: true, default: false }
        hash['Stair'] = { ratio: 0.0146, space_type_gen: true, default: false }
        hash['Toilet'] = { ratio: 0.0193, space_type_gen: true, default: false }
        hash['Undeveloped'] = { ratio: 0.0835, space_type_gen: false, default: false }
        hash['Xray'] = { ratio: 0.0220, space_type_gen: true, default: false }
      elsif building_type == 'SuperMarket'
        # TODO: - populate ratios for SuperMarket
        hash['Bakery'] = { ratio: 0.99, space_type_gen: true, default: false }
        hash['Deli'] = { ratio: 0.99, space_type_gen: true, default: false }
        hash['DryStorage'] = { ratio: 0.99, space_type_gen: true, default: false }
        hash['Office'] = { ratio: 0.99, space_type_gen: true, default: false }
        hash['Produce'] = { ratio: 0.99, space_type_gen: true, default: true }
        hash['Sales'] = { ratio: 0.99, space_type_gen: true, default: true }
        hash['Corridor'] = { ratio: 0.99, space_type_gen: true, default: true }
        hash['Dining'] = { ratio: 0.99, space_type_gen: true, default: true }
        hash['Elec/MechRoom'] = { ratio: 0.99, space_type_gen: true, default: true }
        hash['Meeting'] = { ratio: 0.99, space_type_gen: true, default: true }
        hash['Restroom'] = { ratio: 0.99, space_type_gen: true, default: true }
        hash['Vestibule'] = { ratio: 0.99, space_type_gen: true, default: true }
      else
        return false
      end

      return hash

    end


    def set_bldg_and_system_type(occupancy_type, total_floor_area, raise_exception)
      # DOE Prototype building types:from openstudio-standards/lib/openstudio-standards/prototypes/common/prototype_metaprogramming.rb
      # SmallOffice, MediumOffice, LargeOffice, RetailStandalone, RetailStripmall, PrimarySchool, SecondarySchool, Outpatient
      # Hospital, SmallHotel, LargeHotel, QuickServiceRestaurant, FullServiceRestaurant, MidriseApartment, HighriseApartment, Warehouse

      if !occupancy_type.nil? && !total_floor_area.nil?
        json_file_path = File.expand_path('bldg_and_system_types.json', File.dirname(__FILE__))
        json = eval(File.read(json_file_path))

        process_bldg_and_system_type(json, occupancy_type, total_floor_area)

        if @bldg_type == ''
          raise "Building type '#{occupancy_type}' is beyond BuildingSync scope"
        end
      elsif raise_exception
        if occupancy_type.nil? && !total_floor_area.nil?
          raise "Building type '#{occupancy_type}' is nil"
        elsif !occupancy_type.nil? && total_floor_area.nil?
          raise "Building total floor area '#{total_floor_area}' is nil"
        end
      end
      puts "to get @bldg_type #{@bldg_type}, @bar_division_method #{@bar_division_method} and @system_type: #{@system_type}"
    end

    def process_bldg_and_system_type(json, occupancy_type, total_floor_area)
      puts "using occupancy_type #{occupancy_type} and total floor area: #{total_floor_area}"
      min_floor_area_correct = false
      max_floor_area_correct = false
      if !json[:"#{occupancy_type}"].nil?
        json[:"#{occupancy_type}"].each do |occ_type|
          if !occ_type[:bldg_type].nil?
            if occ_type[:min_floor_area] || occ_type[:max_floor_area]
              if occ_type[:min_floor_area] && occ_type[:min_floor_area].to_f < total_floor_area
                min_floor_area_correct = true
              end
              if occ_type[:max_floor_area] && occ_type[:max_floor_area].to_f > total_floor_area
                max_floor_area_correct = true
              end
              if (min_floor_area_correct && max_floor_area_correct) || (!occ_type[:min_floor_area] && max_floor_area_correct) || (min_floor_area_correct && !occ_type[:max_floor_area])
                puts "selected the following occupancy type: #{occ_type[:bldg_type]}"
                @bldg_type = occ_type[:bldg_type]
                @bar_division_method = occ_type[:bar_division_method]
                @system_type = occ_type[:system_type]
                return
              end
            else
              # otherwise we assume the first one is correct and we select this
              puts "selected the following occupancy type: #{occ_type[:bldg_type]}"
              @bldg_type = occ_type[:bldg_type]
              @bar_division_method = occ_type[:bar_division_method]
              @system_type = occ_type[:system_type]
              return
            end
          else
            # otherwise we assume the first one is correct and we select this
            @bldg_type = occ_type[:bldg_type]
            @bar_division_method = occ_type[:bar_division_method]
            @system_type = occ_type[:system_type]
            return
          end
        end
      end
      raise "Occupancy type #{occupancy_type} is not available in the bldg_and_system_types.json dictionary"
    end

    def validate_positive_number_excluding_zero(name, value)
      puts "Error: parameter #{name} must be positive and not zero." if value <= 0
      return value
    end

    def validate_positive_number_including_zero(name, value)
      puts "Error: parameter #{name} must be positive or zero." if value < 0
      return value
    end

    # create space types
    def create_space_types(model, total_bldg_floor_area, standard_template, open_studio_standard)
      # create space types from section type
      # mapping lookup_name name is needed for a few methods
      set_bldg_and_system_type(@occupancy_type, total_bldg_floor_area, false) if @bldg_type.nil?
      if open_studio_standard.nil?
        begin
          open_studio_standard = Standard.build("#{standard_template}_#{bldg_type}")
        rescue StandardError => e
          # if the combination of standard type and bldg type fails we try the standard type alone.
          puts "could not find open studio standard for template #{standard_template} and bldg type: #{bldg_type}, trying the standard type alone"
          open_studio_standard = Standard.build(standard_template)
          raise(e)
        end
      end
      lookup_name = open_studio_standard.model_get_lookup_name(@occupancy_type)
      puts " Building type: #{lookup_name} selected for occupancy type: #{@occupancy_type}"

      @space_types = get_space_types_from_building_type(@bldg_type, standard_template, true)
      puts " Space types: #{@space_types} selected for building type: #{@bldg_type} and standard template: #{standard_template}"
      # create space_type_map from array
      sum_of_ratios = 0.0

      @space_types.each do |space_type_name, hash|
        # create space type
        space_type = OpenStudio::Model::SpaceType.new(model)
        space_type.setStandardsBuildingType(@occupancy_type)
        space_type.setStandardsSpaceType(space_type_name)
        space_type.setName("#{@occupancy_type} #{space_type_name}")

        # set color
        test = open_studio_standard.space_type_apply_rendering_color(space_type) # this uses openstudio-standards
        OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Building.generate_baseline_osm', "Warning: Could not find color for #{space_type.name}") if !test
        # extend hash to hold new space type object
        hash[:space_type] = space_type

        # add to sum_of_ratios counter for adjustment multiplier
        sum_of_ratios += hash[:ratio]
      end

      # store multiplier needed to adjust sum of ratios to equal 1.0
      @ratio_adjustment_multiplier = 1.0 / sum_of_ratios

      @space_types_floor_area = {}
      @space_types.each do |space_type_name, hash|
        ratio_of_bldg_total = hash[:ratio] * @ratio_adjustment_multiplier * @fraction_area
        final_floor_area = ratio_of_bldg_total * total_bldg_floor_area # I think I can just pass ratio but passing in area is cleaner
        @space_types_floor_area[hash[:space_type]] = { floor_area: final_floor_area }
      end
      return @space_types_floor_area
    end

    def add_element_in_xml_file(building_element, ns, field_name, field_value)
      user_defined_fields = REXML::Element.new("#{ns}:UserDefinedFields")
      user_defined_field = REXML::Element.new("#{ns}:UserDefinedField")
      field_name_element = REXML::Element.new("#{ns}:FieldName")
      field_value_element = REXML::Element.new("#{ns}:FieldValue")

      if !field_value.nil?
        user_defined_fields.add_element(user_defined_field)
        building_element.add_element(user_defined_fields)
        user_defined_field.add_element(field_name_element)
        user_defined_field.add_element(field_value_element)

        field_name_element.text = field_name
        field_value_element.text = field_value
      end
    end

    def write_parameters_to_xml_for_spatial_element(ns, xml_element)
      add_element_in_xml_file(xml_element, ns, 'TotalFloorArea', @total_floor_area)
      add_element_in_xml_file(xml_element, ns, 'BuildingType', @bldg_type)
      add_element_in_xml_file(xml_element, ns, 'SystemType', @system_type)
      add_element_in_xml_file(xml_element, ns, 'BarDivisionMethod', @bar_division_method)
      add_element_in_xml_file(xml_element, ns, 'FractionArea', @fraction_area)
      add_element_in_xml_file(xml_element, ns, 'SpaceTypesFloorArea', @space_types_floor_area)
      add_element_in_xml_file(xml_element, ns, 'ConditionedFloorAreaHeatedOnly', @conditioned_floor_area_heated_only)
      add_element_in_xml_file(xml_element, ns, 'ConditionedFloorAreaCooledOnly', @conditioned_floor_area_cooled_only)
      add_element_in_xml_file(xml_element, ns, 'ConditionedFloorAreaHeatedCooled', @conditioned_floor_area_heated_cooled)
      add_element_in_xml_file(xml_element, ns, 'ConditionedBelowGradeFloorArea', @conditioned_below_grade_floor_area)
      add_element_in_xml_file(xml_element, ns, 'CustomConditionedAboveGradeFloorArea', @custom_conditioned_above_grade_floor_area)
      add_element_in_xml_file(xml_element, ns, 'CustomConditionedBelowGradeFloorArea', @custom_conditioned_below_grade_floor_area)
    end

    def validate_fraction; end
    attr_reader :total_floor_area, :bldg_type, :system_type, :space_types
  end
end
