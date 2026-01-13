# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************
require 'buildingsync/report'

RSpec.describe 'Report Spec' do
  describe 'Methods' do
    before(:all) do
      # -- Setup
      file_name = 'building_151_level1.xml'
      std = ASHRAE90_1
      xml_path, output_path = create_xml_path_and_output_path(file_name, std, __FILE__, 'v2.4.0')

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
      benchmark = @report.scenarios.find(&:benchmark?)
      cb_modeled = @report.scenarios.find(&:cb_modeled?)

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
