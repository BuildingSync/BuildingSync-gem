# BuildingSync

![BuildingSync-gem](https://github.com/BuildingSync/BuildingSync-gem/actions/workflows/continuous_integration.yml/badge.svg?branch=develop)

The BuildingSync-Gem is a repository of helpers for reading and writing BuildingSync XML files, and for using that data 
to drive energy simulations of the subject building. See full documentation [here](https://buildingsync-gem.buildingsync.net).

All of the following are supported: 

  * convert BuildingSync XML file into: 
      * an OpenStudio Baseline model 
      * an OpenStudio workflow for each scenario defined in the XML file 
  * enable simulation of the baseline model and all workflows and 
  * insert simulation results back into the Building XML file. 

## Installation

The BuildingSync Gem requires installation of OpenStudio, specifically [OpenStudio v3.4.0](https://openstudio-builds.s3.amazonaws.com/index.html?prefix=3.4.0/).
The newer versions of OpenStudio have minor breaking changes that have not been addressed in this repository yet. After OpenStudio is 
installed, then export the path of the folder that contains the openstudio.rb file to RUBYLIB environment variable
(e.g., `export RUBYLIB=/Applications/OpenStudio-3.4.0/Ruby`)

After installing OpenStudio and setting the environment variable, then add this line to your application's Gemfile:
```ruby
gem 'buildingsync', '0.2.1'
```

And then execute:
```bash
bundle install
```

Or install it yourself as:
```bash
gem install 'buildingsync'
```

## Usage

All of the features described above are provided by the translator class, as shown in the following sample code. There
are also BuildingSync Gem example files in [this repository](https://github.com/BuildingSync/BuildingSync-gem-examples).

```ruby
require 'buildingsync/translator'

building_sync_xml_file_path = 'path/to/bsync.xml'
out_path = 'path/to/output_dir'

# initializing the translator 
translator = BuildingSync::Translator.new(building_sync_xml_file_path, out_path)

# generating the OpenStudio Model and writing the osm file.
# path/to/output_dir/SR and path/to/output_dir/in.osm created
translator.setup_and_sizing_run

# generating the OpenStudio workflows and writing the osw files
# auc:Scenario elements with measures are turned into new simulation dirs
# path/to/output_dir/scenario_name
translator.write_osws

# run all simulations
translator.run_osws

# gather the results for all scenarios found in out_path,
# such as annual and monthly data for different energy
# sources (electricity, natural gas, etc.)
translator.gather_results(out_path)

# Add in UserDefinedFields, which contain information about the
# OpenStudio model run 
translator.prepare_final_xml

# write results to xml
# default file name is 'results.xml' 
file_name = 'abc-123.xml' 
translator.save_xml(file_name)
```

## Testing

Check out the repository and then execute:

```bash
bundle install
bundle exec rake
```
    
## Documentation

The documentation of the BuildingSync-Gem is done with Yard (https://yardoc.org)
To generate the documentation locally do the following:

```bash
gem install yard
SITEMAP_BASEURL=https://buildingsync-gem.buildingsync.net bundle exec yard doc --plugin sitemap
```

Documentation for the develop branch is automatically released when code is merged into the branch.

# Releasing

1. Update CHANGELOG.md
1. Run `bundle exec rake rubocop:auto_correct`
1. Update version in `lib/buildingsync/version.rb`
1. Create PR to main, after tests and reviews complete, then merge
1. Locally - from the main branch, run `bundle exec rake release`
1. On GitHub, go to the releases page and update the latest release tag. Name it “Version x.y.z” and copy the CHANGELOG entry into the description box.

# TODO

* [ ] Support BuildingSync 2.3.0
* [ ] Update to OpenStudio version 3.2.0
