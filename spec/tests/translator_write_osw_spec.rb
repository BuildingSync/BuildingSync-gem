# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************

test_configs = [
  # file_name, standard, epw_path, schema_version
  # ['179D_Example_Building.xml', ASHRAE90_1, nil, 'v2.4.0'],  # FAILS: weather file????????
  # # ['ASHRAE 211 Export.xml', ASHRAE90_1, nil, 'v2.4.0'],  # FAILS:  Building has building type Agricultural estate which is not handled by the gem.
  # ['BETTER-1.0.0_SampleOffice_gemtest.xml', ASHRAE90_1, nil, 'v2.4.0'],
  # ['building_151.xml', ASHRAE90_1, nil, 'v2.4.0'],
  # ['BuildingEQ-1.0.0_gemtest.xml', ASHRAE90_1, nil, 'v2.4.0'],
  # ['BuildingEQ-1.0.0.xml', ASHRAE90_1, nil, 'v2.4.0'],
  # ['Chula_Vista_ASHRAE_L1_Example_Building.xml', ASHRAE90_1, nil, 'v2.4.0'],
  # ['Demo_ASHRAE_L2_Example_Building.xml', ASHRAE90_1, nil, 'v2.4.0'],
  # ['Example_ASHRAE_L2_Report_-_with_Energy_Use_Data_2.xml', ASHRAE90_1, nil, 'v2.4.0'],
  # ['Example_ASHRAE_L2_Report_-_with_Energy_Use_Data.xml', ASHRAE90_1, nil, 'v2.4.0'],
  # ['Example_ASHRAE_L2_Report.xml', ASHRAE90_1, nil, 'v2.4.0'],
  # ['Example_HOMES_Template_Building.xml', ASHRAE90_1, nil, 'v2.4.0'],
  # ['Example_NYC_Energy_Efficiency_Report_Property_2.xml', ASHRAE90_1, nil, 'v2.4.0'],
  # ['Example_NYC_Energy_Efficiency_Report_Property.xml', ASHRAE90_1, nil, 'v2.4.0'],
  # ['Example_San_Francisco_Audit_Report.xml', ASHRAE90_1, nil, 'v2.4.0'],
  # ['example-smalloffice-level1.xml', ASHRAE90_1, nil, 'v2.4.0'],
  # ['Golden Test File.xml', ASHRAE90_1, nil, 'v2.4.0'],
  # ['L100_Audit-1.0.0_and_BSyncr-1.0.0.xml', ASHRAE90_1, nil, 'v2.4.0'],
  # ['L100_Audit-1.0.0.xml', ASHRAE90_1, nil, 'v2.4.0'],
  # ['L100_Pre-Simulation-1.0.0.xml', ASHRAE90_1, nil, 'v2.4.0'],
  # ['NYC_BBL_AT_Demo_Property.xml', ASHRAE90_1, nil, 'v2.4.0'],
  ['Reference-PrimarySchool-L100-Audit.xml', ASHRAE90_1, nil, 'v2.4.0'],
  ['example-smalloffice-level2.xml', ASHRAE90_1, nil, 'v2.4.0'],
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

      xit "write and run measure osws. File: #{file_name}, Standard: #{standard}, EPW_Path: #{epw_path}, File Schema Version: #{schema_version}" do
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

  describe 'External measure manifest integration' do
    before(:each) do
      @comstock_repo_root = File.join(EXTERNAL_MEASURE_REPOS_INSTALL_DIR, 'comstock')
      @expected_external_roots = [
        File.join(@comstock_repo_root, 'measures'),
        File.join(@comstock_repo_root, 'resources', 'measures')
      ]

      @created_roots = []
      @expected_external_roots.each do |root|
        next if Dir.exist?(root)

        FileUtils.mkdir_p(root)
        @created_roots << root
      end
    end

    after(:each) do
      @created_roots.each do |root|
        FileUtils.rm_rf(root) if Dir.exist?(root)
      end

      if Dir.exist?(@comstock_repo_root)
        # Remove empty parent folders created by this test.
        resources_dir = File.join(@comstock_repo_root, 'resources')
        Dir.rmdir(resources_dir) if Dir.exist?(resources_dir) && Dir.empty?(resources_dir)
        Dir.rmdir(@comstock_repo_root) if Dir.empty?(@comstock_repo_root)
      end
    end

    it 'writes baseline in.osw with expected ordered measure_paths from local, gems, and external manifest repos' do
      file_name = 'Reference-PrimarySchool-L100-Audit.xml'
      standard = ASHRAE90_1
      epw_path = nil
      schema_version = 'v2.4.0'

      xml_path, output_path = create_xml_path_and_output_path(file_name, standard, __FILE__, schema_version)
      translator = BuildingSync::Translator.new(xml_path, output_path, epw_path, standard)

      translator.write_baseline_osw
      translator.run_baseline_osw

      in_osw_path = File.join(output_path, 'baseline', 'in.osw')
      expect(File.exist?(in_osw_path)).to be true

      osw = JSON.parse(File.read(in_osw_path))
      measure_paths = osw['measure_paths']

      puts 'Generated measure_paths from baseline/in.osw:'
      measure_paths.each_with_index do |path, idx|
        puts "  #{idx}: #{path}"
      end

      expect(measure_paths).to be_an(Array)
      expect(measure_paths.first).to eq(LOCAL_MEASURES_DIR)
      @expected_external_roots.each do |external_root|
        expect(measure_paths).to include(external_root)
      end

      gem_paths = [
        OpenStudio::CommonMeasures::Extension.new.measures_dir,
        OpenStudio::ModelArticulation::Extension.new.measures_dir,
        BuildingSync::Extension.new.measures_dir,
        OpenStudio::EeMeasures::Extension.new.measures_dir
      ].uniq

      gem_paths.each do |gem_path|
        expect(measure_paths).to include(gem_path)
      end

      last_gem_index = gem_paths.map { |gem_path| measure_paths.index(gem_path) }.compact.max
      @expected_external_roots.each do |external_root|
        external_index = measure_paths.index(external_root)
        expect(external_index).to be > last_gem_index
      end
    end
  end
end
