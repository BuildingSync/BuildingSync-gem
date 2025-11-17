test_configs = [
  # file_name, standard, epw_path, schema_version
  # ['building_151.xml', ASHRAE90_1, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.4.0'],
  # ['example-smalloffice-level1.xml', ASHRAE90_1, File.join(SPEC_WEATHER_DIR, 'USA_IL_Chicago-OHare.Intl.AP.725300_TMY3.epw'), 'v2.4.0'],
  ['example-smalloffice-level1.xml', ASHRAE90_1, nil, 'v2.4.0'],
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
        translator = BuildingSync::Translator.new(xml_path, output_path, epw_path, standard)

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
