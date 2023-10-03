# frozen_string_literal: true

source 'http://rubygems.org'

gemspec

# Local gems are useful when developing and integrating the various dependencies.
# To favor the use of local gems, set the following environment variable:
#   Mac: export FAVOR_LOCAL_GEMS=1
#   Windows: set FAVOR_LOCAL_GEMS=1
# Note that if allow_local is true, but the gem is not found locally, then it will
# checkout the latest version (develop) from github.
allow_local = ENV['FAVOR_LOCAL_GEMS']

if allow_local && File.exist?('../openstudio-common-measures-gem')
  gem 'openstudio-common-measures', path: '../openstudio-common-measures-gem'
else
  gem 'openstudio-common-measures', github: 'NREL/openstudio-common-measures-gem', tag: 'v0.6.1'
end

if allow_local && File.exist?('../openstudio-model-articulation-gem')
  gem 'openstudio-model-articulation', path: '../openstudio-model-articulation-gem'
else
  gem 'openstudio-model-articulation', github: 'NREL/openstudio-model-articulation-gem', tag: 'v0.6.1'
end

if allow_local && File.exist?('../openstudio-ee-gem')
  gem 'openstudio-ee', path: '../openstudio-ee-gem'
else
  gem 'openstudio-ee', github: 'NREL/openstudio-ee-gem', tag: 'v0.6.0'
end

gem 'parser', '3.2.2.2'