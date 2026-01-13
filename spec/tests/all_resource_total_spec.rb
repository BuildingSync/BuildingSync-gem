# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************

require 'buildingsync/generator'
require 'buildingsync/all_resource_total'

RSpec.describe 'AllResourceTotal' do
  it 'should raise an error given a non-AllResourceTotal REXML Element' do
    # -- Setup
    ns = 'auc'
    v = '2.4.0'
    g = BuildingSync::Generator.new(ns, v)
    doc_string = g.create_bsync_root_to_building
    doc = REXML::Document.new(doc_string)
    facility_element = doc.elements["//#{ns}:Facility"]

    # -- Create AllResourceTotal object from Facility
    begin
      art = BuildingSync::AllResourceTotal.new(facility_element, ns)

      # Should not reach this
      expect(false).to be true
    rescue StandardError => e
      puts e.message
      expect(e.message).to eql 'Attempted to initialize AllResourceTotal object with Element name of: Facility'
    end
  end
end
