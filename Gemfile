source 'http://rubygems.org'

# Specify your gem's dependencies in buildingsync.gemspec
gemspec

if File.exist?('../OpenStudio-extension-gem')
  # gem 'openstudio-extension', github: 'NREL/OpenStudio-extension-gem', branch: 'develop'
  gem 'openstudio-extension', path: '../OpenStudio-extension-gem'
else
  gem 'openstudio-extension', github: 'NREL/OpenStudio-extension-gem', branch: 'DA'
end

if File.exist?('../openstudio-model-articulation-gem')
  # gem 'openstudio-model-articulation', github: 'NREL/openstudio-model-articulation-gem', branch: 'develop'
  gem 'openstudio-model-articulation', path: '../openstudio-model-articulation-gem'
else
  gem 'openstudio-model-articulation', github: 'NREL/openstudio-model-articulation-gem', branch: 'DA'
end

if File.exist?('../openstudio-common-measures-gem')
  # gem 'openstudio-model-articulation', github: 'NREL/openstudio-common-measures-gem', branch: 'develop'
  gem 'openstudio-common-measures', path: '../openstudio-common-measures-gem'
else
  gem 'openstudio-common-measures', github: 'NREL/openstudio-common-measures-gem', branch: 'develop'
end

# OpenStudio Measure Tester includes the dependencies for running unit tests, coverage, and rubocop
gem 'openstudio_measure_tester', '0.1.7'

# simplecov has an unneccesary dependency on native json gem, use fork that does not require this
gem 'simplecov', github: 'NREL/simplecov'
