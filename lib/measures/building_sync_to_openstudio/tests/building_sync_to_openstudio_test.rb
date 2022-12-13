# insert your copyright here

require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class BuildingSyncToOpenStudioTest < Minitest::Test
  # def setup
  # end

  # def teardown
  # end
  def test_good_argument_values
    # create an instance of the measure
    measure = BuildingSyncToOpenStudio.new

    # create runner with empty OSW
    osw = OpenStudio::WorkflowJSON.new
    runner = OpenStudio::Measure::OSRunner.new(osw)

    #"#{File.dirname(__FILE__)}/spec/files/v2.4.0/building151.xml"
    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = "#{File.dirname(__FILE__)}/example_model.osm"
    model = translator.loadModel(path)
    assert(!model.empty?)
    model = model.get

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {}
    args_hash['building_sync_xml_file_path'] = "#{File.dirname(__FILE__)}/building_151.xml"
    args_hash['out_path'] = "#{File.dirname(__FILE__)}/output"
    # using defaults values from measure.rb for other arguments

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash.key?(arg.name)
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result

    path = "#{args_hash['out_path']}/in.osm"
    model = translator.loadModel(path)
    assert(!model.empty?)
    model = model.get

    # show the output
    show_output(result)

    # assert that it ran correctly
    assert_equal('Success', result.value.valueName)
    #assert(result.info.size == 1)
    assert(result.warnings.empty?)

    # save the model to test output directory
    output_file_path = "#{File.dirname(__FILE__)}//output/test_output.osm"
    model.save(output_file_path, true)
  end
end
