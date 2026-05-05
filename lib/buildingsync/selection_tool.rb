# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************
require 'uri'
require 'net/http'
require 'net/http/post/multipart'

module BuildingSync
  # Class for communicating with SelectionTool on the BuildingSync website
  class SelectionTool
    # initialize the selection tools class
    # @note See documentation here: https://github.com/buildingsync/buildingsync-website#validator
    # @note Use core Net::HTTPS
    # @param xml_path [String]
    def initialize(xml_path, version = '2.4.0')
      @hash_response = nil
      version = '2.4.0' if version.nil?
      url = URI.parse('https://buildingsync.net/api/validate')

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
      use_cases = @hash_response['validation_results']['use_cases']
      if use_cases.key?(use_case)
        if !use_cases[use_case]['valid']
          use_cases[use_case]['errors'].each do |error|
            puts error
          end
        end
        return use_cases[use_case]['valid']
      else
        puts "BuildingSync::SelectionTool.validate_use_case, Use Case #{use_case} is not an option.  The available use cases to validate against are: #{use_cases}"
        return false
      end
    end

    # validate schema
    # @return boolean
    def validate_schema
      if !@hash_response['validation_results']['schema']['valid']
        @hash_response['validation_results']['schema']['errors'].each do |error|
          puts error
        end
      end
      return @hash_response['validation_results']['schema']['valid']
    end

    attr_reader :hash_response
  end
end
