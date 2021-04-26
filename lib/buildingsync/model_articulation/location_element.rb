# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2021, Alliance for Sustainable Energy, LLC.
# BuildingSync(R), Copyright (c) 2015-2021, Alliance for Sustainable Energy, LLC.
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

module BuildingSync
  # base class for objects that will configure workflows based on building sync files
  class LocationElement < SpatialElement
    # initialize LocationElement class
    # @param base_xml [REXML::Element] an element corresponding to a locational element
    #   either an auc:Site or auc:Building
    # @param ns [String] namespace, likely 'auc'
    def initialize(base_xml, ns)
      super(base_xml, ns)
      @base_xml = base_xml
      @ns = ns

      @climate_zone = nil
      @climate_zone_ashrae = nil
      @climate_zone_ca_t24 = nil
      @city_name = nil
      @state_name = nil

      read_location_values
    end

    # read location values
    def read_location_values
      # read in the ASHRAE climate zone
      read_climate_zone

      # read city and state name
      read_city_and_state_name
    end

    def determine_climate_zone(standard_to_be_used = nil)
      if standard_to_be_used == ASHRAE90_1
        if !@climate_zone_ashrae.nil?
          @climate_zone = @climate_zone_ashrae
        elsif @climate_zone.nil? && !@climate_zone_ca_t24.nil?
          @climate_zone = @climate_zone_ca_t24
          OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.LocationElement.determine_climate_zone', "Element ID: #{xget_id} - Standard to use is #{standard_to_be_used} but ASHRAE Climate Zone is nil. Using CA T24: #{@climate_zone}")
        end
      elsif standard_to_be_used == CA_TITLE24
        if !@climate_zone_ca_t24.nil?
          @climate_zone = @climate_zone_ca_t24
        elsif @climate_zone.nil? && !@climate_zone_ashrae.nil?
          @climate_zone = @climate_zone_ashrae
          OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.LocationElement.determine_climate_zone', "Element ID: #{xget_id} - Standard to use is #{standard_to_be_used} but CA T24 Climate Zone is nil. Using ASHRAE: #{@climate_zone}")
        end
      end
    end

    # get climate zone
    # @param standard_to_be_used [String]
    # @return [String]
    def get_climate_zone
      return @climate_zone
    end

    # read climate zone
    def read_climate_zone
      if @base_xml.elements["#{@ns}:ClimateZoneType/#{@ns}:ASHRAE"]
        @climate_zone_ashrae = @base_xml.elements["#{@ns}:ClimateZoneType/#{@ns}:ASHRAE/#{@ns}:ClimateZone"].text
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.LocationElement.read_climate_zone', "Element ID: #{xget_id} - ASHRAE Climate Zone: #{@climate_zone_ashrae}")
      else
        @climate_zone_ashrae = nil
      end
      if @base_xml.elements["#{@ns}:ClimateZoneType/#{@ns}:CaliforniaTitle24"]
        @climate_zone_ca_t24 = @base_xml.elements["#{@ns}:ClimateZoneType/#{@ns}:CaliforniaTitle24/#{@ns}:ClimateZone"].text
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.LocationElement.read_climate_zone', "Element ID: #{xget_id} - Title24 Climate Zone: #{@climate_zone_ca_t24}")
      else
        @climate_zone_ca_t24 = nil
      end

      if @climate_zone_ashrae.nil? && @climate_zone_ca_t24.nil?
        OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.LocationElement.read_climate_zone', "Element ID: #{xget_id} - Title24 Climate Zone and ASHRAE Climate Zone not found")
      end
    end

    # read city and state name
    def read_city_and_state_name
      if @base_xml.elements["#{@ns}:Address/#{@ns}:City"]
        @city_name = @base_xml.elements["#{@ns}:Address/#{@ns}:City"].text
      else
        @city_name = nil
      end
      if @base_xml.elements["#{@ns}:Address/#{@ns}:State"]
        @state_name = @base_xml.elements["#{@ns}:Address/#{@ns}:State"].text
      else
        @state_name = nil
      end
    end
  end
end
