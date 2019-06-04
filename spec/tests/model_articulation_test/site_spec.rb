# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2019, Alliance for Sustainable Energy, LLC.
# BuildingSync(R), Copyright (c) 2015-2019, Alliance for Sustainable Energy, LLC.
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

RSpec.describe 'SiteSpec' do

  it 'Should generate meaningful error when passing empty XML data' do

  end

  it 'Should create an instance of the site class with minimal XML snippet' do

  end

  it 'Should return the correct building template' do
    # get_building_template
  end

  it 'Should return the correct system type' do
    # get_system_type
  end

  it 'Should return the correct building type' do
    # get_building_type
  end

  it 'Should return the correct climate zone' do
    # get_climate_zone
  end

  it 'Should write the same OSM file as previously generated' do
    # call generate_baseline_osm
    # call write_osm
    # compare this osm file with a file that was previously generated.
  end

  it 'Should validate XML site data' do
    run_site_spec('building_151_site_withOutBuilding', 'auc')
  end

  it 'Should validate site data' do
    @sites = []
    ns = 'auc'

    xml_path = File.expand_path('../../files/building_151.xml', File.dirname(__FILE__))
    expect(File.exist?(xml_path)).to be true

    doc = create_xml_file_object(xml_path)

    facility_xml = create_facility_object(doc, ns)

    facility_xml.elements.each("#{ns}:Sites/#{ns}:Site") do |site_element|
      @sites.push(BuildingSync::Site.new(site_element, CA_TITLE24, ns))
    end
  end

  def run_site_spec(file_name, ns)
    @sites = []
    xml_path = File.expand_path("../../files/#{file_name}.xml", File.dirname(__FILE__))
    expect(File.exist?(xml_path)).to be true

    doc = create_xml_file_object(xml_path)

    doc.elements.each("/#{ns}:BuildingSync/#{ns}:Sites/#{ns}:Site") do |site_element|
      @sites.push(BuildingSync::Site.new(site_element, CA_TITLE24, ns))
    end
  end

  def create_facility_object(doc, ns)
    facilities = []
    doc.elements.each("/#{ns}:BuildingSync/#{ns}:Facilities/#{ns}:Facility") do |facility_xml|
      facilities.push(facility_xml)
    end
    return facilities[0]
  end

  def create_xml_file_object(xml_file_path)
    doc = nil
    File.open(xml_file_path, 'r') do |file|
      doc = REXML::Document.new(file)
    end
    return doc
  end
end
