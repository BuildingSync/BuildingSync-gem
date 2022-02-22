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
require_relative './../spec_helper'

RSpec.describe 'XmlGetSet' do
  describe 'xget_linked_premises' do
    before(:all) do
      # -- Setup
      ns = 'auc'
      g = BuildingSync::Generator.new
      doc_string = g.create_bsync_root_to_building
      doc = REXML::Document.new(doc_string)
      hvac_system_xml = g.add_hvac_system_to_first_facility(doc)
      g.add_linked_building(hvac_system_xml, 'Building-1')
      g.add_linked_section(hvac_system_xml, 'Section-1')
      g.add_linked_section(hvac_system_xml, 'Section-2')

      d = DummyClass.new(hvac_system_xml, ns)
      @links = d.xget_linked_premises
      puts "Linked Premises: #{@links}"
    end
    it 'is a Hash' do
      expect(@links).to be_an_instance_of(Hash)
    end
    it 'has expected keys' do
      expected_keys = ['Building', 'Section']

      # -- Assert
      expected_keys.each do |k|
        expect(@links.key?(k)).to be true
      end
    end

    it 'has values of type Array and the correct length' do
      expect(@links['Building']).to be_an_instance_of(Array)
      expect(@links['Section']).to be_an_instance_of(Array)

      expect(@links['Building'].size).to eq(1)
      expect(@links['Section'].size).to eq(2)
    end

    it 'has correct values' do
      expect(@links['Building'][0]).to eq('Building-1')
      expect(@links['Section'][0]).to eq('Section-1')
      expect(@links['Section'][1]).to eq('Section-2')
    end
  end
end
