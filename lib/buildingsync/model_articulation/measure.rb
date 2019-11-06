# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2019, Alliance for Sustainable Energy, LLC.
# BuildingSync(R), Copyright (c) 2015-2019, Alliance for Sustainable Energy, LLC.
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
  class Measure
    # initialize
    def initialize(measure_element, ns)
      @field_value = nil
      @system_category_affected = nil
      @measure_total_first_cost = nil
      @annual_savings_cost = nil
      @simple_payback = nil
      @measure_rank = nil
      @field_value = nil
      @annual_savings_native_units = nil

      read_xml(measure_element, ns)
    end

    # adding a measures to the facility
    def read_xml(measure_element, ns)
      read_measure_other_detail(measure_element, ns)
    end

    def read_measure_other_detail(measure_element, ns)
      if measure_element.elements["#{ns}:AnnualSavingsCost"]
        @annual_savings_cost = measure_element.elements["#{ns}:AnnualSavingsCost"].text
      else
        @annual_savings_cost = nil
      end

      if measure_element.elements["#{ns}:SystemCategoryAffected"]
        @system_category_affected = measure_element.elements["#{ns}:SystemCategoryAffected"].text
      else
        @system_category_affected = nil
      end

      if measure_element.elements["#{ns}:AnnualSavingsByFuels"]
        if measure_element.elements["#{ns}:AnnualSavingsByFuels/#{ns}:SimplePayback"]
          @simple_payback = measure_element.elements["#{ns}:AnnualSavingsByFuels/#{ns}:SimplePayback"].text
        else
          @simple_payback = nil
        end

        if measure_element.elements["#{ns}:AnnualSavingsByFuels/#{ns}:MeasureRank"]
          @measure_rank = measure_element.elements["#{ns}:AnnualSavingsByFuels/#{ns}:MeasureRank"].text
        else
          @measure_rank = nil
        end
      end

      if measure_element.elements["#{ns}:MeasureTotalFirstCost"]
        @measure_total_first_cost = measure_element.elements["#{ns}:MeasureTotalFirstCost"].text
      else
        @measure_total_first_cost = nil
      end

      if measure_element.elements["#{ns}:UserDefinedFields/#{ns}:UserDefinedField/#{ns}:FieldValue"]
        @field_value = measure_element.elements["#{ns}:UserDefinedFields/#{ns}:UserDefinedField/#{ns}:FieldValue"].text
      else
        @field_value = nil
      end

      if measure_element.elements["#{ns}:MeasureSavingsAnalysis/#{ns}:AnnualSavingsByFuels/#{ns}:AnnualSavingsByFuel/#{ns}:AnnualSavingsNativeUnits"]
        @annual_savings_native_units = measure_element.elements["#{ns}:MeasureSavingsAnalysis/#{ns}:AnnualSavingsByFuels/#{ns}:AnnualSavingsByFuel/#{ns}:AnnualSavingsNativeUnits"].text
      else
        @annual_savings_native_units = nil
      end
    end
  end
end
