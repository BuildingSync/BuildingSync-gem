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
require 'buildingsync/report'
require 'buildingsync/contact'
require 'buildingsync/helpers/helper'
require 'buildingsync/helpers/xml_get_set'
require 'buildingsync/helpers/Model.hvac'

require_relative 'site'
require_relative 'loads_system'
require_relative 'envelope_system'
require_relative 'hvac_system'
require_relative 'lighting_system'
require_relative 'service_hot_water_system'
require_relative 'measure'

module BuildingSync
  # Facility class
  class Facility
    include BuildingSync::Helper
    include BuildingSync::XmlGetSet
    # initialize
    # @param base_xml [REXML:Element]
    # @param ns [String]
    def initialize(base_xml, ns)
      @base_xml = base_xml
      @ns = ns

      help_element_class_type_check(base_xml, 'Facility')

      @report_xml = nil
      @site_xml = nil

      @site = nil
      @report = nil

      @measures = []
      @contacts = []

      # TODO: Go under Report
      @utility_name = nil
      @utility_meter_numbers = []
      @metering_configuration = nil
      @spaces_excluded_from_gross_floor_area = nil

      @load_system = nil
      @hvac_system = nil

      # reading the xml
      read_xml
    end

    # read xml
    def read_xml
      # Site - checks
      site_xml_temp = @base_xml.get_elements("#{@ns}:Sites/#{@ns}:Site")
      if site_xml_temp.nil? || site_xml_temp.empty?
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Facility.read_xml', "Facility ID: #{xget_id} has no Site elements.  Cannot initialize Facility.")
        raise StandardError, "Facility with ID: #{xget_id} has no Site elements.  Cannot initialize Facility."
      elsif site_xml_temp.size > 1
        @site_xml = site_xml_temp.first
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Facility.read_xml', "Facility ID: #{xget_id}. There is more than one (#{site_xml_temp.size}) Site elements. Only the first Site will be considered (ID: #{@site_xml.attributes['ID']}")
      else
        @site_xml = site_xml_temp.first
      end
      # Create new Site
      @site = BuildingSync::Site.new(@site_xml, @ns)

      # Report - checks
      report_xml_temp = @base_xml.get_elements("#{@ns}:Reports/#{@ns}:Report")
      if report_xml_temp.nil? || report_xml_temp.empty?
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Facility.read_xml', "Facility with ID: #{xget_id} has no Report elements.  Cannot initialize Facility.")
        raise StandardError, "Facility with ID: #{xget_id} has no Report elements.  Cannot initialize Facility."
      elsif report_xml_temp.size > 1
        @report_xml = report_xml_temp.first
        OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Facility.read_xml', "There are more than one (#{report_xml_temp.size}) Report elements in your BuildingSync file. Only the first Report will be considered (ID: #{@report_xml.attributes['ID']}")
      else
        @report_xml = report_xml_temp.first
      end
      # Create new Report
      @report = BuildingSync::Report.new(@report_xml, @ns)

      measures_xml_temp = @base_xml.get_elements("#{@ns}:Measures/#{@ns}:Measure")

      # Measures - create
      if !measures_xml_temp.nil?
        measures_xml_temp.each do |measure_xml|
          if measure_xml.is_a? REXML::Element
            @measures.push(BuildingSync::Measure.new(measure_xml, @ns))
          end
        end
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.read_xml', "Facility with ID: #{xget_id} has #{@measures.size} Measure Objects")
      end

      read_other_details
      read_and_create_initial_systems
    end

    # set_all wrapper for Site
    def set_all
      @site.set_all
    end

    # determine open studio standard
    # @param standard_to_be_used [String]
    # @return [Standard]
    def determine_open_studio_standard(standard_to_be_used)
      return @site.determine_open_studio_standard(standard_to_be_used)
    end

    def set_weather_and_climate_zone(epw_file_path, output_path, standard_to_be_used, ddy_file = nil)
      @site.set_weather_and_climate_zone(epw_file_path, standard_to_be_used, ddy_file = nil)
    end

    # get space types
    # @return [Array<OpenStudio::Model::SpaceType>]
    def get_space_types
      return @site.get_space_types
    end

    # get epw_file_path
    # @return [String]
    def get_epw_file_path
      @site.get_epw_file_path
    end

    # Get the ContactName specified by the AuditorContactID/@IDref
    # @return [String] if exists
    # @return [nil] if not
    def get_auditor_contact_name
      auditor_id = @report.get_auditor_contact_id
      if !auditor_id.nil?
        contact = @contacts.find { |contact| contact.xget_id == auditor_id }
        return contact.xget_text('ContactName')
      end
      return nil
    end

    # determine OpenStudio system standard
    # @return [Standard]
    def determine_open_studio_system_standard
      return @site.determine_open_studio_system_standard
    end

    # @see BuildingSync::Report.add_cb_modeled
    def add_cb_modeled(id = 'Scenario-Baseline')
      @report.add_cb_modeled(id)
    end

    # read other details from the xml
    # - contact information
    # - audit levels and dates
    # - Utility information
    # - UDFs
    def read_other_details
      # Get Contact information
      @base_xml.elements.each("#{@ns}:Contacts/#{@ns}:Contact") do |contact|
        @contacts << BuildingSync::Contact.new(contact, @ns)
      end
    end


    # TODO: I don't think we want any of this.
    # write parameters to xml
    def prepare_final_xml
      @site.prepare_final_xml
    end

    attr_reader :site, :report, :measures, :contacts
  end
end
