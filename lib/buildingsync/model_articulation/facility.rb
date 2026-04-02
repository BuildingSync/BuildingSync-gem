# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************
require 'buildingsync/report'
require 'buildingsync/contact'
require 'buildingsync/helpers/helper'
require 'buildingsync/helpers/xml_get_set'
require 'pry'

require_relative 'site'
require_relative 'measure'
require_relative 'systems_map'


module BuildingSync
  # Facility class
  class Facility
    include BuildingSync::Helper
    include BuildingSync::XmlGetSet
    # initialize
    # @param base_xml [REXML:Element]
    # @param ns [String]
    def initialize(base_xml, ns, standard_to_be_used)
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
      @standard_to_be_used = standard_to_be_used

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
      @site = BuildingSync::Site.new(@site_xml, @ns, @standard_to_be_used)

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
    end

    # set_all wrapper for Site
    def set_all
      @site.set_all
    end

    # set standard template
    def set_standard_template
      @site.set_standard_template
    end

    def set_weather_and_climate_zone(epw_file_path)
      @site.set_weather_and_climate_zone(epw_file_path)
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

    # get sum of /Systems/LightingSystems/PlugLoads/WeightedAverageLoad
    # @return [String]
    def get_total_weighted_average_load
      # if no plug_loads, return nil
      plug_loads = @base_xml.elements["#{@ns}:Systems/#{@ns}:PlugLoads/"]
      return nil if plug_loads.nil?

      # get all weighted_average_loads
      plug_loads = plug_loads.reject {|s| s.class == REXML::Comment}
      all_weighted_average_loads = plug_loads.map {|s| s.elements["#{@ns}:WeightedAverageLoad/"]}

      # if any nil, return nil, else return sum
      return nil if !all_weighted_average_loads.all?
      return all_weighted_average_loads.map {|s| s.first.to_s.to_f}.sum
    end

    # get sum of /Systems/LightingSystems/LightingSystem/InstalledPower
    # @return [String]
    def get_total_installed_power
      # if no lighting systems, return nil
      lighting_systems = @base_xml.elements["#{@ns}:Systems/#{@ns}:LightingSystems/"]
      return nil if lighting_systems.nil?

      # get all all_installed_powers
      lighting_systems = lighting_systems.reject {|s| s.class == REXML::Comment}
      all_installed_powers = lighting_systems.map {|s| s.elements["#{@ns}:InstalledPower/"]&.first&.to_s&.to_f}

      # if any nil, return nil, else return sum
      return nil if !all_installed_powers.all?
      return all_installed_powers.sum
    end

    # get principal hvac system type
    # @return [String]
    def get_principal_HVAC_system_type
      # if no hvac systems, return nil
      hvac_systems = @base_xml.elements["#{@ns}:Systems/#{@ns}:HVACSystems/"]
      return nil if hvac_systems.nil?

      # find first none nil principal_HVAC_system_type
      hvac_systems = hvac_systems.reject {|s| s.class == REXML::Comment}
      first_principal_HVAC_system_type = hvac_systems.find {|s| s.elements["#{@ns}:PrincipalHVACSystemType/"]}

      # if none, return nil, else return mapping
      return nil if first_principal_HVAC_system_type.nil?
      return BuildingSyncToOSSystemMaps.get_hvac_map[first_principal_HVAC_system_type.to_s]
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
