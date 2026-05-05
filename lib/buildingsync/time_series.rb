# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************
module BuildingSync
  # TimeSeries class
  class TimeSeries
    include BuildingSync::Helper
    include BuildingSync::XmlGetSet
    # initialize
    # @param @base_xml [REXML::Element]
    # @param ns [String]
    def initialize(base_xml, ns)
      @base_xml = base_xml
      @ns = ns
      help_element_class_type_check(base_xml, 'TimeSeries')

      # translates to: 2020-01-01T00:00:00
      @timestamp_format = '%FT%T'
    end

    # Creates monthly start and end times for the element.
    # @param start_date_time [DateTime] should be the zeroth second of the month, i.e. 2020-01-01T00:00:00
    def set_start_and_end_timestamps_monthly(start_date_time)
      xset_or_create('StartTimestamp', start_date_time.strftime(@timestamp_format))

      # >>= shifts a datetime by 1 month
      end_date = start_date_time >>= 1

      # += shifts a datetime by 1 day.  the following shifts it by negative 1 minute
      end_date += - Rational(1, 24.0 * 60)

      # Always sets to last minute of the month:
      # 2020-01-31T23:59:00
      xset_or_create('EndTimestamp', end_date.strftime(@timestamp_format))
    end

    # @param start_date_time [DateTime] should be the zeroth second of the month, i.e. 2020-01-01T00:00:00
    # @param interval_reading_value [Numeric] the value to use for IntervalReading
    # @param resource_use_id [String] the ID of the ResourceUse to point to
    def set_monthly_energy_reading(start_date_time, interval_reading_value, resource_use_id)
      xset_or_create('ReadingType', 'Total')
      xset_or_create('TimeSeriesReadingQuantity', 'Energy')
      set_start_and_end_timestamps_monthly(start_date_time)
      xset_or_create('IntervalFrequency', 'Month')
      xset_or_create('IntervalReading', interval_reading_value)
      ru_id_element = xget_or_create('ResourceUseID')
      ru_id_element.add_attribute('IDref', resource_use_id)
    end
  end
end
