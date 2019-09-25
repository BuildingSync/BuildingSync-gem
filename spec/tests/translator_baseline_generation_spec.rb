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
RSpec.describe 'BuildingSync' do
  it 'should parse and write building_151.xml (phase zero) with auc namespace for Title24' do
    test_baseline_creation('building_151.xml', CA_TITLE24)
  end

  it 'should parse and write building_151.xml (phase zero) with auc namespace for ASHRAE 90.1' do
    test_baseline_creation('building_151.xml', ASHRAE90_1)
  end

  it 'should parse and write building_151_n1.xml (phase zero) with n1 namespace for Title24' do
    test_baseline_creation('building_151_n1.xml', CA_TITLE24)
  end

  it 'should not find the Standard for large office and Title24 with DC GSA Headquarters.xml (phase zero)' do
    begin
      test_baseline_creation('DC GSA Headquarters.xml', CA_TITLE24, 'CZ01RV2.epw')
    rescue StandardError => e
      expect(e.message.include?("Did not find a class called 'CBES Pre-1978_LargeOffice' to create in")).to be true
    end
  end

  it 'should parse and write DC GSA Headquarters.xml (phase zero) with ASHRAE 90.1' do
    test_baseline_creation('DC GSA Headquarters.xml', ASHRAE90_1, 'CZ01RV2.epw')
  end

  it 'should parse and write DC GSA Headquarterswith.xml (phase zero) with ASHRAE 90.1' do
    test_baseline_creation('DC GSA HeadquartersWithClimateZone.xml', ASHRAE90_1, 'CZ01RV2.epw')
  end

  it 'should parse and write BuildingSync Website Valid Schema.xml (phase zero) with Title 24' do
    test_baseline_creation('BuildingSync Website Valid Schema.xml', CA_TITLE24, 'CZ01RV2.epw')
  end

  it 'should parse and write BuildingSync Website Valid Schema.xml (phase zero) with ASHRAE 90.1' do
    test_baseline_creation('BuildingSync Website Valid Schema.xml', ASHRAE90_1, 'CZ01RV2.epw')
  end

  it 'should parse and write Golden Test File.xml (phase zero) with Title 24' do
    begin
    test_baseline_creation('Golden Test File.xml', CA_TITLE24, 'CZ01RV2.epw')
    rescue StandardError => e
      expect(e.message.include?("Did not find a class called 'CBES T24 2008_LargeOffice' to create in")).to be true
    end
  end

  it 'should parse and write Golden Test File.xml (phase zero) with ASHRAE 90.1' do
    begin
      test_baseline_creation('Golden Test File.xml', ASHRAE90_1, 'CZ01RV2.epw')
    rescue StandardError => e
      expect(e.message.include?('Error: There is more than one (2) building attached to this site in your BuildingSync file.')).to be true
    end
  end

  it 'should parse and write Golden Test File.xml (phase zero) with ASHRAE 90.1 and without weather file' do
    begin
      test_baseline_creation('Golden Test File.xml', ASHRAE90_1)
    rescue StandardError => e
      expect(e.message.include?('Error: There is more than one (2) building attached to this site in your BuildingSync file.')).to be true
    end
  end
end
