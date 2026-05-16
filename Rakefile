# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

require 'rubocop/rake_task'
RuboCop::RakeTask.new

# Load in the rake tasks from the base extension gem
require 'openstudio/extension/rake_task'
require 'openstudio/model_articulation'
require_relative './lib/buildingsync/constants'
require_relative './lib/buildingsync/external_measure_repo_manager'
rake_task = OpenStudio::Extension::RakeTask.new
rake_task.set_extension_class(OpenStudio::ModelArticulation::Extension)

desc 'Convert tabs to spaces'
task :remove_tabs do
  Dir['examples/**/*.xml', 'BuildingSync.xsd'].each do |file|
    puts " Cleaning #{file}"
    doc = Nokogiri.XML(File.read(file)) do |config|
      config.default_xml.noblanks
    end

    doc.xpath('//comment()').each do |node|
      if node.text.match?(/XMLSpy/)
        node.remove
      end
    end

    File.open(file, 'w') { |f| f << doc.to_xml(indent: 2) }
  end

  if File.exist? 'BuildingSync.json'
    f = JSON.parse(File.read('BuildingSync.json'))
    File.open('BuildingSync.json', 'w') do |file|
      file << JSON.pretty_generate(f)
    end
  end
end

desc 'Run measure test'
task :measure_test do
  puts Dir.getwd
  require_relative './lib/measures/building_sync_to_openstudio/tests/building_sync_to_openstudio_test'

end

namespace :measures do
  desc 'Clone/fetch external non-gem measure repositories declared in config/external_measure_repos.yml'
  task :install_external do
    manager = BuildingSync::ExternalMeasureRepoManager.new

    if !manager.manifest_exists?
      puts "No external measure manifest found at #{EXTERNAL_MEASURE_REPOS_MANIFEST_PATH}"
      next
    end

    dirs = manager.install_all
    puts "Installed external measure roots (#{dirs.length}):"
    dirs.each { |dir| puts "  - #{dir}" }
  end

  desc 'List resolved external non-gem measure directories'
  task :list_external do
    manager = BuildingSync::ExternalMeasureRepoManager.new
    dirs = manager.resolved_measure_directories

    puts "External measure roots (#{dirs.length}):"
    dirs.each { |dir| puts "  - #{dir}" }
  end
end

task default: :spec
