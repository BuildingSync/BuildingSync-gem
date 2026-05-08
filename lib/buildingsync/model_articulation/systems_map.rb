# *******************************************************************************
# OpenStudio(R), Copyright (c) Alliance for Energy Innovation, LLC.
# See also https://github.com/BuildingSync/BuildingSync-gem/blob/develop/LICENSE.md
# *******************************************************************************

module BuildingSyncToOSSytemMaps
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

    def self.get_glass_layers_map
        return {
            "Single pane" => "Single",
            "Double pane" => "Double",
            "Triple pane" => "Triple",
            "Single paned with storm panel" => "Single",
        }
    end

    def self.get_glass_type_map
        return {
            "Clear uncoated" => "No LowE - Clear",
            "Low e" => "LowE - Clear",
            "Tinted" => "No LowE - Tinted/Reflective",
            "Tinted plus low e" => "LowE - Tinted/Reflective",
            "Reflective" => "No LowE - Tinted/Reflective",
            "Reflective on tint" => "No LowE - Tinted/Reflective",
            "High performance tint" => "LowE - Tinted/Reflective",
            "Sunbelt low E low SHGC" => "LowE - Tinted/Reflective",
            # "Suspended film" => "",
            # "Plastic" => "",
        }
    end

    def self.get_frame_material_map
        return {
            "Aluminum uncategorized" => "Aluminum",
            "Aluminum no thermal break" => "Aluminum",
            "Aluminum thermal break" => "Thermally Broken Aluminum",
            # "Clad" => "",
            # "Composite" => "",
            # "Fiberglass" => "",
            # "Steel" => "",
            # "Vinyl" => "",
            "Wood" => "Wood",
        }
    end
end
