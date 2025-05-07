require_relative './../spec_helper'

test_configs = [
  # file_name, standard, epw_path, schema_version
  ['building_151.xml', CA_TITLE24, nil, 'v2.4.0'],
]

RSpec.describe 'BuildingSync' do
  describe 'Translator should write baseline osw' do
    test_configs.each do |test_config|
      (file_name, standard, epw_path, schema_version) = test_config

      # Should write to osws
      it "File: #{file_name}. Standard: #{standard}. EPW_Path: #{epw_path}. File Schema Version: #{schema_version}" do
        # Set up
        xml_path, output_path = create_xml_path_and_output_path(file_name, standard, __FILE__, schema_version)
        output_path = "hannahs_test_results"
        translator = BuildingSync::Translator.new(xml_path, output_path, epw_path, standard)
        # translator.setup_and_sizing_run ->
          # work_flow_maker.setup_and_sizing_run ->
            # @facility.generate_baseline_osm ->
              # @site.generate_baseline_osm ->
                # determine_climate_zone(standard_to_be_used)
                #  @building.set_weather_and_climate_zone
                # @building.generate_baseline_osm (creates_bar)
              # create_building_systems ->
            # @facility.write_osm ->
              # @site.write_osm ->
                # @building.write_osm ->
                  # model.save
        # translator.setup_and_sizing_run


        # translator.write_baseline_osw ->
          # work_flow_maker.write_baseline_osw ->
        translator.write_baseline_osw

        # Action
        # Translator::write_osws ->
          # WorkflowMaker::write_osws ->
            # @facility.report.poms.each do |scenario|
              # WorkflowMaker::write_osw ->
                # configure_workflow_for_scenario(base_workflow, scenario) ->
                  # scenario.get_measure_ids.each do |measure_id|
                    # sym_to_find = measure.xget_text('SystemCategoryAffected')
                    # @workflow_maker_json[sym_to_find].each do |category|
                      # category[m_name][:arguments].each do |argument|
                        # set_argument_detail(base_workflow, argument, measure_dir_name, m_name.to_s)



                # scenario.set_workflow(base_workflow) # literally just sets @workflow
                # scenario.write_osw # writes @workflow to file
        # translator.write_osws

        # Assertion
      end
    end
  end
end
