# BOSS - BuildingSync OpenStudio Simulator

BuildingSync OpenStudio Simulator (BOSS) takes in BuildingSync files, creates OpenStudio workflows from their contents, and runs those workflows to create models.

## Current Configuration  and Compatibility Matrix

BOSS currently supports OpenStudio 3.10 and BuildingSync 2.7.0

| BOSS Version | OpenStudio Version | BuildingSync Version |
|--------------|--------------------|----------------------|
| v0.2.1    | OpenStudio v3.0.1 | BuildingSync v2.2.0 |



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
BOSS uses its `Translator` class to 1) write openstudio workflows and 2) run those workflows.
```ruby
require 'buildingsync/translator'

# init translator
xml_file_path = "BuildingEQ-1.0.0_gemtest.xml"
output_dir = "output"
translator = BuildingSync::Translator.new(xml_file_path, output_dir, nil, "ASHRAE90.1")

# create baseline workflow from buildingsync file
translator.write_baseline_osw
expect(File.exist?("#{output_dir}/baseline/in.osw")).to be true

# create baseline model from workflow
translator.run_baseline_osw
expect(File.exist?("#{output_dir}/baseline/out.osw")).to be true
expect(File.exist?("#{output_dir}/baseline/in.osm")).to be true
```

The file `workflow_maker.rb` does all of the actual writing to the osw. Each function writes one measure. Heres an overview of how each measure is populated.

[set_run_period]: https://github.com/NatLabRockies/openstudio-common-measures-gem/blob/v0.12.3/lib/measures/set_run_period/README.md
[ChangeBuildingLocation]: https://github.com/NatLabRockies/openstudio-common-measures-gem/blob/v0.12.3/lib/measures/ChangeBuildingLocation/README.md
[create_bar_from_building_type_ratios]: https://github.com/NatLabRockies/openstudio-model-articulation-gem/blob/v0.12.2/lib/measures/create_bar_from_building_type_ratios/README.md
[create_typical_building_from_model]: https://github.com/NatLabRockies/openstudio-model-articulation-gem/blob/v0.12.2/lib/measures/create_typical_building_from_model/README.md
[SetLightingLoadsByLPD]: https://github.com/NatLabRockies/openstudio-common-measures-gem/blob/v0.12.3/lib/measures/SetLightingLoadsByLPD/README.md
[set_electric_equipment_loads_by_epd]: https://github.com/NatLabRockies/openstudio-common-measures-gem/tree/v0.12.3/lib/measures/set_electric_equipment_loads_by_epd
[openstudio_results]: https://github.com/NatLabRockies/openstudio-common-measures-gem/blob/v0.12.3/lib/measures/openstudio_results/README.md

| Measure                                | Argument                | Will error if Unset | Description                                                                                                                       |
|----------------------------------------|-------------------------|:-------------------:|-----------------------------------------------------------------------------------------------------------------------------------|
| [set_run_period]                       |                         |                     |                                                                                                                                   |
|                                        | timesteps_per_hour      |                     | Hard Coded to `1`                                                                                                                 |
|                                        | begin_date              |                     | Hard Coded to `2019-01-01`                                                                                                        |
|                                        | end_date                |                     | Hard Coded to `2019-12-31`                                                                                                        |
| [ChangeBuildingLocation]               |                         |                     |                                                                                                                                   |
|                                        | weather_file_name       |          X          | set via `set_weather_and_climate_zone` from the given weather file, or the building's climate zone, or city and state.            |
|                                        | climate_zone            |                     | The site's climate zone, set via `determine_climate_zone`, which chooses either the `CaliforniaTitle24` or  `ASHRAE` climate zone |
| [create_bar_from_building_type_ratios] |                         |                     |                                                                                                                                   |
|                                        | bldg_type_a             |          X          | set via `building.get_building_type`, which in turn is set via `set_bldg_and_system_type_for_building_and_section`                |
|                                        | total_bldg_floor_area   |          X          | set via `building.total_bldg_floor_area`, which is set via `read_floor_areas`                                                     |
|                                        | floor_height            |                     | set via `get_floor_to_floor_height`. Set to the `floor_to_floor_height` of the largest building section                           |
|                                        | num_stories_above_grade |                     | set via `building.num_stories_above_grade`, which is set via `read_stories_above_and_below_grade`                                 |
|                                        | num_stories_below_grade |                     | set via `building.num_stories_below_grade`, which is set via `read_stories_above_and_below_grade`                                 |
|                                        | building_rotation       |                     | always set to 0, not read from BuildingSync file                                                                                  |
|                                        | template                |          X          | set via `building.get_standard_template`, which is set via `set_standard_template`                                                |
|                                        | ns_to_ew_ratio          |                     | set via `building.ns_to_ew_ratio`, which is set via `set_ns_to_ew_ratio`                                                          |
|                                        | wwr                     |                     | set via `building.wwr`, which is set via `set_building_form_defaults`                                                             |
|                                        | party_wall_fraction     |                     | set via `building.party_wall_fraction`, which is always set to zero                                                               |
|                                        | story_multiplier_method |                     | set to None                                                                                                                       |
| [create_typical_building_from_model]   |                         |                     |                                                                                                                                   |
|                                        | template                |          X          | set via `building.get_standard_template`, which is set via `set_standard_template`                                                |
|                                        | system_type             |                     | set to `facility.get_principal_HVAC_system_type`                                                                                  |
|                                        | add_swh                 |                     | set to `facility.get_principal_HVAC_system_type`                                                                                  |
|                                        | add_hvac                |                     | set to `facility.get_principal_HVAC_system_type`                                                                                  |
| [SetLightingLoadsByLPD]                |                         |                     |                                                                                                                                   |
|                                        | lpd                     |                     | set to `facility.get_total_installed_power`                                                                                       |
| [set_electric_equipment_loads_by_epd]  |                         |                     |                                                                                                                                   |
|                                        | epd                     |                     | set to `facility.get_total_installed_power * 1000 / building.total_floor_area`                                                    |
| [openstudio_results]                   |                         |                     |                                                                                                                                   |


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
