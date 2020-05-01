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

RSpec.describe 'LoadSystemSpec' do
  it 'Should add internal loads successfully' do
    model = OpenStudio::Model::Model.new
    standard = Standard.build('DOE Ref Pre-1980')
    load_system = BuildingSync::LoadsSystem.new
    puts 'expected add internal loads : true but got: false} ' if load_system.add_internal_loads(model, standard, 'DOE Ref Pre-1980', nil, false) != true
    expect(load_system.add_internal_loads(model, standard, 'DOE Ref Pre-1980', nil, false)).to be true
  end

  it 'Should add exterior lights successfully' do
    site = create_minimum_site('Retail', '1980', 'Gross', '20000')
    site.determine_open_studio_standard(ASHRAE90_1)
    site.generate_baseline_osm(File.expand_path('../../weather/CZ01RV2.epw', File.dirname(__FILE__)), ASHRAE90_1)
    # we need to create a site and call the generate_baseline_osm method in order to set the space types in the model, why are those really needed?
    load_system = BuildingSync::LoadsSystem.new
    puts 'expected add internal loads : true but got: false} ' if load_system.add_exterior_lights(site.get_model, site.determine_open_studio_system_standard, 1.0, '3 - All Other Areas', false) != true
    expect(load_system.add_exterior_lights(site.get_model, site.determine_open_studio_system_standard, 1.0, '3 - All Other Areas', false)).to be true
  end

  it 'Should add elevator successfully' do
    model = OpenStudio::Model::Model.new
    standard = Standard.build('DOE Ref Pre-1980')
    load_system = BuildingSync::LoadsSystem.new
    puts 'expected add elevator : true but got: false} ' if load_system.add_elevator(model, standard) != true
    expect(load_system.add_elevator(model, standard)).to be true
  end

  it 'Should add daylighting controls successfully' do
    model = OpenStudio::Model::Model.new
    standard = Standard.build('DOE Ref Pre-1980')
    load_system = BuildingSync::LoadsSystem.new
    puts 'expected add day lighting controls : true but got: false} ' if load_system.add_day_lighting_controls(model, standard, 'DOE Ref Pre-1980') != true
    expect(load_system.add_day_lighting_controls(model, standard, 'DOE Ref Pre-1980')).to be true
  end
end
