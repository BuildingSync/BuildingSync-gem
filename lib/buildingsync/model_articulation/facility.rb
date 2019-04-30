require_relative 'site'
module BuildingSync
  class Facility
    # an array that contains all the sites
    @sites = []

    # initialize
    def initialize(facility_xml)
      # code to initialize
      create_site(facility_xml)
    end

    # adding a site to the facility
    def create_site(facility_xml)
      facility_xml.elements.each("/#{@ns}:Sites/#{@ns}:Site") do |site_element|
        puts "#{facility_xml.elements["#{@ns}:Sites/#{@ns}:Site/#{@ns}:Address/#{@ns}:StreetAddressDetail/#{@ns}:Simplified/#{@ns}:StreetAddress"].text} value is correct"
        @sites.push(Site.new(site_element))
      end
    end

    # adding the typical HVAC system to the buildings in all sites of this facility
    def add_typical_HVAC
      # TODO: code to add typical HVAC systems
    end

    # generating the OpenStudio model based on the imported BuildingSync Data
    def generate_baseline_osm
      # this is code refactored from the "create_bar_from_building_type_ratios" measure
      # first we check is there is any data at all in this facility, aka if there is a site in the list
      if @sites.count == 0
        puts 'Error: There are no sites attached to this facility in your BuildingSync file.'
      else
        puts "Info: There is/are #{@sites.count} sites in this facility."
      end
      # TODO: do we have any kind of identifier for facility/site that we can use also in the logging??

      # the original measure reads in potential values from a previous measure, I think we do not need this anymore (maybe the zip code??)

      # TODO: the original measure contains value range checks, should we implement them here or while importing data??
      # Fraction: 'bldg_type_b_fract_bldg_area', 'bldg_type_c_fract_bldg_area', 'bldg_type_d_fract_bldg_area', 'wwr', 'party_wall_fraction' 0 =<= 1
      # Bigger than 0 (excluding 0): 'total_bldg_floor_area' 0 <= nil
      # Bigger than 1 (including 1): 'num_stories_above_grade' 1 =< nil
      # Bigger than 0 (including 0): 'bldg_type_a_num_units', 'bldg_type_c_num_units', 'bldg_type_d_num_units', 'num_stories_below_grade', 'floor_height', 'ns_to_ew_ratio', 'party_wall_stories_north',
      # 'party_wall_stories_south', 'party_wall_stories_east', 'party_wall_stories_west', 'single_floor_area' 0 =<= nil

      # TODO: we have not really defined a good logic what happens with multiple sites, versus multiple buildings, here we just take the first building on the first site
      @sites[0].set_building_form_defaults

      # checking that the factions add up
      @sites.each do |site|
        if site.check_building_faction is false
          return false
        end
      end

      # let's create our new empty model
      model = OpenStudio::Model.new

      building = @sites[0].buildings[0]
      # set building rotation
      initial_rotation = model.getBuilding.northAxis
      if args['building_rotation'] != initial_rotation
        model.getBuilding.setNorthAxis(building.building_rotation)
        puts "INFO: Set Building Rotation to #{model.getBuilding.northAxis}"
      end
      model.getBuilding.setName(building.name)

      building.create_space_types

      # TODO: do we need to do any other unit conversions? should we just convert all of them during xml parsing, is there some unti mechanism in BuildingSync?

      # TODO: continue refactoring from here
      # Make the standard applier
      standard = Standard.build("#{args['template']}_#{args['bldg_type_a']}")

      # calculate length and width of bar
      # todo - update slicing to nicely handle aspect ratio less than 1



      # create envelope
      # populate bar_hash and create envelope with data from envelope_data_hash and user arguments
      bar_hash = {}
      bar_hash[:length] = building.length
      bar_hash[:width] =  building.width
      bar_hash[:num_stories_below_grade] = building.num_stories_below_grade
      bar_hash[:num_stories_above_grade] =  building.num_stories_above_grade
      bar_hash[:floor_height] =  building.floor_height_si
      # bar_hash[:center_of_footprint] = OpenStudio::Point3d.new(length* 0.5,width * 0.5,0.0)
      bar_hash[:center_of_footprint] = OpenStudio::Point3d.new(0, 0, 0)
      bar_hash[:bar_division_method] = 'Multiple Space Types - Individual Stories Sliced'
      # default for now 'Multiple Space Types - Individual Stories Sliced', 'Multiple Space Types - Simple Sliced', 'Single Space Type - Core and Perimeter'
      bar_hash[:make_mid_story_surfaces_adiabatic] = false
      bar_hash[:space_types] = building.space_types_hash
      bar_hash[:building_wwr_n] = building.wwr
      bar_hash[:building_wwr_s] = building.wwr
      bar_hash[:building_wwr_e] = building.wwr
      bar_hash[:building_wwr_w] = building.wwr

      # TODO: implement the party wall logic

      # remove non-resource objects not removed by removing the building
      # remove_non_resource_objects(runner, model)

      # create bar
      create_bar(runner, model, bar_hash, 'Basements Ground Mid Top')
      # using the default value for story multiplier for now 'Basements Ground Mid Top'

      # store expected floor areas to check after bar made
#      target_areas = {}
#      bar_hash[:space_types].each do |k, v|
#        target_areas[k] = v[:floor_area]
#      end

      # check expected floor areas against actual
#      model.getSpaceTypes.sort.each do |space_type|
#        next if !target_areas.key? space_type

        # convert to IP
#        actual_ip = OpenStudio.convert(space_type.floorArea, 'm^2', 'ft^2').get
#        target_ip = OpenStudio.convert(target_areas[space_type], 'm^2', 'ft^2').get

 #       if (space_type.floorArea - target_areas[space_type]).abs >= 1.0

  #        if !args['bar_division_method'].include? 'Single Space Type'
  #          runner.registerError("#{space_type.name} doesn't have the expected floor area (actual #{OpenStudio.toNeatString(actual_ip, 0, true)} ft^2, target #{OpenStudio.toNeatString(target_ip, 0, true)} ft^2)")
  #          return false
  #        else
  #          # will see this if use Single Space type division method on multi-use building or single building type without whole building space type
  #          runner.registerWarning("#{space_type.name} doesn't have the expected floor area (actual #{OpenStudio.toNeatString(actual_ip, 0, true)} ft^2, target #{OpenStudio.toNeatString(target_ip, 0, true)} ft^2)")
  #        end

  #      end
  #    end



      # test for excessive exterior roof area (indication of problem with intersection and or surface matching)
#      ext_roof_area = model.getBuilding.exteriorSurfaceArea - model.getBuilding.exteriorWallArea
#      expected_roof_area = args['total_bldg_floor_area'] / (args['num_stories_above_grade'] + args['num_stories_below_grade']).to_f
#      if ext_roof_area > expected_roof_area && single_floor_area_si == 0.0 # only test if using whole-building area input
#        runner.registerError('Roof area larger than expected, may indicate problem with inter-floor surface intersection or matching.')
#        return false
#      end

      # report final condition of model
      puts "INFO: The building finished with #{model.getSpaces.size} spaces."

      return true
    end
  end
end
