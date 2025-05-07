class OSWARGPopulator
  # static class of methods for populating a given ows with the given facility.
  # each function is named after the measure it populates

  def self.populate_set_run_period_args(ows, facility)
    building = facility.site.get_building
    set_measure_argument = lambda {| key, value | OpenStudio::Extension.set_measure_argument(ows, "set_run_period", key, value) }

    # Add args
    # -  __SKIP__
    # -  timesteps_per_hour
    # -  begin_date
    # -  end_date

  end

  def self.populate_change_building_location_args(ows, facility)
    building = facility.site.get_building
    set_measure_argument = lambda {| key, value | OpenStudio::Extension.set_measure_argument(ows, "ChangeBuildingLocation", key, value) }

    # -  __SKIP__
    # -  weather_file_name
    # -  climate_zone

  end

  def self.populate_create_bar_from_building_type_ratios_args(ows, facility)
    building = facility.site.get_building
    set_measure_argument = lambda {| key, value | OpenStudio::Extension.set_measure_argument(ows, "create_bar_from_building_type_ratios", key, value) }

    # Add args
    # -  __SKIP__
    # -  bldg_type_a
    # -  bldg_type_a_num_units
    # -  bldg_type_b
    # -  bldg_type_b_fract_bldg_area
    # -  bldg_type_b_num_units
    # -  bldg_type_c
    # -  bldg_type_c_fract_bldg_area
    # -  bldg_type_c_num_units
    # -  bldg_type_d
    # -  bldg_type_d_fract_bldg_area
    # -  bldg_type_d_num_units
    # -  single_floor_area
    # -  floor_height
    set_measure_argument.call("floor_height", building.floor_height)
    # -  num_stories_above_grade
    set_measure_argument.call("num_stories_above_grade", building.num_stories_above_grade.to_i)
    # -  num_stories_below_grade
    set_measure_argument.call("num_stories_below_grade", building.num_stories_below_grade.to_i)
    # -  building_rotation
    set_measure_argument.call("building_rotation", building.building_rotation.to_i)
    # -  template
    # -  ns_to_ew_ratio
    # -  wwr
    set_measure_argument.call("wwr", building.wwr.to_i)
    # -  party_wall_fraction
    # -  story_multiplier_method
    # -  bar_division_method

  end

  def self.populate_openstudio_results_args(ows, facility)
    building = facility.site.get_building
    set_measure_argument = lambda {| key, value | OpenStudio::Extension.set_measure_argument(ows, "openstudio_results", key, value) }

    # Add args
    # -  __SKIP__

  end

end
