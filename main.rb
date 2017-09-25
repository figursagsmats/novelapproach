# Copyright 2016 Trimble Navigation Limited
# Licensed under the MIT license

require 'sketchup.rb'
#SKETCHUP_CONSOLE.clear
puts "LOADED MAIN FYFAN"


require_relative 'src/importer.rb'
require_relative 'src/model_annotator.rb'
require_relative 'src/console_deluxe.rb'
require_relative 'src/helper_classes.rb'
require_relative 'src/figure2d.rb'
class FalseClass; def to_i; 0 end end
class TrueClass; def to_i; 1 end end



module ACG
  module ImportStrykIron
    def self.add_group_and_layer(name,visible)
      model = Sketchup.active_model
      layers = model.layers
      group = model.active_entities.add_group
      # group.name = name
      layer = layers.add(name)
      layer.visible = visible
      group.layer = layer
      return group
    end
    LINE_CONSCENT_THRESH ||= 4.m
    VERTEX_PROXIMITY_THRESH ||= 2.m
    WALL_BIAS_FACTOR ||= 0.8
    XPOINT_DISTANCES_THRESH ||= 2.m
    ATTRACTION_THRESH ||= 2.m
    # This method creates a simple cube inside of a group in the model.
    def self.import_strykiron
      SKETCHUP_CONSOLE.clear
      puts "KOMMIGEN NU PRITT-MARIE! KÖR FÖFA-AN!!!!!"
      #$stdout.sync = true
      model = Sketchup.active_model
      model.start_operation('Import StrykIron', true)
      model.entities.clear!

      bfp_group = add_group_and_layer("Building Foot Print",false)
      orginial_pc_group = add_group_and_layer("Orginial Points",false)
      pc_regions_group = add_group_and_layer("Clustered Points",false)
      feature_group = add_group_and_layer("Features",true)
      feature_labels_group=add_group_and_layer("Feature Labels",true)
      snapped_feature_group = add_group_and_layer("Snapped Features",false)
      bfp_edge_labels_group = add_group_and_layer("BFP edge labels",false)
      wall_edge_group = add_group_and_layer("Feature-Wall intersection edges",false)
      xpoints_group = add_group_and_layer("Intersection Points",true)
      xpoints_labels_group = add_group_and_layer("Intersection Point Labels",true)
      feature_vertex_ids_group =add_group_and_layer("Feature vertices",false)


      bfp_face = Importer::read_bfp_points(bfp_group)
      
      #COMPONENTS
      point_comp_def = model.definitions.add("point");
      point_comp_def.behavior.always_face_camera = true
 
      edgearray = point_comp_def.entities.add_circle(ORIGIN,Geom::Vector3d.new(0,1,0),200.mm ,24)
      edgearray[0].curve.each_edge {|e| e.visible = false}
      newface = point_comp_def.entities.add_face(edgearray)

      
      # xpoint_comp_def = model.definitions.add("Intersect Point");
      # point_comp_def.behavior.always_face_camera = true
      # xpoint_comp_def.entities.add_edge(ORIGIN,Geom::Vector3d.new(0,1,0),200.mm ,24)
      
      #READ DATA
      Importer::read_point_cloud(orginial_pc_group,point_comp_def)

      #Importer::read_point_cloud(orginial_pc_group,point_comp_def)
      Importer::read_points_regions(pc_regions_group,point_comp_def)

      wall_planes = Array.new
      bfp_face.edges.each_with_index do |edge,index|
        up = Geom::Vector3d.new(0,0,1)
        edge_vector = edge.line[1]
        normal = up.cross(edge_vector)
        plane = [edge.vertices[0],normal]
        wall_planes.push(plane)
        
        txt_point = edge.vertices[0].position.offset(edge_vector,(edge.length*0.5))
        txt_point = txt_point.offset(normal, 1.m)
        text = bfp_edge_labels_group.entities.add_text(index.to_s, txt_point)   
      end

      #Features
      features = Importer::read_features(feature_group)
      
      ModelAnnotator::print_feature_ids(features,feature_labels_group)

      ModelAnnotator::print_feature_vertex_ids(features[0],feature_vertex_ids_group)

      #Create Intersection lines and distances to vertices + transformat
      
      fint = FeatureIntersector.new(features,bfp_face)
      fint.initial_calculations()
      fint.balls_to_the_walls(wall_edge_group)
      fint.remove_bogus_xlines()
      fint.calcualte_relevant_xpoints()

      #Plot

      puts "\n======== Feature xline attraction ========"
      #ConsoleDeluxe::print_row(["Fid","Feature Id Pair","Xpoint Triples"],[5,20,50])
      x_offset = 0
      book_keeping = Hash.new
      howmany = 6
      iterations = 3

      for i in 0..howmany
        
        feature_id = i
        feature_face = features[feature_id]
        
        hash_keys_to_get = fint.get_feature_xline_keys(feature_id)
        #TODO: avid calculating same xpoint many times
        count = 0
        puts "========================================="
        puts "Master feature id: #{feature_id}"
        puts "hash keys to get: #{hash_keys_to_get}"
        puts "looping pairs..."
        hash_keys_to_get.each do |feature_id_pair|

          f1 = feature_id_pair[0]
          f2 = feature_id_pair[1]
          if book_keeping.has_key?([f1,f2])
            next  
          end
          book_keeping[[f1,f2]] = true
          book_keeping[[f2,f1]] = true

          
          plot_group = model.active_entities.add_group

          #fig = Figure2d.new(plot_group) #NEW
          

          face_points_1, face_points_2 = fint.get_transformed_feature(f1,f2)
          

          #fig.add_polygon(face_points_1,face_points_2) #NEW

          puts "f1: #{f1}"
          puts "f2: #{f2}"
          #PLOT
          #Draw faces
          face1 = plot_group.entities.add_face(face_points_1)
          face2 = plot_group.entities.add_face(face_points_2)

          #calculate plot area
          xmax = plot_group.bounds.max[0]
          xmin = plot_group.bounds.min[0]
          ymax = plot_group.bounds.max[1]
          ymin = plot_group.bounds.min[1]
          width = plot_group.bounds.width

          xaxis_end = xmax
          if xmin > 0 then
            width = width + xmin
            xmin = 0
          end

          if xmax < 0 then
            width = width -xmax
            xmax = 0
            xaxis_end = xmin
          end
          
          bb_points = [[xmin,ymin,0],[xmax,ymin,0],[xmax,ymax,0],[xmin,ymax,0],[xmin,ymin,0]]
          #plot_group.entities.add_edges(bb_points)
          move_down = Geom::Transformation.new([0, 0, -1.m]) 
          plot_group.entities.transform_entities(move_down,face1) #to avoid z=0 quirk
          plot_group.entities.transform_entities(move_down,face2)

          ModelAnnotator::draw_2d_arrow(Geom::Point3d.new([0,0,0]),Geom::Point3d.new([0,ymax,0]),plot_group) #y-axis
          ModelAnnotator::draw_2d_arrow(Geom::Point3d.new([0,0,0]),Geom::Point3d.new([xaxis_end,0,0]),plot_group) #y-axis


          #Get xpoints for feature pair
          key_set = [f1,f2].to_set
          shared_xpoints = fint.xpoints_deluxe.select {|k,v| key_set.subset?(k)} #select x-points belonging o f1 and f2
         
          vpf_x_points = Array.new() 
          shared_xpoints.each_pair do |key,point|
            new_x_point = point.clone
            new_x_point.z = 0
            new_x_point.transform!(xlines_transformations[[f1,f2]])
            vpf_x_points.push([key.to_a.join.to_i,new_x_point,-1])
            ModelAnnotator::print_xpoint(key,new_x_point,plot_group)
          end
          
          #ConsoleDeluxe::print_row([i,feature_id_pair,shared_xpoints.keys.collect{|x| x.to_a}],[5,20,50])
          where_are_they = Hash.new
          #Get correct pars of the two feature polygons
          if face1.bounds.center.y > face2.bounds.center.y then #Intersection line is aligned with x-axis, therefore boundingbox can be used
            #face1 is north
            puts "feature #{f1} is north"
            new_face_feature_id_1 = f1
            new_face_feature_id_2 = f2
            new_face_points_1, new_face_points_ids_1 = CustomGeomOperations::get_part_of_polygon(face_points_1,"south")
            new_face_points_2, new_face_points_ids_2 = CustomGeomOperations::get_part_of_polygon(face_points_2,"north")

            where_are_they = {"f1" => "north", "f2" => "south"}
          else
            #face2 is north
            puts "feature #{f2} is north"
            new_face_feature_id_1 = f2
            new_face_feature_id_2 = f1
            new_face_points_2, new_face_points_ids_2 = CustomGeomOperations::get_part_of_polygon(face_points_1,"north")
            new_face_points_1, new_face_points_ids_1 = CustomGeomOperations::get_part_of_polygon(face_points_2,"south")

            where_are_they = {"f1" => "south", "f2" => "north"}
          end


          #PRepare attraction graph
          x1 = new_face_points_1.collect{|point| point.x}
          y1 = new_face_points_1.collect{|point| point.y}
          
          x2 = new_face_points_2.collect{|point| point.x}
          y2 = new_face_points_2.collect{|point| point.y}
          
          x_padding = 100.m
          y_padding_north = 200.m
          y_padding_south = -200.m

          x1_padded = [x1.first - x_padding, x1, x1.last + x_padding].flatten
          y1_padded = [y1.first + y_padding_north, y1, y1.last + y_padding_north].flatten

          x2_padded = [x2.first - x_padding, x2, x2.last + x_padding].flatten
          y2_padded = [y2.first + y_padding_south, y2, y2.last + y_padding_south].flatten

          interp_1 = Interpolate::Points.new(Hash[x1_padded.zip(y1_padded)]) #TODO change value outside interval
          interp_2 = Interpolate::Points.new(Hash[x2_padded.zip(y2_padded)])
          interps = [nil,interp_1,interp_2]

          #collect all step data to attraction table (vpf = vertex-point-feature)
          
          vpf1 = new_face_points_ids_1.zip(new_face_points_1,Array.new(new_face_points_ids_1.length){new_face_feature_id_1})
          vpf2 = new_face_points_ids_2.zip(new_face_points_2,Array.new(new_face_points_ids_2.length){new_face_feature_id_2})
           

          vpf = vpf1 + vpf2 + vpf_x_points

          vpf.sort!{|point_and_id_1,point_and_id_2| point_and_id_1[1].x <=> point_and_id_2[1].x }
          vpf.collect!{|a| {"vertex"=>a[0],"point"=>a[1],"feature"=>a[2]}} #Just for notation purposes...
          print_temp = shared_xpoints.keys.collect{|x| x.to_a.join.to_i}



          puts "\n=== Attraction table for #{feature_id_pair[0]} & #{feature_id_pair[1]} === #{print_temp}"
          col_spacings = [5,8,10,15,15,20,15,20,20,20]
          ConsoleDeluxe::print_row(["Id","Fid","Vertex","X-value","Attraction","Attractive?","Type","Zone","Is Zone?"],col_spacings)

          #CREATE ATTRACTION TABLE
          attraction_table = Array.new
          prev_attraction_status = false 
          first_step = true
          zones = Array.new
          is_zone = false
          empty_zone = Zone.new(-1,-1,-1)
          current_zone = empty_zone

          first_xpoint_hit = false
          index = 0

          xpoints_snaps = vpf_x_points.collect{|xpoint| XPointSnap.new(xpoint[0],xpoint[1])}
          vpf.each do |triplet|
            
            #Get the data from triplet
            fid = triplet["feature"]
            vertex = triplet["vertex"]
            x_val = triplet["point"].x

            #Interpolate the y-vals for current x independent of who the x belongs to
            y_val_1 = interp_1.at(x_val) #TODO avoid interpolating existing value
            y_val_2 = interp_2.at(x_val)

            #Calculate attraction and whether it is within the threshhold
            current_attraction = y_val_1-y_val_2
            is_current_step_attractive = current_attraction < ATTRACTION_THRESH #un

            has_attraction_status_changed_since_prev_step = prev_attraction_status != is_current_step_attractive

            #ADD EXTRA STEP
            if !first_step && has_attraction_status_changed_since_prev_step then 

              

              prev_attraction = attraction_table[index-1].attraction
              prev_x = attraction_table[index-1].x_val
              
              # new_x = prev_x+factor*x_diff #x at the break point
              new_x = CustomGeomOperations::linear_interp_x(prev_x,x_val,prev_attraction,current_attraction,ATTRACTION_THRESH)
              is_zone_start = prev_attraction_status == false

              xpoints_snaps.each do |xpoint_snap|
                dist = (xpoint_snap.xpoint.x - new_x).abs
                if(dist < 3.m) then
                  xpoint_snap.add_candidate(index,dist)
                end
                
              end
              if is_zone_start then
                is_zone = true
                
                zones.push(Zone::new(zones.length,index, -1))
                current_zone = zones.last
                new_step_type = StepTypes::ZONE_START
                attraction_table.push(AttractionTableRow.new(index,nil,nil,new_x,ATTRACTION_THRESH,true,new_step_type,current_zone,is_zone))
                ConsoleDeluxe::print_row(attraction_table[-1].make_print_row(),col_spacings)
              else
                new_step_type = StepTypes::ZONE_END
                attraction_table.push(AttractionTableRow.new(index,nil,nil,new_x,ATTRACTION_THRESH,true,new_step_type,current_zone,is_zone))
                ConsoleDeluxe::print_row(attraction_table[-1].make_print_row(),col_spacings)
                
                zones[-1].end_step = index
                current_zone = empty_zone
                is_zone = false
              end
              index = index +1
            end

            if fid == -1 then #ITS AN XPOINT
              step_type = StepTypes::XPOINT
              #fid = "-"
              first_xpoint_hit = true
            else
              step_type = StepTypes::VERTEX
            end

            attraction_table.push(AttractionTableRow.new(index,fid,vertex,x_val,current_attraction,is_current_step_attractive,step_type,current_zone,is_zone))
            ConsoleDeluxe::print_row(attraction_table[-1].make_print_row(),col_spacings)
            first_step = false
            prev_attraction_status = is_current_step_attractive
            index = index +1
          end
          puts "\n"

          selected = []
          xpoints_snaps.each do |xpoint_snap|
            selected.push(xpoint_snap.get_best_candidate())
            candidates = xpoint_snap.get_all_candidate_ids()
            puts "candidates for #{xpoint_snap.xpoint_key}: #{candidates}"
          end

          if selected.size != selected.uniq.size
            puts "AJAJAJAJAJAJAJAJA kandidatkonflikt!!"
          else
            #TODO: remove x-point from global list if no candidates found

          puts "Before snapping:"
          zones.each do |zone|
            puts zone
          end
            
            xpoints_snaps.each do |xpoint_snap|
              bc_id = xpoint_snap.get_best_candidate()
              unless bc_id.nil?
                xpoint_id = attraction_table.select{|row| row.vertex == xpoint_snap.xpoint_key}.collect{|row|row.id}.first
                if(attraction_table[bc_id].step_type == StepTypes::ZONE_END)
                  puts "zone end #{bc_id} snapped to xpoint #{xpoint_snap.xpoint_key}"
                  attraction_table[bc_id].zone.end_step = xpoint_id

                elsif attraction_table[bc_id].step_type == StepTypes::ZONE_START
                  attraction_table[bc_id].zone.start_step = xpoint_id
                  puts "zone start #{bc_id} snapped to xpoint #{xpoint_snap.xpoint_key}" 

                else
                  puts "AJAJAJAJAJAJAJAJA"
                end
              end

            end
          end
          

          puts "After snapping:"
          f1_rejectees = Array.new
          f2_rejectees = Array.new
          zones.each do |zone|
            puts zone

            f1_rejectees = attraction_table.select{ |row| (row.id >= zone.start_step and row.id <= zone.end_step) and row.fid == f1 }.collect{ |row| row.vertex }
            
            
            puts "f1 rejectees: #{f1_rejectees}"

            f2_rejectees = attraction_table.select{ |row| (row.id >= zone.start_step and row.id <= zone.end_step) and row.fid == f2 }.collect{ |row| row.vertex } 
            puts "f2 rejectees: #{f2_rejectees}"

            start_point = Geom::Point3d.new([attraction_table[zone.start_step].x_val,0,0])
            end_point = Geom::Point3d.new([attraction_table[zone.end_step].x_val,0,0])
            points_to_insert = [start_point,end_point]

            #Alex principle
            if (where_are_they["f1"]=="north") then
              points_to_insert_in_f1 = points_to_insert
              points_to_insert_in_f2 = points_to_insert.reverse
            else
              points_to_insert_in_f1 = points_to_insert.reverse
              points_to_insert_in_f2 = points_to_insert
            end

            temp_group = plot_group.entities.add_group

            if (f1_rejectees.empty?) then
              if (f1_rejectees.empty?) then
              insert_point = nil
              row_id = zone.start_step
              while row_id > 0
                if attraction_table[row_id].fid == f1 then
                  insert_point = attraction_table[row_id].vertex
                  break
                end
                row_id = row_id-1
              end
                
              if insert_point.nil?
                puts "AJAJAJA"
              end
              CustomGeomOperations::replace_vertices_on_face_2(face1, points_to_insert_in_f1, insert_point, temp_group)
            end
            else
              CustomGeomOperations::replace_vertices_on_face(face1, f1_rejectees, points_to_insert_in_f1, temp_group)  
            end

            if (f2_rejectees.empty?) then
              if (f2_rejectees.empty?) then
              insert_point = nil
              row_id = zone.start_step
              while row_id > 0
                if attraction_table[row_id].fid == f2 then
                  insert_point = attraction_table[row_id].vertex
                  break
                end
                row_id = row_id-1
              end
                
              if insert_point.nil?
                puts "AJAJAJA"
              end
              CustomGeomOperations::replace_vertices_on_face_2(face2, points_to_insert_in_f2, insert_point, temp_group)
            end
            else
              CustomGeomOperations::replace_vertices_on_face(face2, f2_rejectees, points_to_insert_in_f2, temp_group)
            end

          end

          x_all = (x1+x2).sort
          attraction = Array.new
          
          x_all.each do |x|
            diff = interp_1.at(x)-interp_2.at(x)
            attraction.push(Geom::Point3d.new([x,diff,0]))
            plot_group.entities.add_cpoint(Geom::Point3d.new([x,diff,0]))
          end

          

          #Plot attraction      
          attraction_edges = plot_group.entities.add_edges(attraction)

          face1.edges.each {|e| e.visible = false}
          face2.edges.each {|e| e.visible = false}
          ModelAnnotator::print_feature_ids([face1,face2],plot_group,[f1,f2])
          ModelAnnotator::print_feature_vertex_ids(face1,plot_group)
          ModelAnnotator::print_feature_vertex_ids(face2,plot_group)
          # plot_group.entities.erase_entities([face1,face2])
          #ModelAnnotator::print_cpoint_with_label("start 1",new_face_points_1[0],plot_group)
          #ModelAnnotator::print_cpoint_with_label("start 2",new_face_points_2[0],plot_group)

          face3 = plot_group.entities.add_face(new_face_points_1)
          face3.edges.each {|e| e.visible = false}
          # face3.reverse!
          face3.material = Sketchup::Color.new(255, 0, 0)
          face3.material.alpha = 0.5
          #face3.visible = false
          #ModelAnnotator::print_feature_vertex_ids(face3,plot_group)
          
          
          
          face4 = plot_group.entities.add_face(new_face_points_2)
          face4.edges.each {|e| e.visible = false}
          #face4.reverse!
          face4.material = Sketchup::Color.new(0, 0, 255)
          face4.material.alpha = 0.5
          #face4.visible = false
          #ModelAnnotator::print_feature_vertex_ids(face4,plot_group)

          move_down = Geom::Transformation.new([0, 0, -0.9.m]) 
          plot_group.entities.transform_entities(move_down,face3) #to avoid z=0 quirk
          plot_group.entities.transform_entities(move_down,face4)
          
          
          #Plot Legend
          # trans = Geom::Transformation.new(Geom::Point3d.new(0,face1.bounds.height,0))
          # temp_group = plot_group.entities.add_group
          # text = "Feature " +f1.to_s  + "& " +f2.to_s
          # temp_group.entities.add_3d_text(text, TextAlignCenter, "Arial", true, false, 0.5.m, 0.0, 0.5, true, 0)
          # temp_group.transform!(trans)
          plot_group.transform!([x_offset-xmin,0,0])
          x_offset = x_offset+width+3.m
          count = count +1
          puts "\n"
          #morph f1 and f2 so they are snapped according to attraction zones


        end
      end


      
      

      #INTERSECTION POINT GENTLEMENS AGREEMENT
      puts "\n==== Map vertices to intersection points ===="
      temp_group = model.active_entities.add_group
      ConsoleDeluxe::print_row(["Fid","Point Id","Vertex idx (sorted)","Distances(sorted)","Type"],[5,10,30,30,20])
      for i in 0..0
        
        all_xpoints_current_feature = xpoints[i] + xpoints_walls[i].to_a
        
        all_xpoints_current_feature = xpoints_deluxe.select {|k,v| [i].to_set.subset?(k)}
        all_xpoints_current_feature.each_pair do |key,point|

          ModelAnnotator::print_xpoint(key,point,temp_group)
          #xpoints_group.entities.add_cpoint(point)
        end
        all_xpoints_current_feature = all_xpoints_current_feature.values
        feature_xpoint_vertex_distances = Array.new(all_xpoints_current_feature.length){Array.new}

        all_xpoints_current_feature.each_with_index do |point,point_idx|
          features[i].vertices.each_with_index do |vertex,vertex_idx|
            feature_xpoint_vertex_distances[point_idx].push ([vertex.position.distance(point),vertex_idx])
          end

          feature_xpoint_vertex_distances[point_idx].sort! { |x,y| y[0] <=> x[0] }.reverse!
          #feature_xpoint_vertex_distances[point_idx].reject!{|pair| pair[0] > 2.m}
        end

        #assing vertices to points
        for j in 1..feature_xpoint_vertex_distances.length-1
          ix_type = "normal"
          if j > xpoints[i].length then
            ix_type = "wall"
          end
          
          ids = feature_xpoint_vertex_distances[j].collect{|pair| pair[1]}
          dists = feature_xpoint_vertex_distances[j].collect{|pair| pair[0].to_mm.round}

         ConsoleDeluxe::print_row([i,j,ids[0..2],dists[0..2],ix_type],[5,10,30,30,20])
        end
        
      end
      
      #VISUAL DEBUG
      feature_to_debug = 0


      # do some shit with features
      for i in 0..0
        feature_id = i
        puts "==== Feature ID: #{feature_id} ====="
        feature_face = features[feature_id]
        hash_keys_to_get = (0..iterations).reject{|x| x == feature_id}.to_a.product([feature_id]) #get whole row except self
        puts "keys: #{hash_keys_to_get}"
        feature_intersections_lines = hash_keys_to_get.collect { |index| xlines[index] }.reject{|x| x.nil?}


        feature_intersections_lines.each {|line| model.entities.add_cline(line[0],line[1])}
        new_points = Array.new
        feature_face.vertices.each do |vertex|
          
          distances = feature_intersections_lines.map {|line| vertex.position.distance_to_line(line)}

          ewim = distances.each_with_index.min
          min_dist = ewim[0]
          min_dist_line_id = ewim[1]
          
          if min_dist < 5.m then
            new_point = vertex.position.project_to_line(feature_intersections_lines[min_dist_line_id])
            new_points.push(new_point)
          else
            new_points.push(vertex.position)
          end   
        end

        #face = snapped_feature_group.entities.add_face(new_points)
        #face.material = Sketchup::Color.new(255, 0, 0)
      end
      model.commit_operation
    end



    # Here we add a menu item for the extension. Note that we again use a
    # load guard to prevent multiple menu items from accidentally being
    # created.
    unless file_loaded?(__FILE__)
      puts "#{__FILE__} loaded for first time."

      # $LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/interp"))
      # require 'interpolate.rb'
      # $LOAD_PATH.shift()

      #==== REQUIRE THIRD PARTY SCRIPTS ===
      #The following code requires all scripts in sub-directories to the specified folder
      vendor_dir = 'vendor'
      individual_vendor_dirs = Dir[File.join(File.dirname(__FILE__),vendor_dir,'*')]
      puts "\nRequireing vendor scripts: "
      for dir in individual_vendor_dirs
        $LOAD_PATH.unshift(dir)
        Dir[File.join(dir,'*.rb')].each do |file|
          require file
          puts "required: #{file}"
        end 
        $LOAD_PATH.shift()
      end
      #=====================================


      menu = UI.menu('Plugins')
      # We fetch a reference to the top level menu we want to add to. Note that
      # we use "Plugins" here which was the old name of the "Extensions" menu.
      # By using "Plugins" you remain backwards compatible.

      # We add the menu item directly to the root of the menu in this example.
      # But if you plan to add multiple items per extension we recommend you
      # group them into a sub-menu in order to keep things organized.
      menu.add_item('Import StrykIron 2') {
        self.import_strykiron
      }

      file_loaded(__FILE__)
    end

  end # module HelloCube
end # module Examples