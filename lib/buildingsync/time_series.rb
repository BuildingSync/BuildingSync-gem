# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2021, Alliance for Sustainable Energy, LLC.
# BuildingSync(R), Copyright (c) 2015-2021, Alliance for Sustainable Energy, LLC.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER(S) AND ANY CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER(S), ANY CONTRIBUTORS, THE
# UNITED STATES GOVERNMENT, OR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF
# THEIR EMPLOYEES, BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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
