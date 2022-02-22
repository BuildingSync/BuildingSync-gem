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
require_relative './../../spec_helper'

require 'buildingsync/model_articulation/lighting_system'

RSpec.describe 'LightingSystemType' do
  it 'should raise an error given a non-LightingSystem REXML Element' do
    # -- Setup
    ns = 'auc'
    v = '2.2.0'
    g = BuildingSync::Generator.new(ns, v)
    doc_string = g.create_bsync_root_to_building
    doc = REXML::Document.new(doc_string)

    facility_xml = g.get_first_facility_element(doc)

    # -- Create scenario object from report
    begin
      BuildingSync::LightingSystemType.new(facility_xml, ns)
    rescue StandardError => e
      expect(e.message).to eql 'Attempted to initialize LightingSystem object with Element name of: Facility'
    end
  end
  before(:all) do
    # -- Setup
    ns = 'auc'
    @std = ASHRAE90_1
    g = BuildingSync::Generator.new
    doc = g.create_minimum_snippet('Retail', '1980', 'Gross', '20000')
    facility_xml = g.get_first_facility_element(doc)

    # -- Setup paths
    @output_path = File.join(SPEC_OUTPUT_DIR, File.basename(__FILE__, File.extname(__FILE__)).to_s)
    @epw_file_path = File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw')

    @facility = BuildingSync::Facility.new(facility_xml, ns)

    # -- Assert - No systems have been added
    expect(@facility.systems_map.empty?).to be true
    @facility.determine_open_studio_standard(@std)

    # Add a blank lighting system to the facility and link it to the building
    building_id = @facility.site.get_building.xget_id
    @lighting_system = @facility.add_blank_lighting_system(building_id, 'Building')

    # -- Assert Lighting System has been properly added
    expect(@facility.systems_map.key?('LightingSystems')).to be true
    expect(@facility.systems_map['LightingSystems'].size).to eq(1)
    expect(@facility.systems_map['LightingSystems'][0]).to be @lighting_system
    expect(@lighting_system.xget_linked_premises).to eq('Building' => ['Building1'])

    # we need to create a site and call the generate_baseline_osm method in order to set the space types in the model, why are those really needed?
    @facility.generate_baseline_osm(@epw_file_path, @output_path, @std)
  end
  describe 'Model Manipulation' do
    it 'Should add exterior lights successfully' do
      # load_system = BuildingSync::LoadsSystem.new
      expect(@lighting_system.add_exterior_lights(@facility.get_model, @facility.determine_open_studio_system_standard, 1.0, '3 - All Other Areas', false)).to be true
    end

    it 'Should add daylighting controls successfully' do
      standard = Standard.build('DOE Ref Pre-1980')
      expect(@lighting_system.add_daylighting_controls(@facility.get_model, standard, 'DOE Ref Pre-1980', @output_path)).to be true
    end
  end
end
