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
require 'uri'
require 'net/http'
require 'net/http/post/multipart'

module BuildingSync
  # Class for communicating with SelectionTool
  class SelectionTool
    # initialize the selection tools class
    # @note See documentation here: https://github.com/buildingsync/selection-tool#validator
    # @note Use core Net::HTTPS
    # @param xml_path [String]
    def initialize(xml_path, version = '2.0.0')
      @hash_response = nil
      version = '2.0.0' if version.nil?
      url = URI.parse('https://selectiontool.buildingsync.net/api/validate')

      params = { 'schema_version' => version }
      params[:file] = UploadIO.new(xml_path, 'text/xml', File.basename(xml_path))

      request = Net::HTTP::Post::Multipart.new(url.path, params)
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      response = http.request(request)

      @hash_response = JSON.parse(response.read_body)
    end

    # validate use case
    # @param use_case [String]
    # @return boolean
    def validate_use_case(use_case)
      if !@hash_response['validation_results']['use_cases'][use_case]['valid']
        @hash_response['validation_results']['use_cases'][use_case]['errors'].each do |error|
          p "#{error['path']} => #{error['message']}"
        end
      end

      return @hash_response['validation_results']['use_cases'][use_case]['valid']
    end

    # validate schema
    # @return boolean
    def validate_schema
      if !@hash_response['validation_results']['schema']['valid']
        @hash_response['validation_results']['schema']['errors'].each do |error|
          p error['message']
        end
      end

      return @hash_response['validation_results']['schema']['valid']
    end
  end
end
