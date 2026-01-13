# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************
require 'rexml/document'
require 'openstudio/workflow/util/energyplus'

require 'buildingsync/generator'

RSpec.describe 'SiteSpec' do
  it 'should raise an StandardError given a non-Site REXML Element' do
    # -- Setup
    ns = 'auc'
    v = '2.4.0'
    g = BuildingSync::Generator.new(ns, v)
    doc_string = g.create_bsync_root_to_building
    doc = REXML::Document.new(doc_string)
    facility_element = doc.elements["//#{ns}:Facility"]

    # -- Create Site object from Facility
    begin
      BuildingSync::Site.new(facility_element, ns)

      # Should not reach this
      expect(false).to be true
    rescue StandardError => e
      puts e.message
      expect(e.message).to eql 'Attempted to initialize Site object with Element name of: Facility'
    end
  end

  it 'Should create an instance of the site class with minimal XML snippet' do
    g = BuildingSync::Generator.new
    site = g.create_minimum_site('Retail', '1954', 'Gross', '69452')
    expect(site).to be_an_instance_of(BuildingSync::Site)
  end

  it 'Should return the correct building template' do
    g = BuildingSync::Generator.new
    site = g.create_minimum_site('Retail', '1954', 'Gross', '69452')
    site.determine_open_studio_standard(ASHRAE90_1)

    # -- Assert
    puts "expected building template: DOE Ref Pre-1980 but got: #{site.get_standard_template} " if site.get_standard_template != 'DOE Ref Pre-1980'
    expect(site.get_standard_template == 'DOE Ref Pre-1980').to be true
  end

  it 'Should return the correct system type' do
    g = BuildingSync::Generator.new
    site = g.create_minimum_site('Retail', '1954', 'Gross', '69452')
    puts "expected system type: PSZ-AC with gas coil heat but got: #{site.get_system_type} " if site.get_system_type != 'PSZ-AC with gas coil heat'
    expect(site.get_system_type == 'PSZ-AC with gas coil heat').to be true
  end

  it 'Should return the correct building type based on size' do
    g = BuildingSync::Generator.new
    site = g.create_minimum_site('Office', '1954', 'Gross', '10000')
    expect(site.get_building_type == 'SmallOffice').to be true

    g = BuildingSync::Generator.new
    site = g.create_minimum_site('Office', '1954', 'Gross', '20000')
    expect(site.get_building_type == 'MediumOffice').to be true

    g = BuildingSync::Generator.new
    site = g.create_minimum_site('Office', '1954', 'Gross', '25000')
    expect(site.get_building_type == 'MediumOffice').to be true

    g = BuildingSync::Generator.new
    site = g.create_minimum_site('Office', '1954', 'Gross', '75000')
    expect(site.get_building_type == 'LargeOffice').to be true
  end

  it 'Should return the correct building type' do
    g = BuildingSync::Generator.new
    site = g.create_minimum_site('Retail', '1954', 'Gross', '69452')
    puts "expected building type: RetailStandalone but got: #{site.get_building_type} " if site.get_building_type != 'RetailStandalone'
    expect(site.get_building_type == 'RetailStandalone').to be true
  end

  it 'Should return the correct climate zone' do
    g = BuildingSync::Generator.new
    site = g.create_minimum_site('Retail', '1954', 'Gross', '69452')
    puts "expected climate zone: nil but got: #{site.get_climate_zone} " if !site.get_climate_zone.nil?
    expect(site.get_climate_zone.nil?).to be true
  end
end
