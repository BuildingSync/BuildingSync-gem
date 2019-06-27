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

require_relative '../../../lib/buildingsync/get_bcl_weather_file'

RSpec.describe 'WeatherFileDownload' do
  it 'weather file download from the nrel site with the help of state and city name' do
    state, city = get_state_and_city_name('building_151', 'auc')
    BuildingSync::GetBCLWeatherFile.new.download_weather_file_from_city_name(state, city, latitude, longitude)
  end

  it 'weather file download from the nrel site  with the help of weather station ID' do
    weather_id = get_weather_id('building_151', 'auc')
    BuildingSync::GetBCLWeatherFile.new.download_weather_file_from_weather_id(weather_id)
  end

  def get_state_and_city_name(file_name, ns)
    doc = get_xml_object(file_name)

    address_element = doc.elements["#{ns}:BuildingSync/#{ns}:Facilities/#{ns}:Facility/#{ns}:Sites/#{ns}:Site"]

    city = address_element.elements["#{ns}:Address/#{ns}:City"].text
    state = address_element.elements["#{ns}:Address/#{ns}:State"].text
    return state, city
  end

  def get_weather_id(file_name, ns)
    doc = get_xml_object(file_name)
    site_element = doc.elements["#{ns}:BuildingSync/#{ns}:Facilities/#{ns}:Facility/#{ns}:Sites/#{ns}:Site"]

    return site_element.elements["#{ns}:WeatherDataStationID"].text
  end

  def get_xml_object(file_name)
    @xml_path = File.expand_path("../../files/#{file_name}.xml", File.dirname(__FILE__))
    expect(File.exist?(@xml_path)).to be true

    return create_xml_file_object(@xml_path)
  end
end
