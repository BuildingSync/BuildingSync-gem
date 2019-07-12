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
    def download_weather_file_from_city_name(state, city)
      wmo_no = 0
      remote = OpenStudio::RemoteBCL.new

      # Search for weather files
      responses = remote.searchComponentLibrary(city, 'Weather File')
      choices = OpenStudio::StringVector.new

      filter_response = find_response_from_given_state(responses, state)
      if !filter_response.nil?
        choices << filter_response.uid
        filter_response.attributes.each do |attribute|
          if attribute.name == 'WMO'
            wmo_no = attribute.valueAsDouble
          end
        end
      end

      if choices.count == 0
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.GetBCLWeatherFile.download_weather_file_from_city_name',
                           "Error, could not find uid for state #{state} and city #{city}. Initial count of weather files: #{responses.count}. Please try a different weather file.")
        return false
      end

      epw_path = download_weather_file(remote, choices)
      download_design_day_file(wmo_no, epw_path)
      return epw_path
    end

    def download_weather_file_from_weather_id(weather_id)
      wmo_no = 0
      remote = OpenStudio::RemoteBCL.new

      # Search for weather files
      responses = remote.searchComponentLibrary(weather_id, 'Weather File')

      choices = OpenStudio::StringVector.new

      responses.each do |response|
        if response.name.include? 'TMY3'
          choices << response.uid

          response.attributes.each do |attribute|
            if attribute.name == 'WMO'
              wmo_no = attribute.valueAsDouble
            end
          end
        end
      end

      if choices.count == 0
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.GetBCLWeatherFile.download_weather_file_from_weather_id',
                           "Error, could not find uid for #{name.valueAsString}.  Please try a different weather file.")
        return false
      end

      epw_path = download_weather_file(remote, choices)
      download_design_day_file(wmo_no, epw_path)
      return epw_path
    end

    def download_weather_file(remote, choices)
      epw_path = ''

      choices.each do |uid|
        remote.downloadComponent(uid)
        component = remote.waitForComponentDownload

        if component.empty?
          OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.GetBCLWeatherFile.download_weather_file',
                             "Error, cannot find the EPW weather file with uid: #{uid}.  Please try a different weather file.")
          return false
        end

        component = component.get

        files = component.files('epw')

        if files.empty?
          OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.GetBCLWeatherFile.download_weather_file',
                             "Error, cannot find the EPW weather file within the downloaded zip container with uid: #{uid}.  Please try a different weather file.")
          return false
        end

        epw_weather_file_path = component.files('epw')[0]
        dir_path = File.dirname(epw_weather_file_path)
        weather_file_name = File.basename(epw_weather_file_path)

        epw_path = File.expand_path('../../spec/weather', File.dirname(__FILE__))

        Dir.glob("#{dir_path}/**/*.*").each do |filename|
          FileUtils.mv(filename, epw_path)
        end
        epw_path = File.expand_path("../../spec/weather/#{weather_file_name}", File.dirname(__FILE__))

      end

      puts "Successfully set weather file to #{epw_path}"

      return epw_path
    end

    def download_design_day_file(wmo_no, epw_path)
      remote = OpenStudio::RemoteBCL.new
      responses = remote.searchComponentLibrary(wmo_no.to_s[0, 6], 'Design Day')
      choices = OpenStudio::StringVector.new

      idf_path_collection = []

      responses.each do |response|
        choices << response.uid
      end

      choices.each do |uid|
        remote.downloadComponent(uid)
        component = remote.waitForComponentDownload

        if !component.empty?

          component = component.get

          files = component.files('idf')

          if !files.empty?
            idf_path_collection.push(component.files('idf')[0])
          else
            OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.GetBCLWeatherFile.download_design_day_file',
                               "Error, cannot find the design day file within the downloaded zip container with uid: #{uid}.  Please try a different weather file.")
          end
        else
          OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.GetBCLWeatherFile.download_design_day_file',
                             "Error, cannot find local component for: #{uid}.  Please try a different weather file.")
        end
      end
      create_ddy_file(idf_path_collection, epw_path)
    end

    def create_ddy_file(idf_path_collection, epw_path)
      idf_file_lines = []

      idf_path_collection.each do |idf_file_path|
        idf_file = File.open(idf_file_path)
        idf_file_lines.push(idf_file.readlines)
      end

      design_day_path = File.dirname(epw_path)
      weather_file_name = File.basename(epw_path, '.*')
      design_day_file = File.new("#{design_day_path}/#{weather_file_name}.ddy", 'w')

      idf_file_lines.each do |line|
        design_day_file.puts(line)
      end

      design_day_file.close
    end

    def find_response_from_given_state(responses, state)
      responses.each do |response|
        if response.name.include? 'TMY3'
          response.attributes.each do |attribute|
            if attribute.name == 'State'
              if attribute.valueAsString == state
                return response
              end
            end
          end
        end
      end
      return nil
    end
  end
end
