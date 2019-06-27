# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2019, Alliance for Sustainable Energy, LLC.
# All rights reserved.
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
  class GetBCLWeatherFile
    def download_weather_file_from_city_name(state, city, latitude, longitude)

      remote = OpenStudio::RemoteBCL.new

      # Search for weather files
      responses = remote.searchComponentLibrary(city, 'Weather File')
      choices = OpenStudio::StringVector.new

      responses.each do |response|
        p "response name: #{response.name}"
        if response.name.include? 'TMY3'
          stateAttrValue = nil
          cityAttrValue = nil
          response.attributes.each do |attribute|
            if attribute.name == 'State'
              stateAttrValue = attribute.valueAsString
            elsif attribute.name == 'City'
              cityAttrValue = attribute.valueAsString
            end
          end
          if stateAttrValue == state && cityAttrValue.include?(city)
            choices << response.uid
          end
        end
      end

      if choices.count == 0
        if responses.count > 0
          responses.each do |response|
              stateAttrValue = nil
              cityAttrValue = nil
              response.attributes.each do |attribute|
                if attribute.valueType.value == 1
                  p "attribute name: #{attribute.name} and value: #{attribute.valueAsDouble}"
                elsif attribute.valueType.value == 6
                  p "attribute name: #{attribute.name} and value: #{attribute.valueAsString}"
                else
                  p "attribute name: #{attribute.name} and value type id: #{attribute.valueType.value}"
                end
                if attribute.name == 'State'
                  stateAttrValue = attribute.valueAsString
                elsif attribute.name == 'City'
                  cityAttrValue = attribute.valueAsString
                end
              end
              if stateAttrValue == state && cityAttrValue.include?(city)
                choices << response.uid
              end
            end
          end
        end

      if choices.count == 0 && !latitude.nil? && !longitude.nil?
        hash = {}
        # let's try to find the closest EPW file via latitude and longitude
        responses.each do |response|
          latitudeAttrValue = nil
          longitudeAttrValue = nil
          response.attributes.each do |attribute|
            if attribute.name == 'Latitude'
              latitudeAttrValue = attribute.valueAsDouble
            elsif attribute.name == 'Longitude'
              longitudeAttrValue = attribute.valueAsDouble
            end
          end
          next if latitudeAttrValue.nil?
          next if longitudeAttrValue.nil?

          diff = (latitudeAttrValue - latitude) ^ 2 + (longitudeAttrValue - longitude) ^ 2
          hash[diff] = response
        end

        if(hash.count > 0)
          choices << hash.sort_by { |key | key }.to_h[0]
        end
      end
      if choices.count == 0
        p "Error, could not find uid for state #{state} and city #{city}. Initial count of weather files: #{responses.count}. Please try a different weather file."
        return false
      end

      return download_weather_file(remote, choices)
  end

    def download_weather_file_from_weather_id(weather_id)
      remote = OpenStudio::RemoteBCL.new

      # Search for weather files
      responses = remote.searchComponentLibrary(weather_id, 'Weather File')

      # Create options for user prompt

      name_to_uid = Hash.new

      choices = OpenStudio::StringVector.new

      responses.each do |response|
        if response.name.include? 'TMY3'
          choices << response.uid
          name_to_uid[response.name] = response.uid
        end
      end

      if choices.count == 0
        p "Error, could not find uid for #{name.valueAsString}.  Please try a different weather file."
        return false
      end

      return download_weather_file(remote, choices)
    end

    def download_weather_file(remote, choices)
      epw_path = ''

      choices.each do |choice|
        uid = choice

        remote.downloadComponent(uid)
        component = remote.waitForComponentDownload

        if component.empty?
          p 'Cannot find local component'
          # runner.registerError('Cannot find local component')
          return false
        end

        component = component.get

        files = component.files('epw')

        if files.empty?
          p 'No epw file found'
          return false
        end

        epw_path = component.files('epw')[0]
      end

      p "Successfully set weather file to #{epw_path}"

      return epw_path
    end
  end
end
