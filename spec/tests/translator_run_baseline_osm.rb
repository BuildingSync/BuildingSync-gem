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
require_relative './../spec_helper'

require 'fileutils'
require 'parallel'

RSpec.describe 'BuildingSync::Translator' do
  it 'BuildingSync::Translator.run_osm("") should successfully run a baseline model: L000_OpenStudio_Pre-Simulation_03.xml' do
    file_name = 'L000_OpenStudio_Pre-Simulation_03.xml'
    xml_path = File.expand_path("../files/#{file_name}", File.dirname(__FILE__))
    expect(File.exist?(xml_path)).to be true
    puts xml_path

    # The output_path will look like:
    # BuildingSync-gem/spec/output/translator_write_osm/L000_OpenStudio_Pre-Simulation_03
    output_path = File.join("../output", "#{File.basename(__FILE__ , File.extname(__FILE__ ))}/#{File.basename(xml_path, File.extname(xml_path))}")
    output_path = File.expand_path(output_path, File.dirname(__FILE__))
    translator = translator_write_osm_checks(xml_path, output_path)
    translator.run_baseline_osm('')

    # Check Baseline directory gets created
    # BuildingSync-gem/spec/output/translator_write_osm/L000_OpenStudio_Pre-Simulation_03/Baseline
    baseline_path = File.join(output_path, 'Baseline')
    expect(Dir.exist?(baseline_path)).to be true

    # Expect job not to have failed
    failed_path = File.join(baseline_path, 'failed.job')
    expect(File.exist?(failed_path)).to be false

    # Expect job finished
    # BuildingSync-gem/spec/output/translator_write_osm/L000_OpenStudio_Pre-Simulation_03/Baseline/finished.job
    finished_path = File.join(baseline_path, 'finished.job')
    expect(File.exist?(finished_path)).to be true
  end

end