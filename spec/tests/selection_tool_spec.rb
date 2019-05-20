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
require_relative './../spec_helper'

require 'fileutils'
require 'parallel'

RSpec.describe 'SelectionTool' do
  it 'Should validate valid XML file against BuildingSync schema' do
    xml_path = File.expand_path('../files/Example – Valid Schema Invalid UseCase.xml', File.dirname(__FILE__))
    expect(File.exist?(xml_path)).to be true

    selection_tool = BuildingSync::SelectionTool.new(xml_path)
    expect(selection_tool.validate_schema).to be true

    expect(selection_tool.validate_use_case).to be true
  end

  it 'Should not validate invalid XML file against BuildingSync schema' do
    xml_path = File.expand_path('../files/Example – Valid Schema Invalid UseCase.xml', File.dirname(__FILE__))
    expect(File.exist?(xml_path)).to be true

    selection_tool = BuildingSync::SelectionTool.new(xml_path)
    hash_response = selection_tool.get_json_data_from_schema

    if !hash_response['validation_results']['schema']['valid']
      p "#{xml_path} is not valid file against BuildingSync schema"
      hash_response['validation_results']['schema']['errors'].each do |error|
        puts error['message']
      end
    end

    if !hash_response['validation_results']['schema']['valid']
      hash_response['validation_results']['schema']['errors'].each do |error|
        p "#{error['path']} => #{error['message']}"
      end
    end

    expect(hash_response['validation_results']['schema']['valid']).to be false

    expect(hash_response['validation_results']['use_cases']['BRICR']['valid']).to be false
  end
end
