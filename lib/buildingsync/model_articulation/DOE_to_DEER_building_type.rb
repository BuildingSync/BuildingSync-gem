# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************

module DoeToDeerBuildingTypeMap
    def self.get_building_type_map
        return {
          "SecondarySchool" => "ESe",
          "PrimarySchool" => "Epr",
          "SmallOffice" => "OfS",
          "MediumOffice" => "OfL",
          "LargeOffice" => "OfL",
          "SmallHotel" => "Mtl",
          "LargeHotel" => "Htl",
          "Warehouse" => "SUn",
          "RetailStandalone" => "RtL",
          "RetailStripmall" => "RtS",
          "QuickServiceRestaurant" => "RFF",
          "FullServiceRestaurant" => "RSD",
          "MidriseApartment" => "MFm",
          "HighriseApartment" => "OfL",
          "Hospital" => "Hsp",
          "Outpatient" => "OfL",
          "SuperMarket" => "Gro"
        }
    end
end
