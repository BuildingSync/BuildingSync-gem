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
    return "This measure takes a BuildingSync XML as an input and translates it to an OpenStudio Model. This measure requires non-standard Ruby Gems that do are not included by default in OpenStudio's Ruby interpreter. To run this measure with the OpenStudio CLI using an OSW, you need to pass in additional gems to the CLI at run time."
  end

  # human readable description of modeling approach
  def modeler_description
    return "BuildingSync to OSM translation used to happen outside of the measure structure, as a result it couldn't easily be used in tools that support running OSW's through the OpenStudio CLI. When upgrading to support OpenStudio 3.4, this code was wrapped into a measure. Additionally, where libraries exist in the OpenStudio Extension Gem and OOpenStudio Standars Gem, those should be used vs. custom code within BuildingSync. This will provide consistency with other workflows and minimize upgrade maintenance. This measure doesn't work with an off the shelf OpenStudio install because it requires additional gems. As a result it isn't currently on the Building Component Library (BCL). It's also possible that at some point this measure may need to run other OpenStudio measures. If that happens it does result in extra planning on setting up a project to assure that the necessary measures are available, possibly through bundle and gem files for projects using this."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new
    # the name of the space to add to the model
    building_sync_xml_file_path = OpenStudio::Measure::OSArgument.makeStringArgument('building_sync_xml_file_path', true)
    building_sync_xml_file_path.setDisplayName('BSync XML path')
    building_sync_xml_file_path.setDescription('The path to the XML file that should be translated.')
    args << building_sync_xml_file_path

    out_path = OpenStudio::Measure::OSArgument.makeStringArgument('out_path', true)
    out_path.setDisplayName('BSync output path')
    out_path.setDescription('The output directory where all workflows and results will be written.')
    args << out_path
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
    model = ostranslator.loadModel(path)
    model = model.get
    runner.registerFinalCondition("The building finished with #{model.getSpaces.size} spaces.")


    # generating the OpenStudio workflows and writing the osw files
    # auc:Scenario elements with measures are turned into new simulation dirs
    # path/to/output_dir/scenario_name
    #translator.write_osws

    # run all simulations
    #translator.run_osws

    # gather the results for all scenarios found in out_path,
    # such as annual and monthly data for different energy
    # sources (electricity, natural gas, etc.)
    #translator.gather_results("#{File.dirname(__FILE__)}/tests/output")

    # Add in UserDefinedFields, which contain information about the
    # OpenStudio model run 
    #translator.prepare_final_xml

    # write results to xml
    # default file name is 'results.xml' 
    #file_name = 'abc-123.xml' 
    #translator.save_xml(file_name)

    # report final condition of model
    #runner.registerFinalCondition("File has been saved as #{file_name}")

    return true
  end
end

# register the measure to be used by the application
BuildingSyncToOpenStudio.new.registerWithApplication
