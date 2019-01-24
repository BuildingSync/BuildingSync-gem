source "http://rubygems.org"

# Specify your gem's dependencies in buildingsync.gemspec
gemspec

# gem 'openstudio-extension', github: 'NREL/OpenStudio-extension-gem', branch: 'develop'
gem 'openstudio-extension', path: '../OpenStudio-extension-gem'

gem 'openstudio_measure_tester', '= 0.1.7' # This includes the dependencies for running unit tests, coverage, and rubocop
#gem 'openstudio_measure_tester', :github => 'NREL/OpenStudio-measure-tester-gem', :ref => '273d1f1a5c739312688ea605ef4a5b6e7325332c'

# simplecov has an unneccesary dependency on native json gem, use fork that does not require this
gem 'simplecov', github: 'NREL/simplecov'