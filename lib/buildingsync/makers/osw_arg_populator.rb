class OSWARGPopulator
  # static class of methods for populating a given osw with the given facility.
  # each function is named after the measure it populates

  def self.populate_set_run_period_args(osw, facility)
    building = facility.site.get_building
    osw[:steps].append({"measure_dir_name": "set_run_period", "arguments": {}})
    set_measure_argument = lambda {| key, value | OpenStudio::Extension.set_measure_argument(osw, "set_run_period", key, value) }

    # Add args
    # -  __SKIP__
    set_measure_argument.call("__SKIP__", false)
    # -  timesteps_per_hour
    set_measure_argument.call("timesteps_per_hour", "1")
    # -  begin_date
    set_measure_argument.call("begin_date", "2019-01-01")
    # -  end_date
    set_measure_argument.call("end_date", "2019-12-31")

  end

  def self.populate_change_building_location_args(osw, facility)
    building = facility.site.get_building
    osw[:steps].append({"measure_dir_name": "ChangeBuildingLocation", "arguments": {}})
    set_measure_argument = lambda {| key, value | OpenStudio::Extension.set_measure_argument(osw, "ChangeBuildingLocation", key, value) }

    # -  __SKIP__
    set_measure_argument.call("__SKIP__", false)
    # -  weather_file_name
    set_measure_argument.call("weather_file_name", building.epw_file_path)
    # -  climate_zone
    set_measure_argument.call("climate_zone", "Lookup From Stat File")

  end

  def self.populate_create_bar_from_building_type_ratios_args(osw, facility)
    building = facility.site.get_building
    osw[:steps].append({"measure_dir_name": "create_bar_from_building_type_ratios", "arguments": {}})
    set_measure_argument = lambda {| key, value | OpenStudio::Extension.set_measure_argument(osw, "create_bar_from_building_type_ratios", key, value) }

    # Add args
    # -  __SKIP__
    set_measure_argument.call("__SKIP__", false)
    # -  bldg_type_a
    set_measure_argument.call("bldg_type_a", building.get_building_type)
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
    # -  total_bldg_floor_area
    set_measure_argument.call("total_bldg_floor_area", building.total_floor_area)
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
    set_measure_argument.call("party_wall_fraction", building.party_wall_fraction.to_i)
    # -  story_multiplier_method
    # -  bar_division_method

  end

  def self.populate_create_typical_building_from_model_args(osw, facility)
    building = facility.site.get_building
    osw[:steps].append({"measure_dir_name": "create_typical_building_from_model", "arguments": {}})
    set_measure_argument = lambda {| key, value | OpenStudio::Extension.set_measure_argument(osw, "create_typical_building_from_model", key, value) }

    # Add args
    # -  __SKIP__
    set_measure_argument.call("__SKIP__", false)
    # template
    set_measure_argument.call("template", building.get_standard_template)
    # system_type
    # set_measure_argument.call("system_type", building.get_system_type)
    # hvac_delivery_type
    # htg_src
    # clg_src
    # swh_src
    # kitchen_makeup
    # exterior_lighting_zone
    # add_constructions
    # wall_construction_type
    # add_space_type_loads
    # add_elevators
    # add_internal_mass
    # add_exterior_lights
    # onsite_parking_fraction
    # add_exhaust
    # add_swh
    # add_thermostat
    # add_hvac
    # add_refrigeration
    # modify_wkdy_op_hrs
    # wkdy_op_hrs_start_time
    # wkdy_op_hrs_duration
    # modify_wknd_op_hrs
    # wknd_op_hrs_start_time
    # wknd_op_hrs_duration
    # unmet_hours_tolerance
    # remove_objects
    # use_upstream_args
    # enable_dst

  end

  def self.populate_openstudio_results_args(osw, facility)
    building = facility.site.get_building
    osw[:steps].append({"measure_dir_name": "openstudio_results", "arguments": {}})
    set_measure_argument = lambda {| key, value | OpenStudio::Extension.set_measure_argument(osw, "openstudio_results", key, value) }

    # Add args
    # -  __SKIP__
    set_measure_argument.call("__SKIP__", false)

  end

end
