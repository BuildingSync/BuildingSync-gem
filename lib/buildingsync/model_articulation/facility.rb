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

      building.create_space_types

      # TODO: continue refactoring from here
      # Make the standard applier
      standard = Standard.build("#{args['template']}_#{args['bldg_type_a']}")

      # calculate length and width of bar
      # todo - update slicing to nicely handle aspect ratio less than 1

      total_bldg_floor_area_si = OpenStudio.convert(args['total_bldg_floor_area'], 'ft^2', 'm^2').get
      single_floor_area_si = OpenStudio.convert(args['single_floor_area'], 'ft^2', 'm^2').get

      num_stories = args['num_stories_below_grade'] + args['num_stories_above_grade']

      # handle user-assigned single floor plate size condition
      if args['single_floor_area'] > 0.0
        footprint_si = single_floor_area_si
        total_bldg_floor_area_si = single_floor_area_si * num_stories.to_f
        runner.registerWarning('User-defined single floor area was used for calculation of total building floor area')
      else
        footprint_si = total_bldg_floor_area_si / num_stories.to_f
      end
      floor_height_si = OpenStudio.convert(args['floor_height'], 'ft', 'm').get
      width = Math.sqrt(footprint_si / args['ns_to_ew_ratio'])
      length = footprint_si / width

      # populate space_types_hash
      space_types_hash = {}
      building_type_hash.each do |building_type, building_type_hash|
        building_type_hash[:space_types].each do |space_type_name, hash|
          next if hash[:space_type_gen] == false

          space_type = hash[:space_type]
          ratio_of_bldg_total = hash[:ratio] * building_type_hash[:ratio_adjustment_multiplier] * building_type_hash[:frac_bldg_area]
          final_floor_area = ratio_of_bldg_total * total_bldg_floor_area_si # I think I can just pass ratio but passing in area is cleaner
          space_types_hash[space_type] = { floor_area: final_floor_area }
        end
      end

      # create envelope
      # populate bar_hash and create envelope with data from envelope_data_hash and user arguments
      bar_hash = {}
      bar_hash[:length] = length
      bar_hash[:width] = width
      bar_hash[:num_stories_below_grade] = args['num_stories_below_grade']
      bar_hash[:num_stories_above_grade] = args['num_stories_above_grade']
      bar_hash[:floor_height] = floor_height_si
      # bar_hash[:center_of_footprint] = OpenStudio::Point3d.new(length* 0.5,width * 0.5,0.0)
      bar_hash[:center_of_footprint] = OpenStudio::Point3d.new(0, 0, 0)
      bar_hash[:bar_division_method] = args['bar_division_method']
      bar_hash[:make_mid_story_surfaces_adiabatic] = args['make_mid_story_surfaces_adiabatic']
      bar_hash[:space_types] = space_types_hash
      bar_hash[:building_wwr_n] = args['wwr']
      bar_hash[:building_wwr_s] = args['wwr']
      bar_hash[:building_wwr_e] = args['wwr']
      bar_hash[:building_wwr_w] = args['wwr']

      # round up non integer stoires to next integer
      num_stories_round_up = num_stories.ceil

      # party_walls_array to be used by orientation specific or fractional party wall values
      party_walls_array = [] # this is an array of arrays, where each entry is effective building story with array of directions

      if args['party_wall_stories_north'] + args['party_wall_stories_south'] + args['party_wall_stories_east'] + args['party_wall_stories_west'] > 0

        # loop through effective number of stories add orientation specific party walls per user arguments
        num_stories_round_up.times do |i|
          test_value = i + 1 - bar_hash[:num_stories_below_grade]

          array = []
          if args['party_wall_stories_north'] >= test_value
            array << 'north'
          end
          if args['party_wall_stories_south'] >= test_value
            array << 'south'
          end
          if args['party_wall_stories_east'] >= test_value
            array << 'east'
          end
          if args['party_wall_stories_west'] >= test_value
            array << 'west'
          end

          # populate party_wall_array for this story
          party_walls_array << array
        end
      end

      # calculate party walls if using party_wall_fraction method
      if args['party_wall_fraction'] > 0 && !party_walls_array.empty?
        runner.registerWarning('Both orientaiton and fractional party wall values arguments were populated, will ignore fractional party wall input')
      elsif args['party_wall_fraction'] > 0

        # orientation of long and short side of building will vary based on building rotation

        # full story ext wall area
        typical_length_facade_area = length * floor_height_si
        typical_width_facade_area = width * floor_height_si

        # top story ext wall area, may be partial story
        partial_story_multiplier = (1.0 - args['num_stories_above_grade'].ceil + args['num_stories_above_grade'])
        area_multiplier = partial_story_multiplier
        edge_multiplier = Math.sqrt(area_multiplier)
        top_story_length = length * edge_multiplier
        top_story_width = width * edge_multiplier
        top_story_length_facade_area = top_story_length * floor_height_si
        top_story_width_facade_area = top_story_width * floor_height_si

        total_exterior_wall_area = 2 * (length + width) * (args['num_stories_above_grade'].ceil - 1.0) * floor_height_si + 2 * (top_story_length + top_story_width) * floor_height_si
        target_party_wall_area = total_exterior_wall_area * args['party_wall_fraction']

        width_counter = 0
        width_area = 0.0
        facade_area = typical_width_facade_area
        until (width_area + facade_area >= target_party_wall_area) || (width_counter == args['num_stories_above_grade'].ceil * 2)
          # update facade area for top story
          if width_counter == args['num_stories_above_grade'].ceil - 1 || width_counter == args['num_stories_above_grade'].ceil * 2 - 1
            facade_area = top_story_width_facade_area
          else
            facade_area = typical_width_facade_area
          end

          width_counter += 1
          width_area += facade_area

        end
        width_area_remainder = target_party_wall_area - width_area

        length_counter = 0
        length_area = 0.0
        facade_area = typical_length_facade_area
        until (length_area + facade_area >= target_party_wall_area) || (length_counter == args['num_stories_above_grade'].ceil * 2)
          # update facade area for top story
          if length_counter == args['num_stories_above_grade'].ceil - 1 || length_counter == args['num_stories_above_grade'].ceil * 2 - 1
            facade_area = top_story_length_facade_area
          else
            facade_area = typical_length_facade_area
          end

          length_counter += 1
          length_area += facade_area
        end
        length_area_remainder = target_party_wall_area - length_area

        # get rotation and best fit to adjust orientation for fraction party wall
        rotation = args['building_rotation'] % 360.0 # should result in value between 0 and 360
        card_dir_array = [0.0, 90.0, 180.0, 270.0, 360.0]
        # reverse array to properly handle 45, 135, 225, and 315
        best_fit = card_dir_array.reverse.min_by { |x| (x.to_f - rotation).abs }

        if ![90.0, 270.0].include? best_fit
          width_card_dir = ['east', 'west']
          length_card_dir = ['north', 'south']
        else # if rotation is closest to 90 or 270 then reverse which orientation is used for length and width
          width_card_dir = ['north', 'south']
          length_card_dir = ['east', 'west']
        end

        # if dont' find enough on short sides
        if width_area_remainder <= typical_length_facade_area

          num_stories_round_up.times do |i|
            if i + 1 <= args['num_stories_below_grade']
              party_walls_array << []
              next
            end
            if i + 1 - args['num_stories_below_grade'] <= width_counter
              if i + 1 - args['num_stories_below_grade'] <= width_counter - args['num_stories_above_grade']
                party_walls_array << width_card_dir
              else
                party_walls_array << [width_card_dir.first]
              end
            else
              party_walls_array << []
            end
          end

        else # use long sides instead

          num_stories_round_up.times do |i|
            if i + 1 <= args['num_stories_below_grade']
              party_walls_array << []
              next
            end
            if i + 1 - args['num_stories_below_grade'] <= length_counter
              if i + 1 - args['num_stories_below_grade'] <= length_counter - args['num_stories_above_grade']
                party_walls_array << length_card_dir
              else
                party_walls_array << [length_card_dir.first]
              end
            else
              party_walls_array << []
            end
          end

        end

        # TODO: - currently won't go past making two opposing sets of walls party walls. Info and registerValue are after create_bar in measure.rb

      end

      # populate bar hash with story information
      bar_hash[:stories] = {}
      num_stories_round_up.times do |i|
        if party_walls_array.empty?
          party_walls = []
        else
          party_walls = party_walls_array[i]
        end

        # add below_partial_story
        if num_stories.ceil > num_stories && i == num_stories_round_up - 2
          below_partial_story = true
        else
          below_partial_story = false
        end

        # bottom_story_ground_exposed_floor and top_story_exterior_exposed_roof already setup as bool

        bar_hash[:stories]["key #{i}"] = { story_party_walls: party_walls, story_min_multiplier: 1, story_included_in_building_area: true, below_partial_story: below_partial_story, bottom_story_ground_exposed_floor: args['bottom_story_ground_exposed_floor'], top_story_exterior_exposed_roof: args['top_story_exterior_exposed_roof'] }
      end

      # remove non-resource objects not removed by removing the building
      remove_non_resource_objects(runner, model)

      # rename building to infer template in downstream measure
      name_array = [args['template'], args['bldg_type_a']]
      if args['bldg_type_b_fract_bldg_area'] > 0 then name_array << args['bldg_type_b'] end
      if args['bldg_type_c_fract_bldg_area'] > 0 then name_array << args['bldg_type_c'] end
      if args['bldg_type_d_fract_bldg_area'] > 0 then name_array << args['bldg_type_d'] end
      model.getBuilding.setName(name_array.join('|').to_s)

      # store expected floor areas to check after bar made
      target_areas = {}
      bar_hash[:space_types].each do |k, v|
        target_areas[k] = v[:floor_area]
      end

      # create bar
      create_bar(runner, model, bar_hash, args['story_multiplier'])

      # check expected floor areas against actual
      model.getSpaceTypes.sort.each do |space_type|
        next if !target_areas.key? space_type

        # convert to IP
        actual_ip = OpenStudio.convert(space_type.floorArea, 'm^2', 'ft^2').get
        target_ip = OpenStudio.convert(target_areas[space_type], 'm^2', 'ft^2').get

        if (space_type.floorArea - target_areas[space_type]).abs >= 1.0

          if !args['bar_division_method'].include? 'Single Space Type'
            runner.registerError("#{space_type.name} doesn't have the expected floor area (actual #{OpenStudio.toNeatString(actual_ip, 0, true)} ft^2, target #{OpenStudio.toNeatString(target_ip, 0, true)} ft^2)")
            return false
          else
            # will see this if use Single Space type division method on multi-use building or single building type without whole building space type
            runner.registerWarning("#{space_type.name} doesn't have the expected floor area (actual #{OpenStudio.toNeatString(actual_ip, 0, true)} ft^2, target #{OpenStudio.toNeatString(target_ip, 0, true)} ft^2)")
          end

        end
      end

      # check party wall fraction by looping through surfaces.
      actual_ext_wall_area = model.getBuilding.exteriorWallArea
      actual_party_wall_area = 0.0
      model.getSurfaces.each do |surface|
        next if surface.outsideBoundaryCondition != 'Adiabatic'
        next if surface.surfaceType != 'Wall'
        actual_party_wall_area += surface.grossArea * surface.space.get.multiplier
      end
      actual_party_wall_fraction = actual_party_wall_area / (actual_party_wall_area + actual_ext_wall_area)
      runner.registerInfo("Target party wall fraction is #{args['party_wall_fraction']}. Realized fraction is #{actual_party_wall_fraction.round(2)}")
      runner.registerValue('party_wall_fraction_actual', actual_party_wall_fraction)

      # test for excessive exterior roof area (indication of problem with intersection and or surface matching)
      ext_roof_area = model.getBuilding.exteriorSurfaceArea - model.getBuilding.exteriorWallArea
      expected_roof_area = args['total_bldg_floor_area'] / (args['num_stories_above_grade'] + args['num_stories_below_grade']).to_f
      if ext_roof_area > expected_roof_area && single_floor_area_si == 0.0 # only test if using whole-building area input
        runner.registerError('Roof area larger than expected, may indicate problem with inter-floor surface intersection or matching.')
        return false
      end

      # report final condition of model
      runner.registerFinalCondition("The building finished with #{model.getSpaces.size} spaces.")

      return true
    end
  end
end
