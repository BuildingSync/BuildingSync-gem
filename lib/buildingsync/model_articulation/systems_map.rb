# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************

module BuildingSyncToOSSystemMaps
    def self.get_hvac_map
        return {
            "Packaged Terminal Air Conditioner" => "PTAC with gas coil",
            "Four Pipe Fan Coil Unit" => "Fan coil chiller with boiler",
            "Packaged Terminal Heat Pump" => "PTHP",
            "Packaged Rooftop Air Conditioner" => "PSZ-AC with gas unit heaters",
            "Packaged Rooftop Heat Pump" => "PSZ-HP",
            "Packaged Rooftop VAV with Hot Water Reheat" => "PVAV with gas boiler reheat",
            "Packaged Rooftop VAV with Electric Reheat" => "PVAV with PFP boxes",
            "VAV with Hot Water Reheat" => "VAV chiller with gas boiler reheat",
            "VAV with Electric Reheat" => "VAV chiller with PFP boxes",
            "Warm Air Furnace" => "Forced air furnace",
            "Ventilation Only" => "",
            "Dedicated Outdoor Air System" => "",
            "Water Loop Heat Pump" => "Water source heat pumps fluid cooler with boiler",
            "Ground Source Heat Pump" => "Water source heat pumps with ground source heat pump",
            "VRF Terminal Unit" => "VRF",
            "Chilled Beam" => "",
            "Other" => ""
        }
    end
end
