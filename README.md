# BuildingSync

![BuildingSync-gem](https://github.com/BuildingSync/BuildingSync-gem/actions/workflows/continuous_integration.yml/badge.svg?branch=develop)

The BuildingSync-Gem takes in BuildingSync files, creates OpenStudio workflows from their contents, and runs those workflows to create models.


## Installation
1. Install OpenStudio 3.10. Check installation with 
    ```console
    🌟 openstudio --version
    3.10.0+ce46db07de
    ```

2. Set enviroment variable `RUBYLIB` to the location of your openstudio installation. Check env var with:
    ```console
    🌟 echo $RUBYLIB
    /Applications/OpenStudio-3.10.0/Ruby
    ```

3. From local repo, bundle install

    ```bash
    🌟 bundle install
    ```

## Usage

```ruby
require 'buildingsync/translator'

# init  translator
translator = BuildingSync::Translator.new(
  bsync_file="BuildingEQ-1.0.0_gemtest.xml", 
  output_path="output", 
  epw_path=nil, # optional weather file
  standard="ASHRAE90.1"
)

# create baseline workflow from buildingsync file
translator.write_baseline_osw
expect(File.exist?(output_path + "/baseline/in.osw")).to be true

# create baseline model from workflow
translator.run_baseline_osw
expect(File.exist?(output_path + "/baseline/out.osw")).to be true
expect(File.exist?(output_path + "/baseline/in.osm")).to be true

```

## Testing

Check out the repository and then execute:

```bash
bundle exec rspec ./spec/tests/translator_write_osw_spec.rb
```

This only runs only files worth of tests, which are integration tests very similar to the code in the usage section. The gem has under gone major rewrites and many of the other tests use  dead and/or delete code. Further clean up and testing is underway.  

# Releasing

1. Update CHANGELOG.md
1. Run `bundle exec rake rubocop:auto_correct`
1. Update version in `lib/buildingsync/version.rb`
1. Create PR to main, after tests and reviews complete, then merge
1. Locally - from the main branch, run `bundle exec rake release`
1. On GitHub, go to the releases page and update the latest release tag. Name it “Version x.y.z” and copy the CHANGELOG entry into the description box.
