# frozen_string_literal: true

# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************
require 'builder'
require 'buildingsync/generator'

require_relative './../../spec_helper'

RSpec.describe 'OccupancyTypeSpec' do
  it 'Should generate osm and simulate baseline for OccupancyType: Retail' do
    run_minimum_facility('Retail', '1954', 'Gross', '69452', ASHRAE90_1, 'occupancy_types_spec')
  end

  it 'Should generate osm and simulate baseline for OccupancyType: Office' do
    run_minimum_facility('Office', '1964', 'Gross', '10000', ASHRAE90_1, 'occupancy_types_spec')
    run_minimum_facility('Office', '1974', 'Gross', '40000', ASHRAE90_1, 'occupancy_types_spec')
    run_minimum_facility('Office', '1984', 'Gross', '80000', ASHRAE90_1, 'occupancy_types_spec')
  end

  it 'Should generate osm and simulate baseline for OccupancyType: StripMall' do
    run_minimum_facility('StripMall', '1994', 'Gross', '50000', ASHRAE90_1, 'occupancy_types_spec')
  end

  it 'Should generate osm and simulate baseline for OccupancyType: PrimarySchool' do
    run_minimum_facility('Education-Primary', '2004', 'Gross', '50000', ASHRAE90_1, 'occupancy_types_spec')
  end

  it 'Should generate osm and simulate baseline for OccupancyType: SecondarySchool' do
    run_minimum_facility('Education-Secondary', '2014', 'Gross', '50000', ASHRAE90_1, 'occupancy_types_spec')
  end

  it 'Should generate osm and simulate baseline for OccupancyType: Outpatient' do
    run_minimum_facility('Health care-Outpatient facility', '2001', 'Gross', '50000', ASHRAE90_1, 'occupancy_types_spec')
  end

  # skip for now - currently failing
  xit 'Should generate osm and simulate baseline for OccupancyType: SmallHotel' do
    run_minimum_facility('Lodging', '2003', 'Gross', '20000', ASHRAE90_1, 'occupancy_types_spec')
  end

  it 'Should generate osm and simulate baseline for OccupancyType: LargeHotel' do
    run_minimum_facility('Lodging', '2005', 'Gross', '60000', ASHRAE90_1, 'occupancy_types_spec')
  end

  it 'Should generate osm and simulate baseline for OccupancyType: QuickServiceRestaurant' do
    run_minimum_facility('Food service-Fast', '2006', 'Gross', '50000', ASHRAE90_1, 'occupancy_types_spec')
  end

  it 'Should generate osm and simulate baseline for OccupancyType: FullServiceRestaurant' do
    run_minimum_facility('Food service-Full', '2007', 'Gross', '50000', ASHRAE90_1, 'occupancy_types_spec')
  end

  it 'Should generate osm and simulate baseline for OccupancyType: MidriseApartment' do
    run_minimum_facility('Multifamily', '2008', 'Gross', '50000', ASHRAE90_1, 'occupancy_types_spec', 3)
  end

  it 'Should generate osm and simulate baseline for OccupancyType: HighriseApartment' do
    run_minimum_facility('Multifamily', '2009', 'Gross', '50000', ASHRAE90_1, 'occupancy_types_spec', 15)
  end

  it 'Should generate osm and simulate baseline for OccupancyType: Warehouse' do
    run_minimum_facility('Warehouse', '2012', 'Gross', '50000', ASHRAE90_1, 'occupancy_types_spec')
  end

  it 'Should generate osm and simulate baseline for OccupancyType: SuperMarket' do
    run_minimum_facility('Food sales-Grocery store', '2018', 'Gross', '50000', ASHRAE90_1, 'occupancy_types_spec')
  end
end
