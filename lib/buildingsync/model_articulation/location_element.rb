# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************

module BuildingSync
  # base class for objects that will configure workflows based on building sync files
  class LocationElement < SpatialElement
    # initialize LocationElement class
    # @param base_xml [REXML::Element] an element corresponding to a locational element
    #   either an auc:Site or auc:Building
    # @param ns [String] namespace, likely 'auc'
    def initialize(base_xml, ns, standard_to_be_used)
      super(base_xml, ns, standard_to_be_used)
      @base_xml = base_xml
      @ns = ns

      @climate_zone = nil
      @climate_zone_ashrae = nil
      @climate_zone_ca_t24 = nil
      @city_name = nil
      @state_name = nil
      @standard_to_be_used = standard_to_be_used

      read_location_values
    end

    # read location values
    def read_location_values
      # read in the ASHRAE climate zone
      read_climate_zone

      # read city and state name
      read_city_and_state_name
    end

    def determine_climate_zone
      if @standard_to_be_used == ASHRAE90_1
        if !@climate_zone_ashrae.nil?
          @climate_zone = @climate_zone_ashrae
        elsif @climate_zone.nil? && !@climate_zone_ca_t24.nil?
          @climate_zone = @climate_zone_ca_t24
          OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.LocationElement.determine_climate_zone', "Element ID: #{xget_id} - Standard to use is #{standard_to_be_used} but ASHRAE Climate Zone is nil. Using CA T24: #{@climate_zone}")
        end
      elsif @standard_to_be_used == CA_TITLE24
        if !@climate_zone_ca_t24.nil?
          @climate_zone = @climate_zone_ca_t24
        elsif @climate_zone.nil? && !@climate_zone_ashrae.nil?
          @climate_zone = @climate_zone_ashrae
          OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.LocationElement.determine_climate_zone', "Element ID: #{xget_id} - Standard to use is #{standard_to_be_used} but CA T24 Climate Zone is nil. Using ASHRAE: #{@climate_zone}")
        end
      end
    end

    # get climate zone
    # @return [String]
    def get_climate_zone
      return @climate_zone
    end

    # read climate zone
    def read_climate_zone
      if @base_xml.elements["#{@ns}:ClimateZoneType/#{@ns}:ASHRAE"]
        unformatted_climate_zone = @base_xml.elements["#{@ns}:ClimateZoneType/#{@ns}:ASHRAE/#{@ns}:ClimateZone"].text
        @climate_zone_ashrae = "ASHRAE 169-2013-#{unformatted_climate_zone}"
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.LocationElement.read_climate_zone', "Element ID: #{xget_id} - ASHRAE Climate Zone: #{@climate_zone_ashrae}")
      else
        @climate_zone_ashrae = nil
      end
      if @base_xml.elements["#{@ns}:ClimateZoneType/#{@ns}:CaliforniaTitle24"]
        unformatted_climate_zone = @base_xml.elements["#{@ns}:ClimateZoneType/#{@ns}:CaliforniaTitle24/#{@ns}:ClimateZone"].text
        @climate_zone_ca_t24 = "CEC T24-CEC#{unformatted_climate_zone.gsub('Climate Zone', '').strip}"
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
