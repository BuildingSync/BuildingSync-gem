require_relative './../spec_helper'

test_configs = [
  # file_name, standard, epw_path, schema_version
  ['building_151.xml', ASHRAE90_1, nil, 'v2.4.0'],
  # ['building_151.xml', CA_TIT LE24, nil, 'v2.4.0'],
  # ['example-smalloffice-level1.xml', ASHRAE90_1, nil, 'v2.4.0'],
  # ['Reference-PrimarySchool-L100-Audit.xml', ASHRAE90_1, nil, 'v2.4.0'],
  # ['Golden Test File.xml', ASHRAE90_1, nil, 'v2.4.0'],
  # ['ASHRAE 211 Export.xml', ASHRAE90_1, nil, 'v2.4.0'],
  # ['AT_example_AS_conversion_audit_report.xml', ASHRAE90_1, nil, 'v2.4.0'],
  # ['AT_example_AS_conversion_audit_report.xml', CA_TITLE24, nil, 'v2.4.0'],
  # ['AT_example_NYC_audit_report_property.xml', ASHRAE90_1, nil, 'v2.4.0'],
  # ['AT_example_SF_audit_report.xml', ASHRAE90_1, nil, 'v2.4.0'],
  # ['AT_example_SF_audit_report.xml', CA_TITLE24, nil, 'v2.4.0'],
  # ['BuildingEQ-1.0.0.xml', ASHRAE90_1, nil, 'v2.4.0'],
  # ['BuildingEQ-1.0.0.xml', CA_TITLE24, nil, 'v2.4.0'],
  # ['CMS Woodlawn Campus.xml', ASHRAE90_1, nil, 'v2.4.0'],
  # ['CMS Woodlawn Campus.xml', CA_TITLE24, nil, 'v2.4.0'],
  # ['LL87.xml', ASHRAE90_1, nil, 'v2.4.0'],
  # ['LL87.xml', CA_TITLE24, nil, 'v2.4.0'],

  # ["/Users/heslinge/Play/bsync_tests/example-smalloffice-level1.xml", ASHRAE90_1, nil, 'v2.4.0'],
  # ["/Users/heslinge/Play/bsync_tests/Reference-PrimarySchool-L100-Audit.xml", ASHRAE90_1, nil, 'v2.4.0'],
  # ["/Users/heslinge/Play/bsync_tests/ASHRAE\ 211\ Export.xml", ASHRAE90_1, nil, 'v2.git stat4.0'],
  # ["/Users/heslinge/Play/bsync_tests/Golden\ Test\ File.xml", ASHRAE90_1, nil, 'v2.4.0'],
  # ["/Users/heslinge/Play/bsync_tests/BuildingEQ-1.0.0.xml", ASHRAE90_1, nil, 'v2.4.0'],
  # ["/Users/heslinge/Play/bsync_tests/L100_Pre-Simulation-1.0.0.xml", ASHRAE90_1, nil, 'v2.4.0'],
  # ["/Users/heslinge/Play/bsync_tests/L100_Audit-1.0.0.xml", ASHRAE90_1, nil, 'v2.4.0'],
  # ["/Users/heslinge/Play/bsync_tests/L100_Audit-1.0.0_and_BSyncr-1.0.0.xml", ASHRAE90_1, nil, 'v2.4.0'],
  # ["/Users/heslinge/Play/bsync_tests/179D_Example_Building.xml", ASHRAE90_1, nil, 'v2.4.0'],
  # ["/Users/heslinge/Play/bsync_tests/Chula_Vista_ASHRAE_L1_Example_Building.xml", ASHRAE90_1, nil, 'v2.4.0'],
  # ["/Users/heslinge/Play/bsync_tests/Chula_Vista_ASHRAE_L2_Example_Building.xml", ASHRAE90_1, nil, 'v2.4.0'],
  # ["/Users/heslinge/Play/bsync_tests/Demo_ASHRAE_L2_Example_Building.xml", ASHRAE90_1, nil, 'v2.4.0'],
  # ["/Users/heslinge/Play/bsync_tests/Example_ASHRAE_L2_Report.xml", ASHRAE90_1, nil, 'v2.4.0'],
  # ["/Users/heslinge/Play/bsync_tests/Example_ASHRAE_L2_Report_-_with_Energy_Use_Data.xml", ASHRAE90_1, nil, 'v2.4.0'],
  # ["/Users/heslinge/Play/bsync_tests/Example_ASHRAE_L2_Report_-_with_Energy_Use_Data_2.xml", ASHRAE90_1, nil, 'v2.4.0'],
  # ["/Users/heslinge/Play/bsync_tests/Example_HOMES_Template_Building.xml", ASHRAE90_1, nil, 'v2.4.0'],
  # ["/Users/heslinge/Play/bsync_tests/Example_NYC_Energy_Efficiency_Report_Property.xml", ASHRAE90_1, nil, 'v2.4.0'],
  # ["/Users/heslinge/Play/bsync_tests/Example_NYC_Energy_Efficiency_Report_Property_2.xml", ASHRAE90_1, nil, 'v2.4.0'],
  # ["/Users/heslinge/Play/bsync_tests/Example_San_Francisco_Audit_Report.xml", ASHRAE90_1, nil, 'v2.4.0'],
  # ["/Users/heslinge/Play/bsync_tests/NYC_BBL_AT_Demo_Property.xml", ASHRAE90_1, nil, 'v2.4.0'],
  # ["/Users/heslinge/Play/bsync_tests/BETTER-1.0.0_SampleOffice_gemtest.xml", ASHRAE90_1, nil, 'v2.4.0'],
  # ["/Users/heslinge/Play/bsync_tests/BuildingEQ-1.0.0_gemtest.xml", ASHRAE90_1, nil, 'v2.4.0'],
]

RSpec.describe 'BuildingSync' do
  describe 'Translator should' do
    test_configs.each do |test_config|
      (file_name, standard, epw_path, schema_version) = test_config

      it "write and run baseline owm. File: #{file_name}, Standard: #{standard}, EPW_Path: #{epw_path}, File Schema Version: #{schema_version}" do
        # Set Up
        xml_path, output_path = create_xml_path_and_output_path(file_name, standard, __FILE__, schema_version)
        translator = BuildingSync::Translator.new(xml_path, output_path, epw_path, standard)

        # Action
        translator.write_baseline_osw
        translator.run_baseline_osw

        # Assertion
        expect(File.exist?(output_path + "/baseline")).to be true
        expect(File.exist?(output_path + "/baseline/out.osw")).to be true
        out_osw = File.read(output_path + "/baseline/out.osw")
        out_osw = JSON.parse(out_osw, symbolize_names: true)
        expect(out_osw[:completed_status]).to eq "Success"
      end

      xit "write and run measure owms. File: #{file_name}, Standard: #{standard}, EPW_Path: #{epw_path}, File Schema Version: #{schema_version}" do
        # Set Up
        xml_path, output_path = create_xml_path_and_output_path(file_name, standard, __FILE__, schema_version)
        output_path = "test smalloffice"
        translator = BuildingSync::Translator.new(file_name, output_path, epw_path, standard)

        # Action
        translator.write_baseline_osw
        translator.run_baseline_osw
        translator.write_report_osws
        translator.run_report_osws

        # Assertion
        measures = [
          "Add daylight controls Only",
          "Add occupancy sensors Only",
          "Add or repair economizer Only",
          "Air_Seal_Infiltration_30%_More_Airtight Only",
          "Cooling_System_SEER 14 Only",
          "Heating_System_Efficiency_0.93 Only",
          "Increase ceiling insulation Only",
          "Increase roof insulation Only",
          "Increase wall insulation Only",
          "Install demand control ventilation Only",
          "Install plug load controls Only",
          "Insulate thermal bypasses Only",
          "LED Only",
          "Replace boiler Only",
          "Replace ice-refrigeration equipment with high efficiency units Only",
          "Upgrade operating protocols calibration and-or sequencing Only",
        ]
        measures.each do | measure |
          expect(File.exist?(output_path + "/" + measure)).to be true
          expect(File.exist?(output_path + "/" + measure + "/out.osw")).to be true
          out_osw = File.read(output_path + "/" + measure + "/out.osw")
          out_osw = JSON.parse(out_osw, symbolize_names: true)
          expect(out_osw[:completed_status]).to eq "Success"
        end
      end
    end
  end
end
