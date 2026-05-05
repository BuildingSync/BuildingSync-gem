# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************

require 'buildingsync/audit_date'
require 'buildingsync/scenario'
require 'buildingsync/utility'

module BuildingSync
  # Report class
  class Report
    include BuildingSync::Helper
    include BuildingSync::XmlGetSet
    # @param base_xml [REXML::Element]
    # @param ns [String]
    def initialize(base_xml, ns)
      @base_xml = base_xml
      @ns = ns
      help_element_class_type_check(base_xml, 'Report')

      @scenarios = []
      @audit_dates = []
      @utilities = []

      # Special scenarios
      @cb_modeled = nil
      @cb_measured = []
      @poms = []

      read_xml
    end

    def read_xml
      read_scenarios

      # Audit dates
      @base_xml.elements.each("#{@ns}:AuditDates/#{@ns}:AuditDate") do |audit_date|
        @audit_dates << BuildingSync::AuditDate.new(audit_date, @ns)
      end

      # Utilities
      @base_xml.elements.each("#{@ns}:Utilities/#{@ns}:Utility") do |utility|
        @utilities << BuildingSync::Utility.new(utility, @ns)
      end
    end

    def read_scenarios
      # Scenarios - create and checks
      scenarios_xml_temp = @base_xml.get_elements("#{@ns}:Scenarios/#{@ns}:Scenario")
      cb_modeled = []
      scenarios_xml_temp&.each do |scenario_xml|
        if scenario_xml.is_a? REXML::Element
          sc = BuildingSync::Scenario.new(scenario_xml, @ns)
          @scenarios.push(sc)
          cb_modeled << sc if sc.cb_modeled?
          @cb_measured << sc if sc.cb_measured?
          @poms << sc if sc.pom?
        end
      end

      # -- Issue warnings for undesirable situations
      if @scenarios.empty?
        OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Facility.read_xml', 'No Scenario elements found')
      end

      # -- Logging for Scenarios
      if cb_modeled.empty?
        OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Facility.read_xml', 'A Current Building Modeled Scenario is required.')
      elsif cb_modeled.size > 1
        @cb_modeled = cb_modeled[0]
        OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Facility.read_xml', "Only 1 Current Building Modeled Scenario is supported.  Using Scenario with ID: #{@cb_modeled.xget_id}")
      else
        @cb_modeled = cb_modeled[0]
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.read_xml', "Current Building Modeled Scenario has ID: #{@cb_modeled.xget_id}")
      end
    end

    def get_all_utility_meter_numbers
      all = []
      @utilities.each do |utility|
        all += utility.get_utility_meter_numbers
      end
      return all
    end

    def get_all_utility_names
      all = []
      @utilities.each do |utility|
        all += utility.get_utility_meter_numbers
      end
      return all
    end

    def get_auditor_contact_id
      return xget_attribute_for_element('AuditorContactID', 'IDref')
    end

    def get_newest_audit_date
      dates = []
      @audit_dates.each do |date|
        dates << date.xget_text_as_date('Date')
      end
      return dates.max
    end

    def get_oldest_audit_date
      dates = []
      @audit_dates.each do |date|
        dates << date.xget_text_as_date('Date')
      end
      return dates.min
    end

    # Get the SiteEnergyUseIntensity for the benchmark scenario.
    # Where multiple benchmark scenarios exist, the value from the first is returned
    # @see get_scenario_site_eui
    def get_first_benchmark_site_eui
      eui = []
      ids = []
      @scenarios.each do |scenario|
        if scenario.benchmark?
          eui << get_first_scenario_site_eui(scenario)
          ids << scenario.xget_id
        end
      end
      if eui.size == 1
        return eui[0]
      elsif eui.empty?
        OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Facility.get_benchmark_site_eui', 'No Benchmark Scenarios exist with SiteEnergyUseIntensity defined')
        return nil
      elsif eui.size > 1
        OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Facility.get_benchmark_site_eui', "Multiple Benchmark Scenarios exist with SiteEnergyUseIntensity defined. Returning the value for Scenario ID: #{ids[0]}")
        return eui[0]
      end
    end

    # Get the SiteEnergyUseIntensity for the cb_modeled scenario.
    # @see get_scenario_site_eui
    def get_first_cb_modeled_site_eui
      return get_first_scenario_site_eui(@cb_modeled)
    end

    # Get the AllResourceTotal/SiteEnergyUseIntensity value as a float.
    # Where multiple AllResourceTotals exist with the value defined, the first is returned.
    # @param scenario [BuildingSync::Scenario] the scenario
    # @return [Float] if atleast one value is found
    # @return [nil] if no value is found
    def get_first_scenario_site_eui(scenario)
      eui = []
      scenario.get_all_resource_totals.each do |art|
        eui << art.xget_text_as_float('SiteEnergyUseIntensity')
      end
      if eui.size == 1
        return eui[0]
      elsif eui.empty?
        OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Facility.get_scenario_site_eui', "Scenario ID: #{@cb_modeled.xget_id} does not have a SiteEnergyUseIntensity defined in any of the AllResourceTotal elements.")
        return nil
      elsif eui.size > 1
        OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.Facility.get_scenario_site_eui', "Scenario ID: #{@cb_modeled.xget_id} has more thant 1 (#{eui.size}) SiteEnergyUseIntensity defined in the AllResourceTotal elements. Returning the first.")
        return eui[0]
      end
    end

    # add a current building modeled scenario and set the @cb_modeled attribute
    # @param id [String] id to use for the scenario
    # @return [NilClass]
    def add_cb_modeled(id = 'Scenario-Baseline')
      if @cb_modeled.nil? || @cb_modeled.empty?
        g = BuildingSync::Generator.new
        scenario_xml = g.add_scenario_to_report(@base_xml, 'CBModeled', id)
        scenario = BuildingSync::Scenario.new(scenario_xml, @ns)
        @scenarios.push(scenario)
        @cb_modeled = scenario
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.WorkflowMaker.add_cb_modeled', "A Current Building Modeled scenario was added (Scenario ID: #{@cb_modeled.xget_id}).")
      else
        OpenStudio.logFree(OpenStudio::Warn, 'BuildingSync.WorkflowMaker.add_cb_modeled', "A Current Building Modeled scenario already exists (Scenario ID: #{@cb_modeled.xget_id}). A new one was not added.")
      end
    end

    attr_reader :scenarios, :cb_modeled, :cb_measured, :poms, :utilities
  end
end
