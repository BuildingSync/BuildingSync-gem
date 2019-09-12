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
require_relative 'building_system'
module BuildingSync
  class EnvelopeSystem < BuildingSystem
    # initialize
    def initialize
      # code to initialize
    end

    # add internal loads from standard definitions
    def create(model, standard, primary_bldg_type, lookup_building_type, remove_objects)
      # remove default construction sets
      if remove_objects
        model.getDefaultConstructionSets.each(&:remove)
      end

      # TODO: - allow building type and space type specific constructions set selection.
      if ['SmallHotel', 'LargeHotel', 'MidriseApartment', 'HighriseApartment'].include?(primary_bldg_type)
        is_residential = 'Yes'
      else
        is_residential = 'No'
      end
      climate_zone = standard.model_get_building_climate_zone_and_building_type(model)['climate_zone']
      OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Facility.create_building_system', 'Could not find climate zone in the model. Verify that the climate zone is set in the BuildingSync File or can be derived from other inputs.') if climate_zone.nil?
      bldg_def_const_set = standard.model_add_construction_set(model, climate_zone, lookup_building_type, nil, is_residential)
      if bldg_def_const_set.is_initialized
        bldg_def_const_set = bldg_def_const_set.get
        if is_residential then bldg_def_const_set.setName("Res #{bldg_def_const_set.name}") end
        model.getBuilding.setDefaultConstructionSet(bldg_def_const_set)
        OpenStudio.logFree(OpenStudio::Info, 'BuildingSync.Facility.create_building_system', "Adding default construction set named #{bldg_def_const_set.name}")
      else
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Facility.create_building_system', "Could not create default construction set for the building type #{lookup_building_type} in climate zone #{climate_zone}.")
        return false
      end

      # address any adiabatic surfaces that don't have hard assigned constructions
      model.getSurfaces.each do |surface|
        next if surface.outsideBoundaryCondition != 'Adiabatic'
        next if surface.construction.is_initialized

        surface.setAdjacentSurface(surface)
        surface.setConstruction(surface.construction.get)
        surface.setOutsideBoundaryCondition('Adiabatic')
      end

      # Modify the infiltration rates
      if remove_objects
        model.getSpaceInfiltrationDesignFlowRates.each(&:remove)
      end
      standard.model_apply_infiltration_standard(model)
      standard.model_modify_infiltration_coefficients(model, primary_bldg_type, climate_zone)

      # set ground temperatures from DOE prototype buildings
      standard.model_add_ground_temperatures(model, primary_bldg_type, climate_zone)
    end
  end
end
