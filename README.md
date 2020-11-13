# BuildingSync

The BuildingSync-Gem is a repository of helpers for reading and writing BuildingSync XML files, and for using that data to drive energy simulations of the subject building. See full documentation on [RubyDoc](https://www.rubydoc.info/github/BuildingSync/BuildingSync-gem).

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
 
    $ bundle exec rake
    
## Documentation

The documentation of the BuildingSync-Gem is done with Yard (https://yardoc.org)
To generate the documentation locally do the following:

     $ gem install yard
     
     $ yardoc - README.md 
     
## Updating published documentation
Publish documentation for each release:

1. Tag release on GitHub
1. Go to [rubydoc.info](https://www.rubydoc.info) and click `Add Project` in the upper right
1. Input the git address: `git://github/BuildingSync/BuildingSync-gem.git`
1. Input the release tag for the desired version, eg: `v0.1.0`
1. Click `Go`
1. Profit
    
# Releasing

* Update change log
* Update version in `/lib/buildingsync/version.rb`
* Merge down to master
* Release via github
* run `rake release` from master
