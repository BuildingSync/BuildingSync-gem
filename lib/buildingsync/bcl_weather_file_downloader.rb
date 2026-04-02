# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************
require 'json'
require 'httparty'
require 'buildingsync/constants'
require 'rexml/document'
require 'zip'
require 'stringio'


module BuildingSync
  class BCLWeatherFileDownloader
    @@base_BCL_uri = 'https://bcl.nrel.gov/api/search'
    @@base_EP_uri = 'https://energyplus-weather.s3.amazonaws.com/north_and_central_america_wmo_region_4'

    def self.download_weather_file_from_city_name(city_name, state_name)
      # from BCL, get closest weather station to city
      response = HTTParty.get("#{@@base_BCL_uri}/location:#{city_name.gsub(' ', '+')},#{state_name}.xml?fq=component_tags:\"Weather File\"")
      results = REXML::Document.new(response.body, {ignore_whitespace_nodes: :all, compress_whitespace: :all}).elements["results"]
      results = results.children.filter {|x| x.name == "result"}

      if results.empty?
         raise StandardError, "No weather files found within a 40 mile radius #{city_name},#{state_name} within the BCL."
      end

      # just pick the closest
      result = results[0]
      filenames = result.elements["component/files"].children.map {|x| x.elements["filename"].text}
      filename = filenames[0]
      filename[".epw"] = ""
      state_name = filename.split("_")[1]

      # from ep, get the zip
      uri = "#{@@base_EP_uri}/USA/#{state_name}/#{filename}/#{filename}.zip"
      response = HTTParty.get(uri)

      # extract and write the zip to disk
      Zip::InputStream.open(::StringIO.new(response.body)) do |zip_stream|
        while entry = zip_stream.get_next_entry
          filepath = File.join(WEATHER_DIR, entry.name)
          File.open(filepath, 'w') { |file| file.write(entry.get_input_stream.read) }
        end
      end


      return  File.join(WEATHER_DIR, filename + ".epw")
    end
  end
end
