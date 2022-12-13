# insert your copyright here

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
require 'buildingsync/translator'

class BuildingSyncToOpenStudio < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'Building Sync to OpenStudio'
  end

  # human readable description
  def description
    return "This measure-gem converts a BuildingSync XML file into a series of OSWs. Each OSW corresponds to an energy efficiency package of measures defined in the BuildingSync XML file. The OSWs can then be simulated and the results are written back into the BuildingSync XML file."
  end

  # human readable description of modeling approach
  def modeler_description
    return "The measure will use a BuildingSync XML file as an input. The XML can be created using tools such as [bsyncpy](https://pypi.org/project/bsync/).
    The XML will be parsed and a new OpenStudio model will be created. A new OSW will be created for each energy efficiency package of measures defined in the XML, using the measures defined in the ./lib/buildingsync/makers/phase_zero_base.osw file.
    The user has a choice for just generating OSWs or generating and simulating them. If the OSWs are simulated, then the results are collected and reports are generated. These reports will be written in the original BuildingSync XML file, and that XML file will be saved."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    building_sync_xml_file_path = OpenStudio::Measure::OSArgument.makeStringArgument('building_sync_xml_file_path', true)
    building_sync_xml_file_path.setDisplayName('BSync XML path')
    building_sync_xml_file_path.setDescription('The path to the XML file that should be translated.')
    args << building_sync_xml_file_path

    out_path = OpenStudio::Measure::OSArgument.makeStringArgument('out_path', true)
    out_path.setDisplayName('BSync output path')
    out_path.setDescription('The output directory where all workflows and results will be written.')
    args << out_path

    simulate_flag = OpenStudio::Measure::OSArgument.makeBoolArgument('simulate_flag', true)
    simulate_flag.setDisplayName('Simulate and record results?')
    simulate_flag.setDescription('The generated OSWs will be simulated and the results recorded into the original XML file.')
    simulate_flag.setDefaultValue(true)
    args << simulate_flag
    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    building_sync_xml_file_path = runner.getStringArgumentValue('building_sync_xml_file_path', user_arguments)
    out_path = runner.getStringArgumentValue('out_path', user_arguments)
    simulate_flag = runner.getStringArgumentValue('simulate_flag', user_arguments)


    # check the space_name for reasonableness
    if building_sync_xml_file_path.empty?
      runner.registerError('Empty space name was entered.')
      return false
    end

    # report initial condition of model
    runner.registerInitialCondition("The building started with #{model.getSpaces.size} spaces.")

    # add a new space to the model
    translator = BuildingSync::Translator.new(building_sync_xml_file_path, out_path)
    translator.setup_and_sizing_run
    # fetch the model from the output directory
    ostranslator = OpenStudio::OSVersion::VersionTranslator.new
    path = "#{out_path}/in.osm"
    model = ostranslator.loadModel(path)#translator.output_dir)
    model = model.get
    runner.registerFinalCondition("The building finished with #{model.getSpaces.size} spaces.")


    # generating the OpenStudio workflows and writing the osw files
    # auc:Scenario elements with measures are turned into new simulation dirs
    # path/to/output_dir/scenario_name
    translator.write_osws
    if simulate_flag
      # run all simulations
      translator.run_osws

      # gather the results for all scenarios found in out_path,
      # such as annual and monthly data for different energy
      # sources (electricity, natural gas, etc.)
      translator.gather_results

      # Add in UserDefinedFields, which contain information about the
      # OpenStudio model run 
      translator.prepare_final_xml

      # write results to xml
      # default file name is 'results.xml' 
      file_name = 'results.xml' 
      translator.save_xml(file_name)

      # report final condition of model
      runner.registerFinalCondition("File has been saved as #{file_name}")
    end

    return true
  end
end

# register the measure to be used by the application
BuildingSyncToOpenStudio.new.registerWithApplication
