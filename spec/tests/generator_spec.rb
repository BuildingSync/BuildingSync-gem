# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2021, Alliance for Sustainable Energy, LLC.
# BuildingSync(R), Copyright (c) 2015-2021, Alliance for Sustainable Energy, LLC.
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
