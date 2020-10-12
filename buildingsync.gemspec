lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'buildingsync/version'

Gem::Specification.new do |spec|
  spec.name          = 'buildingsync'
  spec.version       = BuildingSync::VERSION
  spec.authors       = ['Nicholas Long', 'Dan Macumber', 'Katherine Fleming']
  spec.email         = ['nicholas.long@nrel.gov', 'daniel.macumber@nrel.gov', 'katherine.fleming@nrel.gov']

  spec.summary       = 'BuildingSync library for reading, writing, and exporting BuildingSync to OpenStudio'
  spec.description   = 'BuildingSync library for reading, writing, and exporting BuildingSync to OpenStudio'
  spec.homepage      = 'https://buildingsync.net'

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|lib.measures.*tests|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '~> 2.5.0'

  spec.add_dependency 'bundler', '~> 2.1'
  spec.add_dependency 'openstudio-model-articulation', '~> 0.2.0'
  spec.add_dependency 'openstudio-common-measures', '~> 0.2.0'
  spec.add_dependency 'openstudio-standards', '~> 0.2.11'

  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.9'
end
