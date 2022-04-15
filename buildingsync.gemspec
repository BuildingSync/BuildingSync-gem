# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'buildingsync/version'

Gem::Specification.new do |spec|
  spec.name          = 'buildingsync'
  spec.version       = BuildingSync::VERSION
  spec.authors       = ['Nicholas Long', 'Cory Mosiman', 'Dan Macumber', 'Katherine Fleming']
  spec.email         = ['nicholas.long@nrel.gov', 'cory.mosiman@nrel.gov', 'daniel.macumber@nrel.gov', 'katherine.fleming@nrel.gov']

  spec.summary       = 'BuildingSync library for reading, writing, and exporting BuildingSync to OpenStudio'
  spec.description   = 'BuildingSync library for reading, writing, and exporting BuildingSync to OpenStudio'
  spec.homepage      = 'https://buildingsync.net'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '~> 2.7.0'

  spec.add_dependency 'bundler', '~> 2.1'
  spec.add_dependency 'openstudio-common-measures', '~> 0.5.0'
  spec.add_dependency 'openstudio-ee', '~> 0.5.0'
  spec.add_dependency 'openstudio-extension', '~> 0.5.1'
  spec.add_dependency 'openstudio-model-articulation', '~> 0.5.0'
  spec.add_dependency 'openstudio-standards', '~> 0.2.15'

  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.9'
  spec.add_development_dependency 'yard', '~> 0.9.26'
  spec.add_development_dependency 'yard-sitemap', '~> 1.0.1'
end
