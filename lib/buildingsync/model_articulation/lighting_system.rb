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
  class LightingSystemType

    def initialize(doc, ns)
      @lighting_type = Hash.new
      @ballast_type = Hash.new
      @primary_lighting_system_type = Hash.new

      doc.elements.each("#{ns}:Systems/#{ns}:LightingSystems/#{ns}:LightingSystem") do |lighting_system|
          read(lighting_system, ns)
        end
    end

    def read(section_element, ns)
      primary_lighting_type = nil
      if section_element.elements["#{ns}:PrimaryLightingSystemType"]
        primary_lighting_type = section_element.elements["#{ns}:PrimaryLightingSystemType"].text
      end
      if section_element.elements["#{ns}:LampType/#{ns}:SolidStateLighting/#{ns}:LampLabel"]
        lighting_type = section_element.elements["#{ns}:LampType/#{ns}:SolidStateLighting/#{ns}:LampLabel"].text
      end
      if section_element.elements["#{ns}:BallastType"]
        ballast_type = section_element.elements["#{ns}:BallastType"].text
      end
      if section_element.elements["#{ns}:LinkedPremises/#{ns}:Building/#{ns}:LinkedBuildingID"]
         linked_building = section_element.elements["#{ns}:LinkedPremises/#{ns}:Building/#{ns}:LinkedBuildingID"].attributes['IDref']
         puts "found primary lighting type: #{primary_lighting_type} for linked building: #{linked_building}"
         @primary_lighting_system_type[linked_building] = primary_lighting_type
         @lighting_type[linked_building] = lighting_type
         @ballast_type[linked_building] = ballast_type
      elsif section_element.elements["#{ns}:LinkedPremises/#{ns}:Section/#{ns}:LinkedSectionID"]
         linked_section = section_element.elements["#{ns}:LinkedPremises/#{ns}:Section/#{ns}:LinkedSectionID"].attributes['IDref']
         puts "found primary lighting type: #{primary_lighting_type} for linked section: #{linked_section}"
         @primary_lighting_system_type[linked_section] = primary_lighting_type
         @lighting_type[linked_section] = lighting_type
         @ballast_type[linked_section] = ballast_type
      elsif primary_lighting_type
         puts "primary_lighting_system_type: #{primary_lighting_type} is not linked to a building or section "
      end
    end
  end
end


