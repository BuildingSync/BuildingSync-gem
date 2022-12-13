# BuildingSync Gem

## Description

This measure-gem converts a BuildingSync XML file into a series of OSWs. Each OSW corresponds to an energy efficiency package of measures defined in the BuildingSync XML file. The OSWs can then be simulated and the results are written back into the BuildingSync XML file.

## Modeler Description

The measure will use a BuildingSync XML file as an input. The XML can be created using tools such as [bsyncpy](https://pypi.org/project/bsync/).
The XML will be parsed and a new OpenStudio model will be created. A new OSW will be created for each energy efficiency package of measures defined in the XML, using the measures defined in the ./lib/buildingsync/makers/phase_zero_base.osw file.
The user has a choice for just generating OSWs or generating and simulating them. If the OSWs are simulated, then the results are collected and reports are generated. These reports will be written in the original BuildingSync XML file, and that XML file will be saved.

## Measure Type
ModelMeasure

## Taxonomy


## Arguments

### BSync XML path
The path to the XML file that should be translated.
**Name:** building_sync_xml_file_path,
**Type:** String,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### BSync output path:
The output directory where all workflows and results will be written.
**Name:** out_path,
**Type:** String,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Simulate and record results?
The generated OSWs will be simulated and the results recorded into the original XML file.
**Name:** simulate_flag,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false



