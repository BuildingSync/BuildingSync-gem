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
require 'builder'
require_relative '../../../lib/buildingsync/generator'

RSpec.describe 'OccupancyTypeSpec' do
  it 'Should generate osm and simulate baseline for all supported occupancy types' do
    run_minimum_facility('Retail', '1954', 'Gross', '69452', ASHRAE90_1)

    run_minimum_facility('Office', '1964', 'Gross', '10000', ASHRAE90_1)
    run_minimum_facility('Office', '1974', 'Gross', '40000', ASHRAE90_1)
    run_minimum_facility('Office', '1984', 'Gross', '80000', ASHRAE90_1)

    run_minimum_facility('StripMall', '1994', 'Gross', '50000', ASHRAE90_1)
    run_minimum_facility('PrimarySchool', '2004', 'Gross', '50000', ASHRAE90_1)
    run_minimum_facility('SecondarySchool', '2014', 'Gross', '50000', ASHRAE90_1)
    run_minimum_facility('Outpatient', '2001', 'Gross', '50000', ASHRAE90_1)
    run_minimum_facility('Hospital', '2002', 'Gross', '50000', ASHRAE90_1)
    run_minimum_facility('SmallHotel', '2003', 'Gross', '50000', ASHRAE90_1)
    run_minimum_facility('LargeHotel', '2005', 'Gross', '50000', ASHRAE90_1)
    run_minimum_facility('QuickServiceRestaurant', '2006', 'Gross', '50000', ASHRAE90_1)
    run_minimum_facility('FullServiceRestaurant', '2007', 'Gross', '50000', ASHRAE90_1)
    run_minimum_facility('MidriseApartment', '2008', 'Gross', '50000', ASHRAE90_1)
    run_minimum_facility('HighriseApartment', '2009', 'Gross', '50000', ASHRAE90_1)
    run_minimum_facility('Warehouse', '2012', 'Gross', '50000', ASHRAE90_1)
    run_minimum_facility('SuperMarket', '2018', 'Gross', '50000', ASHRAE90_1)
  end

  def run_minimum_facility(occupancy_classification, year_of_const, floor_area_type, floor_area_value, standard_to_be_used)
    generator = BuildingSync::Generator.new()
    facility = generator.create_minimum_facility(occupancy_classification,  year_of_const, floor_area_type, floor_area_value)
    facility.determine_open_studio_standard(standard_to_be_used)
    epw_file_path = File.expand_path('../../weather/CZ01RV2.epw', File.dirname(__FILE__))
    output_path = File.expand_path("../../output/#{File.basename(__FILE__, File.extname(__FILE__))}/", File.dirname(__FILE__))
    expect(facility.generate_baseline_osm(epw_file_path, output_path, standard_to_be_used)).to be true
    facility.write_osm(output_path)

    run_baseline_simulation(output_path + '/in.osm', 'CZ01RV2.epw')
  end

  def create_xml_file_object(xml_file_path)
    doc = nil
    File.open(xml_file_path, 'r') do |file|
      doc = REXML::Document.new(file)
    end
    return doc
  end




end
