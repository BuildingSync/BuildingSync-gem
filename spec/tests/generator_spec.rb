# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************
require 'buildingsync/generator'

RSpec.describe 'BuildingSync::Generator' do
  it 'should set the version to nil if it is not a supported type' do
    g = BuildingSync::Generator.new('auc', 'asdflkj')
    expect(g.version.nil?).to be true
  end

  it 'create_bsync_root_to_section should return a String' do
    g = BuildingSync::Generator.new
    doc_string = g.create_bsync_root_to_building
    expect(doc_string).to be_an_instance_of(String)
  end

  it 'create_bsync_root_to_section should be able to create an REXML::Document from the returned String' do
    g = BuildingSync::Generator.new
    doc_string = g.create_bsync_root_to_building
    doc = REXML::Document.new(doc_string)
    expect(doc).to be_an_instance_of(REXML::Document)
  end

  it 'create_minimum_snippet should return an REXML::Document' do
    g = BuildingSync::Generator.new
    snippet = g.create_minimum_snippet('Retail')
    expect(snippet).to be_an_instance_of(REXML::Document)
  end

  it 'create_calculation_method_element(result) should correctly create and return an auc:CalculationMethod element' do
    ns = 'auc'
    g = BuildingSync::Generator.new

    # -- Setup
    # Create a dummy result
    result_success = {}
    result_failed = {}
    result_xxx = {}

    result_success[:completed_status] = 'Success'
    result_failed[:completed_status] = 'Failed'
    result_xxx[:completed_status] = 'XXX'

    calc_method_success = g.create_calculation_method_element(result_success)
    calc_method_failed = g.create_calculation_method_element(result_failed)
    calc_method_xxx = g.create_calculation_method_element(result_xxx)

    # -- Assert
    expect(calc_method_success.elements["#{ns}:Modeled/#{ns}:SimulationCompletionStatus"].text).to be == 'Finished'
    expect(calc_method_failed.elements["#{ns}:Modeled/#{ns}:SimulationCompletionStatus"].text).to eq 'Failed'
    expect(calc_method_xxx.elements["#{ns}:Modeled/#{ns}:SimulationCompletionStatus"].text).to eq 'Failed'
  end
end
