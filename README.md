# BuildingSync

Repository to store helpers for reading and writing BuildingSync, to generate a baseline OpenStudio Model, and to manage workflows with measures for generating different scenario models.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'buildingsync'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install 'buildingsync'

## Usage

The BuildingSync-Gem 

* converts your BuildingSync.xml file into 
    * an OpenStudio Baseline model
    * an OpenStudio workflow for each scenario defined in the XML file
* enables simulation of the baseline model and all workflows and 
* inserts simulation results back into the xml file. 

All these features are driven by the translator class.

```ruby
# initializing the translator 
translator = BuildingSync::Translator.new(building_sync_xml_file_path, out_path)
# generating the OpenStudio Model and writing the osm file  
translator.write_osm
# generating the OpenStudio workflows and writing the osw files
translator.write_osws
# running the baseline simulations
translator.run_osm
# running all simulations
translator.run_osws
# gather the results and save them to an BuildingSync.XML
translator.gather_results(out_path)
```
## Testing

Check out the repository and then execute:

    $ bundle install

    $ bundle update   
 
    $ bundle exec rake
    

## TODO

- [ ] Move BuildingSync specific measures into this gem. See list from [here](https://docs.google.com/spreadsheets/d/1PCB4nZoLQ1cWhnlrlnHwo9kI4G8ChOeblU3L4uZu7bc/edit#gid=1482405742) 
- [ ] Add ability to perform validation using https://selectiontool.buildingsync.net. Return which use cases existing BuildingSync XML is valid for.


# Releasing

* Update change log
* Update version in `/lib/buildingsync/version.rb`
* Merge down to master
* Release via github
* run `rake release` from master