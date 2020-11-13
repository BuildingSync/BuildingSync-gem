# BuildingSync

The BuildingSync-Gem is a repository of helpers for reading and writing BuildingSync XML files, and for using that data to drive energy simulations of the subject building. 

All of the following are supported: 

* convert BuildingSync XML file into: 

    * an OpenStudio Baseline model 

    * an OpenStudio workflow for each scenario defined in the XML file 

* enables simulation of the baseline model and all workflows and 

* insert simulation results back into the Building XML file. 
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

All of the features described above are provided by the translator class, as shown in the following sample code: 

```ruby
building_sync_xml_file_path = 'path/to/bsync.xml'
out_path = 'path/to/output_dir'

# initializing the translator 
translator = BuildingSync::Translator.new(building_sync_xml_file_path, out_path)

# generating the OpenStudio Model and writing the osm file.
# path/to/output_dir/SR and path/to/output_dir/in.osm created
translator.write_osm

# generating the OpenStudio workflows and writing the osw files
# auc:Scenario elements with measures are turned into new simulation dirs
# path/to/output_dir/scenario_name
translator.write_osws

# running the baseline simulation
# path/to/output_dir/Baseline/in.osm 
translator.run_baseline_osm

# run all simulations
translator.run_osws

# gather the results for all scenarios found in out_path
translator.gather_results(out_path)

# write results to xml
save_file = File.join(out_path, 'results.xml')
translator.save_xml(save_file)
```
## Testing

Check out the repository and then execute:

    $ bundle install
 
    $ bundle exec rake
    
## Documentation

The documentation of the BuildingSync-Gem is done with Yard (https://yardoc.org)
To generate the documentation do the following:

     $ gem install yard
     
     $ yardoc - README.md 
    
# Releasing

* Update change log
* Update version in `/lib/buildingsync/version.rb`
* Merge down to master
* Release via github
* run `rake release` from master
