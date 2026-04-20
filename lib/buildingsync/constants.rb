# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************

SCHEMA_2_0_URL = 'https://raw.githubusercontent.com/BuildingSync/schema/v2.0/BuildingSync.xsd'
SCHEMA_2_2_0_URL = 'https://raw.githubusercontent.com/BuildingSync/schema/v2.2.0/BuildingSync.xsd'
SCHEMA_2_4_0_URL = 'https://raw.githubusercontent.com/BuildingSync/schema/v2.4.0/BuildingSync.xsd'
SCHEMA_2_7_0_URL = 'https://raw.githubusercontent.com/BuildingSync/schema/v2.7.0/BuildingSync.xsd'
PHASE_0_BASE_OSW_FILE_PATH = File.expand_path(File.join(__dir__, 'makers/phase_zero_base.osw'))
EMPTY_BASELINE_OSW_PATH = File.expand_path(File.join(__dir__, 'makers/empty_baseline.osw'))
WORKFLOW_MAKER_JSON_FILE_PATH = File.expand_path(File.join(__dir__, 'makers/workflow_maker.json'))
BUILDING_AND_SYSTEMS_FILE_PATH = File.expand_path(File.join(__dir__, 'model_articulation/building_and_system_types.json'))
WEATHER_DIR = File.expand_path(File.join(__dir__, '../data/weather'))

# Standards strings
ASHRAE90_1 = 'ASHRAE90.1'
CA_TITLE24 = 'CaliforniaTitle24'
