# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2020, Alliance for Sustainable Energy, LLC.
# BuildingSync(R), Copyright (c) 2015-2020, Alliance for Sustainable Energy, LLC.
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
  ##
  # this class holds the parameters related to the hours of operation
  ##
  class HoursOfOperation
    ##
    # initialize the hours of operation class and set default values
    ##
    # @param hours_per_week [float]
    def initialize(hours_per_week)
      @hours_per_week = hours_per_week
      @start_wkdy = 9.0
      @end_wkdy = 17
      @start_sat = 9.0
      @end_sat = 12.0
      @start_sun = 7.0
      @end_sun = 18.0
      # these default values are coming from the create_parametric_schedules measure in the openstudio-model-articulation-gem
      # see: https://github.com/NREL/openstudio-model-articulation-gem/blob/e1da9c43d6cee75012520975cc4b7022414336b6/lib/measures/create_parametric_schedules/measure.rb#L68
    end

    # occupied hours per week
    # @return [float]
    attr_reader :hours_per_week

    # start hour on saturdays
    # @return [float]
    attr_reader :start_sat

    # end hour on saturdays
    # @return [float]
    attr_reader :end_sat

    # start hour on sundays
    # @return [float]
    attr_reader :start_sun

    # end hour on sundays
    # @return [float]
    attr_reader :end_sun

    # start hour on a weekday
    # @return [float]
    attr_accessor :start_wkdy

    # end hour on a weekday
    # @return [float]
    attr_accessor :end_wkdy
  end
end

