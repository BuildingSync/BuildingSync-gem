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

RSpec.describe 'WorkFlow Maker' do
  it 'should save results to xml file' do
    file_name = 'building_151.xml'
    xml_path = File.expand_path("./../files/#{file_name}", File.dirname(__FILE__))
    expect(File.exist?(xml_path)).to be true

    ns = 'auc'
    doc = BuildingSync::Helper.read_xml_file_document(xml_path)
    workflow_maker = BuildingSync::WorkflowMaker.new(doc, ns)
    result = {}
    result[:completed_status] = 'Success'

    variables = {}
    variables['total_site_energy_savings_mmbtu'] = 100
    variables['total_source_energy_savings_mmbtu'] = 200
    variables['total_energy_cost_savings'] = 300
    variables['baseline_fuel_electricity_kbtu'] = 400
    variables['fuel_electricity_kbtu'] = 500
    variables['baseline_fuel_natural_gas_kbtu'] = 600
    variables['fuel_natural_gas_kbtu'] = 700
    variables['annual_peak_electric_demand_kw'] = 800

    scenarios = workflow_maker.get_scenario_elements
    scenarios.each do |scenario|
      puts "scenario: #{scenario}"
      scenario_name = scenario.elements["#{ns}:ScenarioName"].text
      puts "scenario_name: #{scenario_name}"
      package_of_measures = workflow_maker.delete_previous_results(scenario)
      puts "package_of_measures: #{package_of_measures}"
      if package_of_measures.length > 0
        expect(workflow_maker.add_results_to_scenario(package_of_measures, scenario, scenario_name, {}, result, nil, nil)).to be false
        expect(workflow_maker.add_results_to_scenario(package_of_measures, scenario, scenario_name, variables, result, nil, nil)).to be true
      end
      new_variables = workflow_maker.extract_results(scenario, package_of_measures)
      expect(hash_diff(variables, new_variables)).to be true
    end
  end

  # function to compare two hashes iterating over the key and comparing the values
  def hash_diff(left_hash, right_hash)
    different = false
    (left_hash.keys + right_hash.keys).uniq.inject({}) do |memo, key|
      left = left_hash[key]
      right = right_hash[key]

      next memo if left.to_i == right.to_i

      # we get here when we find a difference
      puts "The two hashes are different for key: #{key}: left: #{left} right: #{right}"
      different = true
    end
    return !different
  end
end
