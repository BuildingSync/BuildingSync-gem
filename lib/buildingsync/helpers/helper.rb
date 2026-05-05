# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************
module BuildingSync
  # helper class for helper methods in BuildingSync
  module Helper
    def help_element_class_type_check(xml_element, expected_type)
      if xml_element.name != expected_type
        OpenStudio.logFree(OpenStudio::Error, "BuildingSync.#{expected_type}.initialize", "Attempted to initialize #{expected_type} object with Element name of: #{xml_element.name}")
        raise StandardError, "Attempted to initialize #{expected_type} object with Element name of: #{xml_element.name}"
      end
    end

    def help_get_or_create(parent, new_element_type)
      new_element = parent.elements[new_element_type]
      if new_element.nil?
        new_element = REXML::Element.new(new_element_type, parent)
      end
      return new_element
    end

    # get text value from xml element
    # @param xml_element [REXML::Element]
    # @return [String] if text value exists
    # @return [nil] if text value doesnt exist or element is complex (has children)
    def help_get_text_value(xml_element)
      if xml_element && !xml_element.text.nil?
        return xml_element.text
      end
      return nil
    end

    def help_get_text_value_as_float(xml_element)
      v = help_get_text_value(xml_element)
      return v.to_f
    end

    def help_get_text_value_as_integer(xml_element)
      v = help_get_text_value(xml_element)
      return v.to_i
    end

    def help_get_text_value_as_bool(xml_element)
      v = help_get_text_value(xml_element)
      return v.to_bool
    end

    # convert between supported units
    # @param val [Numeric] value to convert, i.e. 1
    # @param from_unit [String] starting units
    # @param to_unit [String] desired end units
    # @return [Float] if successful, converted value
    # @return [nil] if unsuccessful
    def help_convert(val, from_unit, to_unit)
      if from_unit == to_unit
        return val
      end

      btu_multiples = [
        {
          'from' => 'Btu',
          'kBtu' => 0.001,
          'MMBtu' => 0.000001
        },
        {
          'from' => 'kBtu',
          'Btu' => 1000,
          'MMBtu' => 0.001
        },
        {
          'from' => 'MMBtu',
          'Btu' => 1000000,
          'kBtu' => 1000
        }
      ]
      map = btu_multiples.find { |from| from['from'] == from_unit }
      if !map.nil? && !map.empty?
        mult = map[to_unit]
        if !mult.nil?
          return val * mult
        else
          OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Helper.help_convert', "Unable to convert from: #{from_unit} to #{to_unit}")
        end
      else
        OpenStudio.logFree(OpenStudio::Error, 'BuildingSync.Helper.help_convert', "Unable to convert from: #{from_unit} to #{to_unit}")
        return nil
      end
    end

    # get attribute value from xml element
    # @param xml_element [REXML::Element]
    # @param attribute_name [String] name of attribute to get the value for
    # @return [String] if attribute
    # @return [nil] if attribute doesnt exist
    def help_get_attribute_value(xml_element, attribute_name)
      if xml_element && !xml_element.attribute(attribute_name).nil?
        return xml_element.attribute(attribute_name).value
      end
      return nil
    end

    # get date value from xml element
    # @param xml_element [REXML::Element]
    # @return [Date] if the text can be parsed as a date
    # @return [nil] if the text cant be parsed as a date
    def help_get_text_value_as_date(xml_element)
      if xml_element && !xml_element.text.nil?
        begin
          return Date.parse(xml_element.text)
        rescue ArgumentError
          return nil
        end
      end
      return nil
    end

    # get date datetime from xml element
    # @param xml_element [REXML::Element]
    # @return [DateTime] if the text can be parsed as a date
    # @return [nil] if the text cant be parsed as a date
    def help_get_text_value_as_datetime(xml_element)
      if xml_element && !xml_element.text.nil?
        begin
          return DateTime.parse(xml_element.text)
        rescue ArgumentError
          return nil
        end
      end
      return nil
    end

    # read xml file document
    # @param xml_file_path [String]
    # @return REXML::Document
    def help_load_doc(xml_file_path)
      doc = nil
      File.open(xml_file_path, 'r') do |file_content|
        doc = REXML::Document.new(file_content, ignore_whitespace_nodes: :all)
      end
      return doc
    end
  end
end
