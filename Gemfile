source 'http://rubygems.org'

gemspec

# Local gems are useful when developing and integrating the various dependencies.
# To favor the use of local gems, set the following environment variable:
#   Mac: export FAVOR_LOCAL_GEMS=1
#   Windows: set FAVOR_LOCAL_GEMS=1
# Note that if allow_local is true, but the gem is not found locally, then it will
# checkout the latest version (develop) from github.
allow_local = ENV['FAVOR_LOCAL_GEMS']

# Uncomment the extension and common measures gem if you need to test local development versions. Otherwise
# these are included in the model articulation gem.
#
# if allow_local && File.exist?('../OpenStudio-extension-gem')
#   gem 'openstudio-extension', path: '../OpenStudio-extension-gem'
# elsif allow_local
#   gem 'openstudio-extension', github: 'NREL/OpenStudio-extension-gem', branch: 'develop'
# end

 if allow_local && File.exist?('../openstudio-common-measures-gem')
   gem 'openstudio-common-measures', path: '../openstudio-common-measures-gem'
 else
   gem 'openstudio-common-measures', github: 'NREL/openstudio-common-measures-gem', ref: '32e76c3'
 end

if allow_local && File.exist?('../openstudio-model-articulation-gem')
  gem 'openstudio-model-articulation', path: '../openstudio-model-articulation-gem'
else
  gem 'openstudio-model-articulation', github: 'NREL/openstudio-model-articulation-gem', ref: '5b1d842'
end

if allow_local && File.exist?('../openstudio-ee-gem')
  gem 'openstudio-ee', path: '../openstudio-ee-gem'
else
  gem 'openstudio-ee', github: 'NREL/openstudio-ee-gem', branch: 'bldgsync_measures' #ref: '1529f42'
end
