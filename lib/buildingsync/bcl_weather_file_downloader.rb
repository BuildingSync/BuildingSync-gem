# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2022, Alliance for Sustainable Energy, LLC.
# BuildingSync(R), Copyright (c) 2015-2022, Alliance for Sustainable Energy, LLC.
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
require 'HTTParty'
require 'buildingsync/constants'
require 'rexml/document'


module BuildingSync
  class BCLWeatherFileDownloader
    @@base_BCL_uri = 'https://bcl.nrel.gov/api/search'
    @@base_EP_uri = 'https://energyplus-weather.s3.amazonaws.com/north_and_central_america_wmo_region_4'

    def self.download_weather_file_from_city_name(city_name, state_name)
      # from BCL, get closest weather station to city
      response = HTTParty.get("#{@@base_BCL_uri}/location:#{city_name.gsub! ' ', '+'},#{state_name}.xml?fq=component_tags:\"Weather File\"")
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
