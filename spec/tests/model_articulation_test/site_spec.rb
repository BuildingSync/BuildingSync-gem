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
require 'rexml/document'
require 'openstudio/workflow/util/energyplus'

require 'buildingsync/generator'

RSpec.describe 'SiteSpec' do
  it 'should raise an StandardError given a non-Site REXML Element' do
    # -- Setup
    ns = 'auc'
    v = '2.2.0'
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

  it 'Should write the same IDF file as previously generated' do
    # We don't compare OSM files because the GUIDs change
    g = BuildingSync::Generator.new
    @osm_file_path = File.join(SPEC_FILES_DIR, 'filecomparison')
    @site = g.create_minimum_site('Retail', '1980', 'Gross', '20000')
    @site.determine_open_studio_standard(ASHRAE90_1)
    epw_file_path = File.join(SPEC_WEATHER_DIR, 'CZ01RV2.epw')
    @site.generate_baseline_osm(epw_file_path, ASHRAE90_1)
    @site.write_osm(@osm_file_path)

    generate_idf_file(@site.get_model)

    new_idf = "#{@osm_file_path}/in.idf"
    original_idf = "#{@osm_file_path}/originalfiles/in.idf"

    line_not_match_counter = compare_two_idf_files(original_idf, new_idf)

    expect(line_not_match_counter == 0).to be true
  end
end
