# BuildingSync

Repository to store helpers for reading and writing BuildingSync as well as measures for converting a BuildingSync XML to OpenStudio models.

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

To be filled out later. 

## TODO

- [ ] Add initial BuildingSync class (can use [BRICR](https://github.com/NREL/bricr/blob/develop/lib/bricr/building_sync.rb) class as example). Use REXML for reading and writing BSync.
- [ ] Add ForwardTranslator class (following [other OpenStudio conventions](https://github.com/NREL/OpenStudio/blob/develop/openstudiocore/src/gbxml/ForwardTranslator.hpp)) that translates BuildingSync to OpenStudio (using pure Ruby)
- [ ] Move BuildingSync specific measures into this gem. See list from [here](https://docs.google.com/spreadsheets/d/1PCB4nZoLQ1cWhnlrlnHwo9kI4G8ChOeblU3L4uZu7bc/edit#gid=1482405742) 
- [ ] Add example on how to use some code from ```openstudio-standards``` or ```openstudio-model-articulation``` during the translation
- [ ] Add unit test for BuildingSync -> OSM translation
- [ ] Add ability to perform validation using https://selectiontool.buildingsync.net. Return which use cases existing BuildingSync XML is valid for.


# Releasing

* Update change log
* Update version in `/lib/buildingsync/version.rb`
* Merge down to master
* Release via github
* run `rake release` from master