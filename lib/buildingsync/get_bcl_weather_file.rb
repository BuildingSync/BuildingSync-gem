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
require 'json'

module BuildingSync
  # GetBCLWeatherFile class to manage the process of getting weather files from BCL
  class GetBCLWeatherFile
    # prefix for data weather path
    $weather_file_path_prefix = '../data/weather/'.freeze

    # download weather file from city name
    # @param state [String]
    # @param city [String]
    # @return string
    def download_weather_file_from_city_name(state, city)
      weather_file_name = get_weather_file_from_city(city)

      if !weather_file_name.empty?
        return File.expand_path("#{$weather_file_path_prefix}#{weather_file_name}", File.dirname(__FILE__))
      else
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
    end

    # download weather file from weather id
    # @param weather_id [String]
    # @return string
    def download_weather_file_from_weather_id(weather_id)
      weather_file_name = get_weather_file_from_weatherid(weather_id)

      if !weather_file_name.empty?
        return File.expand_path("#{$weather_file_path_prefix}#{weather_file_name}", File.dirname(__FILE__))
      else
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
                             "Error, could not find uid for #{weather_id}.  Please try a different weather file.")
          return false
        end

        epw_path = download_weather_file(remote, choices)
        download_design_day_file(wmo_no, epw_path)
        return epw_path
      end
    end

    # download weather file
    # @param remote [OpenStudio::RemoteBCL]
    # @param choices [OpenStudio::StringVector]
    # @return string
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

        epw_path = File.expand_path($weather_file_path_prefix.to_s, File.dirname(__FILE__))

        Dir.glob("#{dir_path}/**/*.*").each do |filename|
          FileUtils.mv(filename, epw_path)
        end
        epw_path = File.expand_path("#{$weather_file_path_prefix}/#{weather_file_name}", File.dirname(__FILE__))
      end

      puts "Successfully set weather file to #{epw_path}"
      return epw_path
    end

    # download design day file
    # @param wmo_no [String]
    # @param epw_path [String]
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

            raise "Error, cannot find the design day file within the downloaded zip container with uid: #{uid}.  Please try a different weather file."
          end
        else
          OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.GetBCLWeatherFile.download_design_day_file',
                             "Error, cannot find local component for: #{uid}.  Please try a different weather file.")
          raise "Error, cannot find local component for: #{uid}.  Please try a different weather file."
        end
      end

      puts "Successfully downloaded ddy file to #{epw_path}"
      create_ddy_file(idf_path_collection, epw_path)
      puts "Successfully combined design day files to ddy file in #{epw_path}"
      if update_json_file(epw_path)
        puts 'JSON file updated'
      else
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.GetBCLWeatherFile.update_json_file',
                           "Error, cannot write JSON file for downloaded weather file #{epw_path}.  The format of the weather file seems incorrect.")
      end
    end

    # create design day file (ddy)
    # @param idf_path_collection [array<string>]
    # @param epw_path [String]
    # @return [Boolean]
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

    # update the JSON file
    # @param epw_path [String]
    # @return [Boolean]
    def update_json_file(epw_path)
      weather_file = File.open(epw_path)
      location = weather_file.readlines.first.split(',')

      weather_file_name = File.basename(epw_path)
      if location.length < 5
        return false
      end
      city_name = location[1]
      state_code = location[2]
      weather_id = location[5]

      weather_file_path = File.expand_path("#{$weather_file_path_prefix}/weather_file.json", File.dirname(__FILE__))

      if !File.exist?(weather_file_path)
        create_json_file(weather_file_path)
      end

      weather_json = eval(File.read(weather_file_path))

      weather_json[:weather_file_name] << weather_file_name
      weather_json[:city_name] << city_name
      weather_json[:state_code] << state_code
      weather_json[:weather_id] << weather_id

      File.open(weather_file_path, 'w') { |f| f.write(weather_json.to_json) }
      return true
    end

    # read JSON file
    def read_json_file
      weather_file_path = File.expand_path("#{$weather_file_path_prefix}/weather_file.json", File.dirname(__FILE__))
      File.open(weather_file_path) do |f|
        str = f.gets
        p str
        # start parsing
      end
    end

    # get weather file from weather ID
    # @param weather_id [String]
    # @return [String]
    def get_weather_file_from_weatherid(weather_id)
      weather_file_name = ''

      json = get_weather_json_data

      is_found, counter = weatherid_found_in_json_data(json, weather_id)

      weather_file_name = json[:weather_file_name][counter] if is_found

      return weather_file_name
    end

    # check if weather ID is found in JSON data
    # @param json [JSON]
    # @param weather_id [String]
    # @return [array<boolean, int>]
    def weatherid_found_in_json_data(json, weather_id)
      counter = 0
      json[:weather_id].each do |cname|
        if cname.include? weather_id
          return true, counter
        end
        counter += 1
      end
      return false, counter
    end

    # get weather file from city
    # @param city [String]
    # @return [String]
    def get_weather_file_from_city(city)
      weather_file_name = ''

      json = get_weather_json_data

      is_found, counter = city_found_in_json_data(json, city)

      weather_file_name = json[:weather_file_name][counter] if is_found

      return weather_file_name
    end

    # city found in JSON data
    # @param json [JSON]
    # @param city [String]
    # @return [array<boolean, int>]
    def city_found_in_json_data(json, city)
      counter = 0
      json[:city_name].each do |cname|
        if cname.include? city
          return true, counter
        end
        counter += 1
      end
      return false, counter
    end

    # city found in JSON data
    # @return [object]
    def get_weather_json_data
      weather_file_path = File.expand_path("#{$weather_file_path_prefix}/weather_file.json", File.dirname(__FILE__))
      create_json_file(weather_file_path) if !File.exist?(weather_file_path)

      return eval(File.read(weather_file_path))
    end

    # create JSON file
    # @param weather_file_path [String]
    def create_json_file(weather_file_path)
      weather_file_folder = File.expand_path($weather_file_path_prefix.to_s, File.dirname(__FILE__))
      FileUtils.mkdir_p weather_file_folder
      weather_file = File.new("#{weather_file_folder}/weather_file.json", 'w')

      arr = []
      weather_detail = {
        'weather_file_name' => arr,
        'city_name' => arr,
        'state_code' => arr,
        'weather_id' => arr
      }

      File.open(weather_file_path, 'w') { |f| f.write(weather_detail.to_json) }
    end

    # find response from given state
    # @param responses [array<BCLSearchResult>]
    # @param state [String]
    # @return [BCLSearchResult]
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
