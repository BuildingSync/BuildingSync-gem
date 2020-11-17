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
require 'rexml/document'
require 'openstudio/workflow/util/energyplus'

RSpec.describe 'SiteSpec' do
  it 'Should generate meaningful error when passing empty XML data' do
    # -- Setup
    file_name = 'building_151_Blank.xml'
    std = ASHRAE90_1
    xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')
    begin
      generate_baseline_sites(xml_path, 'auc')
    rescue StandardError => e
      puts "expected error message:Year of Construction is blank in your BuildingSync file. but got: #{e.message} " if !e.message.include?('Year of Construction is blank in your BuildingSync file.')
      expect(e.message.include?('Year of Construction is blank in your BuildingSync file.')).to be true
    end
  end

  it 'Should create an instance of the site class with minimal XML snippet' do
    create_minimum_site('Retail', '1954', 'Gross', '69452')
  end

  it 'Should return the correct building template' do
    site = create_minimum_site('Retail', '1954', 'Gross', '69452')
    site.determine_open_studio_standard(ASHRAE90_1)
    puts "expected building template: DOE Ref Pre-1980 but got: #{site.get_building_template} " if site.get_building_template != 'DOE Ref Pre-1980'
    expect(site.get_building_template == 'DOE Ref Pre-1980').to be true
  end

  it 'Should return the correct system type' do
    site = create_minimum_site('Retail', '1954', 'Gross', '69452')
    puts "expected system type: PSZ-AC with gas coil heat but got: #{site.get_system_type} " if site.get_system_type != 'PSZ-AC with gas coil heat'
    expect(site.get_system_type == 'PSZ-AC with gas coil heat').to be true
  end

  it 'Should return the correct building type' do
    site = create_minimum_site('Retail', '1954', 'Gross', '69452')
    puts "expected building type: RetailStandalone but got: #{site.get_building_type} " if site.get_building_type != 'RetailStandalone'
    expect(site.get_building_type == 'RetailStandalone').to be true
  end

  it 'Should return the correct climate zone' do
    site = create_minimum_site('Retail', '1954', 'Gross', '69452')
    puts "expected climate zone: nil but got: #{site.get_climate_zone} " if !site.get_climate_zone.nil?
    expect(site.get_climate_zone.nil?).to be true
  end

  it 'Should write the same OSM file as previously generated - comparing the translated IDF files' do
    # call generate_baseline_osm
    # call write_osm
    # compare this osm file with a file that was previously generated.
    @osm_file_path = File.expand_path('../../files/filecomparison', File.dirname(__FILE__))
    @site = create_minimum_site('Retail', '1980', 'Gross', '20000')
    @site.determine_open_studio_standard(ASHRAE90_1)
    @site.generate_baseline_osm(File.expand_path('../../weather/CZ01RV2.epw', File.dirname(__FILE__)), ASHRAE90_1)
    @site.write_osm(@osm_file_path)

    generate_idf_file(@site.get_model)

    osm_file_full_path = "#{@osm_file_path}/in.idf"
    to_be_comparison_path = "#{@osm_file_path}/originalfiles/in.idf"

    original_file_size = File.size(to_be_comparison_path)
    new_file_size = File.size(osm_file_full_path)
    puts "original idf file size #{original_file_size} bytes versus new idf file size #{new_file_size} bytes"
    expect((original_file_size - new_file_size).abs <= 1).to be true

    line_not_match_counter = compare_two_idf_files("#{@osm_file_path}/in.idf", "#{@osm_file_path}/originalfiles/in.idf")

    expect(line_not_match_counter == 0).to be true
  end

end
