# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
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
