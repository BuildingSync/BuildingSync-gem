require_relative './../spec_helper'

require 'fileutils'
require 'parallel'

RSpec.describe 'BuildingSync' do
  it 'should have a version' do
    expect(BuildingSync::VERSION).not_to be_nil
  end

  it 'should parse and write building_151.xml (phase zero)' do
    xml_path = File.expand_path('../files/building_151.xml', File.dirname(__FILE__))

    expect(File.exist?(xml_path)).to be true

    out_path = File.expand_path('../output/phase0_building_151/', File.dirname(__FILE__))
    if File.exist?(out_path)
      FileUtils.rm_rf(out_path)
    end
    expect(File.exist?(out_path)).not_to be true

    FileUtils.mkdir_p(out_path)
    expect(File.exist?(out_path)).to be true

    translator = BuildingSync::Translator.new(xml_path, true)
    translator.write_osm(out_path)
  end

  it 'should parse and write DC GSA Headquarters.xml (phase zero)' do
    xml_path = File.expand_path('../files/DC GSA Headquarters.xml', File.dirname(__FILE__))

    expect(File.exist?(xml_path)).to be true

    out_path = File.expand_path('../output/DC GSA Headquarters/', File.dirname(__FILE__))
    if File.exist?(out_path)
      FileUtils.rm_rf(out_path)
    end
    expect(File.exist?(out_path)).not_to be true

    FileUtils.mkdir_p(out_path)
    expect(File.exist?(out_path)).to be true

    translator = BuildingSync::Translator.new(xml_path, false)
    translator.write_osm(out_path)
  end

  it 'should parse and write BuildingSync Website Valid Schema.xml (phase zero)' do
    xml_path = File.expand_path('../files/BuildingSync Website Valid Schema.xml', File.dirname(__FILE__))

    expect(File.exist?(xml_path)).to be true

    out_path = File.expand_path('../output/BuildingSync Website Valid Schema/', File.dirname(__FILE__))
    if File.exist?(out_path)
      FileUtils.rm_rf(out_path)
    end
    expect(File.exist?(out_path)).not_to be true

    FileUtils.mkdir_p(out_path)
    expect(File.exist?(out_path)).to be true

    translator = BuildingSync::Translator.new(xml_path, true)
    translator.write_osm(out_path)
  end

  it 'should parse and write building_151.xml (phase zero) with n1 namespace' do
    xml_path = File.expand_path('../files/building_151_n1.xml', File.dirname(__FILE__))
    expect(File.exist?(xml_path)).to be true

    out_path = File.expand_path('../output/phase0_building_151_n1/', File.dirname(__FILE__))
    if File.exist?(out_path)
      FileUtils.rm_rf(out_path)
    end
    expect(File.exist?(out_path)).not_to be true

    FileUtils.mkdir_p(out_path)
    expect(File.exist?(out_path)).to be true

    translator = BuildingSync::Translator.new(xml_path, true)
    translator.writeOSWs(out_path)

    osw_files = []
    Dir.glob("#{out_path}/**/*.osw") { |osw| osw_files << osw }

    expect(osw_files.size).to eq 30

    if BuildingSync::DO_SIMULATIONS
      num_sims = 0
      Parallel.each(osw_files, in_threads: [BuildingSync::NUM_PARALLEL, BuildingSync::MAX_DATAPOINTS].min) do |osw|
        break if num_sims > BuildingSync::MAX_DATAPOINTS

        cmd = "\"#{BuildingSync::OPENSTUDIO_EXE}\" run -w \"#{osw}\""
        puts "Running cmd: #{cmd}"
        result = system(cmd)
        expect(result).to be true

        num_sims += 1
      end

      translator.gatherResults(out_path)
      translator.saveXML(File.join(out_path, 'results.xml'))

      expect(translator.failed_scenarios.empty?).to be(true), "Scenarios #{translator.failed_scenarios.join(', ')} failed to run"
    end
  end
end
