# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************
require 'builder/xmlmarkup'
require 'rexml/element'

RSpec.describe 'BuildingSync::Helper' do
  # help_get_text_value
  it 'help_get_text_value returns the text value of an an REXML::Element if text exists' do
    # --Setup
    el = REXML::Element.new('a')
    to_add = 'This is text'
    el.add_text(to_add)
    received = help_get_text_value(el)

    # -- Assert
    expect(to_add == received).to be true
  end

  it 'help_get_text_value returns nil for an REXML::Element if text doesnt exists' do
    # --Setup
    el = REXML::Element.new('a')
    received = help_get_text_value(el)
    expect(received.nil?).to be true
  end

  it 'help_get_text_value returns nil for an REXML::Element if it has child elements' do
    # --Setup
    el = REXML::Element.new('a')
    el.add_element(REXML::Element.new('b'))
    received = help_get_text_value(el)

    # -- Assert
    expect(received.nil?).to be true
  end

  # get_attribute_value
  it 'get_attribute_value returns the attribute value of an an REXML::Element if the attribute exists' do
    # --Setup
    el = REXML::Element.new('a')
    attr = 'ID'
    attr_value = 'ID1'
    el.add_attribute(attr, attr_value)
    received = help_get_attribute_value(el, attr)

    # -- Assert
    expect(attr_value == received).to be true
  end

  it 'get_attribute_value returns nil for an REXML::Element if the attribute doesnt exist' do
    # --Setup
    el = REXML::Element.new('a')
    attr = 'ID'
    received = help_get_attribute_value(el, attr)

    # -- Assert
    expect(received.nil?).to be true
  end

  # help_get_date_value
  it 'help_get_date_value returns a Date object if the text can be parsed' do
    # --Setup
    el = REXML::Element.new('a')
    date_text = '2020-01-01'
    el.add_text(date_text)
    received = help_get_text_value_as_date(el)

    # -- Assert
    expect(received).to be_an_instance_of(Date)
    expect(received.to_s == date_text).to be true
  end

  it 'help_get_date_value returns nil if the text cant be parsed' do
    # --Setup
    el = REXML::Element.new('a')
    date_text = 'stuff'
    el.add_text(date_text)
    received = help_get_text_value_as_date(el)

    # -- Assert
    expect(received.nil?).to be true
  end

  it 'help_get_date_value returns nil if the REXML::Element has children' do
    # --Setup
    el = REXML::Element.new('a')
    el.add_element(REXML::Element.new('b'))
    received = help_get_text_value_as_date(el)

    # -- Assert
    expect(received.nil?).to be true
  end
end

RSpec.describe 'BuildingSync::Helper convert' do
  to_test = [
    [1000, 'Btu', 'kBtu', 1],
    [1000000, 'Btu', 'MMBtu', 1],
    [0.001, 'kBtu', 'Btu', 1],
    [1000, 'kBtu', 'MMBtu', 1],
    [0.000001, 'MMBtu', 'Btu', 1],
    [0.001, 'MMBtu', 'kBtu', 1]
  ]
  to_test.each do |test|
    # 1000 Btu should equal 1 kBtu, etc.
    it "#{test[0]} #{test[1]} should equal #{test[3]} #{test[2]}" do
      output = help_convert(test[0], test[1], test[2])
      expect(test[3]).to be_within(0.01).of(output)
    end
  end
end
