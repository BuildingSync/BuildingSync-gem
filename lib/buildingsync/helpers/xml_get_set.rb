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
require 'rexml/document'

require 'buildingsync/helpers/helper'

module BuildingSync
  # Used for getting, setting, and creating XML snippets
  # for BuildingSync classes with an @base_xml attribute
  module XmlGetSet

    # Get the id attribute of the @base_xml
    # @see help_get_attribute_value
    def xget_id
      return help_get_attribute_value(@base_xml, 'ID')
    end

    # Get the name of the element, based on the type of element
    # @example scenario.get_name, returns text for ScenarioName element
    # @example site.get_name, returns text for SiteName
    # @return [String] name associated with the @base_xml
    def xget_name
      premises = ['Site', 'Building', 'Section', 'ThermalZone', 'Space']
      if premises.include? @base_xml.name
        return xget_text("PremisesName")
      elsif @base_xml.name == 'Measure'
        m = @base_xml.elements[".//#{@ns}:MeasureName"]
        return help_get_text_value(m)
      else
        return xget_text("#{@base_xml.name}Name")
      end
    end

    def xget_attribute_for_element(element_name, attribute)
      element = @base_xml.elements["./#{@ns}:#{element_name}"]
      return help_get_attribute_value(element, attribute)
    end

    # returns the first element with the specified element name
    # @param element_name [String] non-namespaced element name, 'EnergyResource'
    # @return [REXML::Element] if element exists
    # @return [nil] if element doesnt exist
    def xget_element(element_name)
      return @base_xml.elements["./#{@ns}:#{element_name}"]
    end

    # get or create a new element
    # @param element_name [String] non-namespaced element name, 'EnergyResource'
    # @see help_get_or_create
    def xget_or_create(element_name)
      return help_get_or_create(@base_xml, "#{@ns}:#{element_name}")
    end

    # @param element_name [String] non-namespaced element name, 'EnergyResource'
    # @see help_get_text_value
    def xget_text(element_name)
      return help_get_text_value(@base_xml.elements["./#{@ns}:#{element_name}"])
    end

    # @param element_name [String] non-namespaced element name, 'YearOfConstruction'
    # @see help_get_text_value_as_float
    def xget_text_as_float(element_name)
      return help_get_text_value_as_float(@base_xml.elements["./#{@ns}:#{element_name}"])
    end

    # @param element_name [String] non-namespaced element name, 'YearOfConstruction'
    # @see help_get_text_value_as_integer
    def xget_text_as_integer(element_name)
      return help_get_text_value_as_integer(@base_xml.elements["./#{@ns}:#{element_name}"])
    end

    # @param element_name [String] non-namespaced element name, 'BuildingAutomationSystem'
    # @see help_get_text_value_as_bool
    def xget_text_as_bool(element_name)
      return help_get_text_value_as_bool(@base_xml.elements["./#{@ns}:#{element_name}"])
    end

    # @param element_name [String] non-namespaced element name, 'RetrocommissioningDate'
    # @see help_get_text_value_as_date
    def xget_text_as_date(element_name)
      return help_get_text_value_as_date(@base_xml.elements["./#{@ns}:#{element_name}"])
    end

    # @param element_name [String] non-namespaced element name, 'StartTimestamp'
    # @see help_get_text_value_as_datetime
    def xget_text_as_dt(element_name)
      return help_get_text_value_as_datetime(@base_xml.elements["./#{@ns}:#{element_name}"])
    end

    # Gets all of the IDref attributes of the element_name provided
    # assumes there is a parent child containment downstream of the base_xml,
    # where the parent is a plural version of the element_name provided
    # @example xget_idrefs('Measure') #=> Searches for .//Measures/Measure
    # @param element_name [String] name of the non-pluralized element, i.e. Measure
    # @return [Array<String>] all associated IDs ['Measure-1', 'Measure-2', etc.]
    def xget_idrefs(element_name)
      id_elements = @base_xml.get_elements(".//#{@ns}:#{element_name}s/#{@ns}:#{element_name}")
      to_return = []
      id_elements.each do |id|
        to_return << help_get_attribute_value(id, 'IDref')
      end
      return to_return
    end

    # Get the linked premises ids of the @base_xml element
    # @return [Hash] where keys are premise types and values are an array of ids
    # @example {'Building' => ['Building-1', 'Building-1'], 'Section' => ['Section-4']]}
    def xget_linked_premises
      map = {}
      premises = @base_xml.get_elements(".//#{@ns}:LinkedPremises").first()
      if !premises.nil?
        premises.elements.each do |premise_type|
          map[premise_type.name] = []
          idref_elements = premise_type.get_elements(".//*[@IDref]")
          if !idref_elements.nil?
            idref_elements.each do |element|
              map[premise_type.name] << element.attributes["IDref"]
            end
          end
        end
      end
      return map
    end

    # Only sets the text for an element if it exists
    # @param element_name [String] non-namespaced element name, 'EnergyResource'
    # @param new_value [String] new text value to use, 'Electricity'
    # @return [REXML::Element] if element exists
    # @return [nil] if element doesn't exist
    def xset_text(element_name, new_value)
      element = @base_xml.elements["./#{@ns}:#{element_name}"]
      if !element.nil?
        element.text = new_value
      end
      return element
    end

    # Sets the text for an element if it exists, or creates the element then sets
    # the text if it doesn't exist
    # @param element_name [String] non-namespaced element name, 'EnergyResource'
    # @param new_value [String] new text value to use, 'Electricity'
    # @param override [Boolean] whether to override the text value if the element already has text
    # @return [REXML::Element] the element
    def xset_or_create(element_name, new_value, override = true)
      element = @base_xml.elements["./#{@ns}:#{element_name}"]
      if !element.nil?
        # if there is no value, we set it
        if element.text.nil? || element.text.empty?
          element.text = new_value
        # if there is a value but we are overriding, we set it
        elsif override
          element.text = new_value
        end
      else
        new_element = REXML::Element.new("#{@ns}:#{element_name}", @base_xml)
        new_element.text = new_value
      end
      return element
    end

  end
end
