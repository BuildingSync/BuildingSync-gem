# frozen_string_literal: true

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

RSpec.describe 'Translator' do
  describe "Example Full Workflow" do
    tests = [
        # file_name, standard, epw_path, schema_version
        ['building_151.xml', CA_TITLE24, nil, 'v2.2.0'],
        ['L000_OpenStudio_Pre-Simulation_02.xml', ASHRAE90_1, nil, 'v2.2.0']
    ]
    tests.each do |test|
      it 'Should Run the Prototypical Workflow' do
        file_name = test[0]
        std = test[1]
        epw_path = test[2]
        version = test[3]
        xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, version)
        results_xml = File.join(output_path, 'results.xml')

        # This should be the prototypical workflow in most cases.
        # 1. Create new translator from file
        # 2. Perform a SR to get an OSM with efficiencies / etc. for the location
        #    determined from the location defined in the BSync file
        # OR
        #   for the location overriden by the epw file
        # 3. Write new scenarios for
        translator = BuildingSync::Translator.new(xml_path, output_path, epw_path, std)
        translator.setup_and_sizing_run

        # -- Assert sizing run performs as expected
        sizing_run_checks(output_path)

        workflows_successfully_written = translator.write_osws

        # -- Assert
        expect(workflows_successfully_written).to be true
        failures = translator.run_osws

        # -- Assert no failures
        expect(failures.empty?).to be true

        translator.gather_results

        # -- Assert result_gathered set to true
        expect(translator.results_gathered).to be true

        translator.prepare_final_xml

        # -- Assert final_xml_prepared set to true
        expect(translator.final_xml_prepared).to be true

        # -- Assert file doesn't exist
        expect(File.exist?(results_xml)).to be false

        translator.save_xml

        # -- Assert file exists
        expect(File.exist?(results_xml)).to be true
      end
    end
  end
end
