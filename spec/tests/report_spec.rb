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
require 'buildingsync/report'

RSpec.describe 'Report Spec' do
  describe 'Methods' do
    before(:all) do
      # -- Setup
      file_name = 'building_151_level1.xml'
      std = ASHRAE90_1
      xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.2.0')

      @report = BuildingSync::Generator.new.get_report_from_file(xml_path)
    end
    # TODO: Is this the functionality we want?  Or do we only want previous results
    #  to be deleted when we are populating new results?
    it 'Should return nil for get_first_cb_modeled_site_eui since Current Building Modeled data gets wiped on Scenario Instantiation' do
      # -- Setup
      expected_value = nil

      # -- Assert
      expect(@report.get_first_cb_modeled_site_eui).to eql(expected_value)
    end
    it 'Should return get_first_benchmark_site_eui since Benchmark data does not get wiped on Scenario Instantiation' do
      expected_value = 9.7

      # -- Assert
      expect(@report.get_first_benchmark_site_eui).to eql(expected_value)
    end

    it 'Should return auditor_contact_id' do
      # -- Setup
      expected_value = 'Contact1'

      # -- Assert
      expect(@report.get_auditor_contact_id).to eql(expected_value)
    end

    it 'Should return utility_meter_numbers' do
      # -- Setup
      expected_value = '0123456'
      meter_numbers = @report.get_all_utility_meter_numbers
      expect(meter_numbers.size).to eql 1

      # -- Assert
      expect(meter_numbers[0]).to eql(expected_value)
    end

    it 'Should return BenchmarkTool value' do
      # -- Setup
      expected_value = 'Portfolio Manager'
      benchmark = @report.scenarios.find { |scenario| scenario.benchmark? }
      cb_modeled = @report.scenarios.find { |scenario| scenario.cb_modeled? }

      # -- Assert
      expect(benchmark.get_benchmark_tool).to eql(expected_value)
      expect(cb_modeled.get_benchmark_tool).to eql(nil)
    end

    it 'Should return the most recent audit data' do
      # -- Setup
      expected_value = Date.parse('2019-05-01')

      expect(@report.get_newest_audit_date).to eql(expected_value)
    end
  end
end