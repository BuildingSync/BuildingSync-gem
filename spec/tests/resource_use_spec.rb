# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************

require 'buildingsync/generator'
require 'buildingsync/resource_use'

RSpec.describe 'ResourceUse' do
  it 'should raise an error given a non-ResourceUse REXML Element' do
    # -- Setup
    ns = 'auc'
    v = '2.4.0'
    g = BuildingSync::Generator.new(ns, v)
    doc_string = g.create_bsync_root_to_building
    doc = REXML::Document.new(doc_string)
    facility_element = doc.elements["//#{ns}:Facility"]

    # -- Create ResourceUse object from Facility
    begin
      ru = BuildingSync::ResourceUse.new(facility_element, ns)

      # Should not reach this
      expect(false).to be true
    rescue StandardError => e
      puts e.message
      expect(e.message).to eql 'Attempted to initialize ResourceUse object with Element name of: Facility'
    end
  end
end
