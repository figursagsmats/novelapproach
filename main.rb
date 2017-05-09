# Copyright 2016 Trimble Navigation Limited
# Licensed under the MIT license

require 'sketchup.rb'
puts "Path: #{File.expand_path("")}"
puts "Dir of file: #{File.dirname(__FILE__)}"
puts "LOAD_PATH: #{$LOAD_PATH}"
$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/interp"))
puts "LOAD_PATH: #{$LOAD_PATH}"
require_relative 'interp/interpolate.rb'

module ACG
  module ImportStrykIron
    @@distinguishable_colors = Array.new
    @@distinguishable_colors.push(Sketchup::Color.new(240,163,255))	#F0A3FF	 	Amethyst
    @@distinguishable_colors.push(Sketchup::Color.new(0,117,220))	#0075DC	 	Blue
    @@distinguishable_colors.push(Sketchup::Color.new(153,63,0))	#993F00	 	Caramel
    @@distinguishable_colors.push(Sketchup::Color.new(76,0,92))	#4C005C	 	Damson
    @@distinguishable_colors.push(Sketchup::Color.new(25,25,25))	#191919	 	Ebony
    @@distinguishable_colors.push(Sketchup::Color.new(0,92,49))	#005C31	 	Forest
    @@distinguishable_colors.push(Sketchup::Color.new(43,206,72))	#2BCE48	 	Green
    @@distinguishable_colors.push(Sketchup::Color.new(255,204,153))	#FFCC99	 	Honeydew
    @@distinguishable_colors.push(Sketchup::Color.new(128,128,128))	#808080	 	Iron
    @@distinguishable_colors.push(Sketchup::Color.new(148,255,181))	#94FFB5	 	Jade
    @@distinguishable_colors.push(Sketchup::Color.new(143,124,0))	#8F7C00	 	Khaki
    @@distinguishable_colors.push(Sketchup::Color.new(157,204,0))	#9DCC00	 	Lime
    @@distinguishable_colors.push(Sketchup::Color.new(194,0,136))	#C20088	 	Mallow
    @@distinguishable_colors.push(Sketchup::Color.new(0,51,128))	#003380	 	Navy
    @@distinguishable_colors.push(Sketchup::Color.new(255,164,5))	#FFA405	 	Orpiment
    @@distinguishable_colors.push(Sketchup::Color.new(255,168,187))	#FFA8BB	 	Pink
    @@distinguishable_colors.push(Sketchup::Color.new(66,102,0))	#426600	 	Quagmire
    @@distinguishable_colors.push(Sketchup::Color.new(255,0,16))	#FF0010	 	Red
    @@distinguishable_colors.push(Sketchup::Color.new(94,241,242))	#5EF1F2	 	Sky
    @@distinguishable_colors.push(Sketchup::Color.new(0,153,143))	#00998F	 	Turquoise
    @@distinguishable_colors.push(Sketchup::Color.new(224,255,102))	#E0FF66	 	Uranium
    @@distinguishable_colors.push(Sketchup::Color.new(116,10,255))	#740AFF	 	Violet
    @@distinguishable_colors.push(Sketchup::Color.new(153,0,0))	#990000	 	Wine
    @@distinguishable_colors.push(Sketchup::Color.new(255,255,128))	#FFFF80	 	Xanthin
    @@distinguishable_colors.push(Sketchup::Color.new(255,255,0))	#FFFF00	 	Yellow
    @@distinguishable_colors.push(Sketchup::Color.new(255,80,5)) #FF5005 Zinnia

    LINE_CONSCENT_THRESH = 4.m
    VERTEX_PROXIMITY_THRESH = 2.m
    WALL_BIAS_FACTOR = 0.8
    XPOINT_DISTANCES_THRESH = 2.m
    ATTRACTION_THRESH = 2.m
    # This method creates a simple cube inside of a group in the model.
    def self.import_strykiron
      #$stdout.sync = true
      SKETCHUP_CONSOLE.clear
      model = Sketchup.active_model
      model.start_operation('Import StrykIron', true)

      #GROUPS
      bfp_group = model.active_entities.add_group
      orginial_pc_group = model.active_entities.add_group
      pc_regions_group = model.active_entities.add_group
      feature_group = model.active_entities.add_group
      feature_labels_group=model.entities.add_group
      snapped_feature_group = model.active_entities.add_group
      bfp_edge_labels_group = model.active_entities.add_group
      wall_edge_group = model.active_entities.add_group
      xpoints_group = model.active_entities.add_group
      xpoints_labels_group = model.active_entities.add_group
      feature_vertex_ids_group = model.active_entities.add_group
      plot_group = model.active_entities.add_group

      #LAYERS
      layers = model.layers

      original_points_layer = layers.add("Orginial Points")
      clustered_points_layer = layers.add("Clustered Points")
      feature_layer = layers.add("Features")
      feature_labels_layer = layers.add("Feature Labels")
      snapped_feature_layer = layers.add("Snapped Features")
      wall_edge_layer = layers.add("Feature-Wall intersection edges")
      xpoints_layer = layers.add("Intersection Points")
      xpoints_labels_layer = layers.add("Intersection Point Labels")

      original_points_layer.visible = false
      clustered_points_layer.visible = false
      feature_layer.visible = true
      feature_labels_layer.visible = true
      snapped_feature_layer.visible = true
      wall_edge_layer.visible = false

      orginial_pc_group.layer = original_points_layer
      pc_regions_group.layer = clustered_points_layer
      feature_group.layer = feature_layer
      feature_labels_group.layer = feature_labels_layer
      snapped_feature_group.layer = snapped_feature_layer
      wall_edge_group.layer = wall_edge_layer
      xpoints_group.layer = xpoints_layer

      bfp_face = read_bfp_points(bfp_group)
      
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
      read_point_cloud(orginial_pc_group,point_comp_def)
      read_points_regions(pc_regions_group,point_comp_def)

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
      features = read_features(feature_group)
      
      prin_feature_ids(features,feature_labels_group)

      print_feature_vertex_ids(features[0],feature_vertex_ids_group)

      #Create Intersection lines and distances to vertices
      xlines= Hash.new
      xlines_dists = Hash.new
      xlines_projs = Hash.new
      xlines_ts = Hash.new
      xlines_proximity_between_ft_vertices = Hash.new
      xlines_transformed_points = Hash.new
      xlines_transformations = Hash.new
      iterations = features.length-1
      for i in 0..iterations
        for j in 0..iterations
          unless i == j || xlines.has_key?([i,j]) then #no neeed for i-j if j-i exists
           

            line = Geom.intersect_plane_plane(features[i].plane, features[j].plane)
            xlines[[i,j]] = line
            xlines[[j,i]] = line

            #Transformation
            xaxis = line[1].clone.normalize
            origo = line[0].clone
            xaxis.z = 0
            origo.z = 0

            yaxis = xaxis*Geom::Vector3d.new(0,0,1)
            
            trans = Geom::Transformation.new(origo, xaxis, yaxis)
            trans.invert!
            xlines_transformations[[i,j]] = trans
            xlines_transformations[[j,i]] = trans

            #First feature closest vertex to xline
            distances_i = Array.new
            proj_points_i = Array.new
            ts_i= Array.new
            transformed_points_i = Array.new
            features[i].vertices.each do |vertex|
              distances_i.push(vertex.position.distance_to_line(line))
              proj_points_i.push(vertex.position.project_to_line(line))
              ts_i.push(where_on_line(vertex.position,line))
              p = vertex.position.transform(trans)
              p.z = 0
              transformed_points_i.push(p)
            end

            xlines_dists[[i,j]] = distances_i
            xlines_projs[[i,j]] = proj_points_i
            xlines_ts[[i,j]] = ts_i
            xlines_transformed_points[[i,j]] = transformed_points_i
            
            #Second Feature closest vertex to xline
            distances_j = Array.new
            proj_points_j = Array.new
            ts_j= Array.new
            transformed_points_j = Array.new
            features[j].vertices.each do |vertex|
              distances_j.push(vertex.position.distance_to_line(line))     
              proj_points_j.push(vertex.position.project_to_line(line))
              ts_j.push(where_on_line(vertex.position,line))
              p = vertex.position.transform(trans)
              p.z = 0
              transformed_points_j.push(p)
            end

            xlines_dists[[j,i]] = distances_j
            xlines_projs[[j,i]] = proj_points_j
            xlines_ts[[j,i]] = ts_j
            xlines_transformed_points[[j,i]] = transformed_points_j

            #Vertex proximity
            temp_hash = Hash.new
            edge_dists = Array.new
            features[i].vertices.each_with_index do |first_vertex,k|
              features[j].vertices.each_with_index do |second_vertex,l|
                unless temp_hash.has_key?([[l,k]]) then
                  temp_hash[[k,l]] = true
                  temp_hash[[l,k]] = true
                  edge_dists.push(first_vertex.position.distance(second_vertex))
                  
                end
              end
            end
            min_edge_dist = edge_dists.min
            xlines_proximity_between_ft_vertices[[j,i]] = min_edge_dist
            xlines_proximity_between_ft_vertices[[i,j]] = min_edge_dist

          end      
        end
      end

      
      #BALLS TO THE WALLS
      
      #find wall-featureplane intersections that are close enough
      puts "\n==== BALLS TO THE WALLS ===="
      print_row(["Fid","BFP-edge","Min dist","Status"])
      xlines_walls = Hash.new
      xpoints_walls = Array.new(features.length){Set.new}
      for i in 0..iterations
        plane = features[i].plane
        edge_idx = 0
        for edge in bfp_face.edges
          line_1 = [edge.start.position,Geom::Vector3d.new(0,0,1)]
          line_2 = [edge.end.position,Geom::Vector3d.new(0,0,1)]
          #model.entities.add_cline(line_1[0],line_1[1])
          x1 = Geom.intersect_line_plane(line_1,plane)
          x2 = Geom.intersect_line_plane(line_2,plane)

          new_edge = wall_edge_group.entities.add_edges(x1,x2)[0]
          distances =  Array.new
          for vertex in features[i].vertices
            distances.push(point_to_edge_distance(vertex.position,new_edge))
          end
          min_dist = distances.min
          if min_dist > 2.m
            status = "FIMPAD"
            new_edge.erase!
          else
            status = "ok"
            xpoints_walls[i].add(x1)
            xpoints_walls[i].add(x2)
          end
          print_row([i,edge_idx,min_dist,status])
          
          edge_idx = edge_idx+1
        end
      end
    

      # VASK O FIMP
      puts "\n==== Determine which intersection lines to vask ===="
      print_row(["ID","Closest Vertex","Vertex Proximity","Status"])
      for i in 0..iterations
        f1 = features[i] 
        for j in 0..iterations
          unless i == j  then
            id = i.to_s + "-" + j.to_s
            closest_vertex_to_line_dist,min_id_i = xlines_dists[[i,j]].each_with_index.min
            vertex_proximity = xlines_proximity_between_ft_vertices[[i,j]]           

            if closest_vertex_to_line_dist > LINE_CONSCENT_THRESH || vertex_proximity > VERTEX_PROXIMITY_THRESH
              status = "FIMPAD!"
              xlines[[i,j]] = nil
            else
              status = "ok"
            end
            print_row([id,closest_vertex_to_line_dist.to_mm.floor,vertex_proximity,status])
            
          end      
        end
      end

      #Intersection points
      xpoints = Array.new(features.length){Array.new}
      xpoints_deluxe = Hash.new
      #xpoint_id = 0
      puts "\n==== Find intersection points ===="
      print_row(["Fid","Features X","Keyz","Feature dists (m)","Sum","Status"],[5,15,20,30,20,30])
      for i in 0..iterations
        
        feature_id = i
        feature_face = features[feature_id]
        hash_keys_to_get = (0..iterations).reject{|x| x == feature_id}.to_a.product([feature_id]) #get whole row except self
        hash_keys_to_get = hash_keys_to_get.reject{|pair| xlines[pair].nil?} # remove pair with non-existing line
        
        #TODO: avid calculating same xpoint many times
        hash_keys_to_get.combination(2).each do |keyz|
          point = Geom.intersect_line_line(xlines[keyz[0]], xlines[keyz[1]])

          point_identity = keyz.flatten.uniq
          xpoint_dists_to_creators = Array.new
          for fid in point_identity do
            dists = Array.new
            features[fid].edges.each do |edge|
              dists.push(point_to_edge_distance(point, edge))
            end
            xpoint_dists_to_creators.push(dists)
          end

          xpoint_dists_to_creators_min = xpoint_dists_to_creators.collect{|x|  x.min}
          xpoint_dists_to_creators_min_sum = xpoint_dists_to_creators_min.inject(0){|sum,x| sum + x }
          
          #vask = xpoint_dists_to_creators_min.any?{|min_dist| min_dist>XPOINT_DISTANCES_THRESH} 
          vask = xpoint_dists_to_creators_min_sum > 16.m #TODO: option for sum vs individual

          if vask then 
            status = "FIMPAD!"
          else
            status = "ok"  
          end
          
          
          xpoint_dists_to_creators_min_print = xpoint_dists_to_creators_min.collect{|x|  x.to_m.round(2)}
          xpoints_deluxe[point_identity.to_set] = point #TODO: make hash that can lookup point from 2 features rather than 3

          print_row([feature_id,point_identity,keyz,xpoint_dists_to_creators_min_print,xpoint_dists_to_creators_min_sum.to_m.round(2),status],[5,15,20,30,20,30])
          unless vask then
            xpoints[i].push(point)
          end
          
          #xpoints_group.entities.add_cpoint(point)
          #xpoint_id = xpoint_id+1
        end
      end
      
      #Plot
      puts "\n==== Plot attraction graphs ===="
      print_row(["Fid","Feature Id Pair","Xpoint Triples"],[5,20,50])
      for i in 0..0
        
        feature_id = i
        feature_face = features[feature_id]
        hash_keys_to_get = (0..iterations).reject{|x| x == feature_id}.to_a.product([feature_id]) #get whole row except self
        hash_keys_to_get = hash_keys_to_get.reject{|pair| xlines[pair].nil?} # remove pair with non-existing line
        #TODO: avid calculating same xpoint many times
        count = 0
        hash_keys_to_get.each do |feature_id_pair|
          if count >= 1 then 
            break
          end
          f1 = feature_id_pair[0]
          f2 = feature_id_pair[1]
          face_points_1 = xlines_transformed_points[[f1,f2]]
          face_points_2 = xlines_transformed_points[[f2,f1]]
          face1 = plot_group.entities.add_face(face_points_1)
          face2 = plot_group.entities.add_face(face_points_2)

          #Get xpoints for feature pair
          key_set = [f1,f2].to_set
          xpoint_keys = xpoints_deluxe.select {|k,v| key_set.subset?(k)}
          shared_xpoints = Array.new
          xpoint_keys.each_pair do |key,point|
            new_x_point = point.clone
            new_x_point.z = 0
            new_x_point.transform!(xlines_transformations[[f1,f2]])
            shared_xpoints.push(new_x_point)
            print_xpoint(key,new_x_point,plot_group)
          end
          
          print_row([i,feature_id_pair,xpoint_keys.keys.collect{|x| x.to_a}],[5,20,50])

          #Get correct pars of the two feature polygons
          if face1.bounds.center.y > face2.bounds.center.y then #Intersection line is aligned with x-axis, therefore boundingbox can be used
            #face1 is north
            new_face_points_1, new_face_points_ids_1 = get_part_of_polygon(face_points_1,"south")
            new_face_points_2, new_face_points_ids_2 = get_part_of_polygon(face_points_2,"north")
          else
            #face2 is north
            new_face_points_1, new_face_points_ids_1 = get_part_of_polygon(face_points_1,"north")
            new_face_points_2, new_face_points_ids_2 = get_part_of_polygon(face_points_2,"south")
          end


          #PRepare attraction graph
          x1 = new_face_points_1.collect{|point| point.x}
          y1 = new_face_points_1.collect{|point| point.y}
          
          x2 = new_face_points_2.collect{|point| point.x}
          y2 = new_face_points_2.collect{|point| point.y}

          interp_1 = Interpolate::Points.new(Hash[x1.zip(y1)])
          interp_2 = Interpolate::Points.new(Hash[x2.zip(y2)])
          interps = [nil,interp_1,interp_2]
          #New stuff
          vpf1 = new_face_points_ids_1.zip(new_face_points_1,Array.new(new_face_points_ids_1.length){1})
          vpf2 = new_face_points_ids_2.zip(new_face_points_2,Array.new(new_face_points_ids_2.length){2})
          vpf = vpf1 + vpf2 

          vpf.sort!{|point_and_id_1,point_and_id_2| point_and_id_1[1].x <=> point_and_id_2[1].x }
          vpf.collect!{|a| {"vertex"=>a[0],"point"=>a[1],"feature"=>a[2]}} #Just for notation purposes...

          #shared_xpoints.sort!{|p1,p2| p1.x <=> p2.x }
          puts "\n==== Attraction Table ===="
          print_row(["Fid","Vertex","X-value","Attraction","Type"])
          fids = Array.new
          vertex_ids = Array.new
          x_vals = Array.new
          attraction_vals = Array.new
          step_types = Array.new
          
          attraction_points = Array.new
          

          prev_step_status = false
          virgin = true
          vpf.each_with_index do |triplet,index|
            fid = triplet["feature"]
            vertex = triplet["vertex"]
            x_val = triplet["point"].x
            step_type = "v"
            y_val_1 = interp_1.at(x_val)
            y_val_2 = interp_2.at(x_val)

            current_attraction = y_val_1-y_val_2
            current_step_status = current_attraction < ATTRACTION_THRESH


            if !virgin && (prev_step_status != current_step_status) #Inte f
              prev_attraction = attraction_vals[index-1]
              prev_x = x_vals[index-1]

              #Linear interpolation TODO: check if retarded
              adiff = (current_attraction-prev_attraction).abs #difference in attraction
              factor = 1-ATTRACTION_THRESH/adiff
              x_diff = x_val-prev_x
              new_x = prev_x+factor*x_diff #x at the break point
              new_step_type = prev_step_status == false ? "Zone START" : "Zone END"

              #NEW STEP
              fids.push(nil)
              vertex_ids.push(nil)
              x_vals.push(new_x)
              attraction_vals.push(ATTRACTION_THRESH)
              step_types.push(new_step_type)

              
              print_row(["-","-",new_x.to_m.round(2),ATTRACTION_THRESH.to_m.round(2),new_step_type])
            end
            
            fids.push(fid)
            vertex_ids.push(vertex)
            x_vals.push(x_val)
            attraction_vals.push(current_attraction)
            step_types.push(step_type)
            attraction_vals.push(current_attraction)
            print_row([fid,vertex,x_val.to_m.round(2),current_attraction.to_m.round(2),step_type])
            virgin = false
            prev_step_status = current_step_status
          end
          



          
          x_all = (x1+x2).sort
          attraction = Array.new
          
          x_all.each do |x|
            diff = interp_1.at(x)-interp_2.at(x)
            attraction.push(Geom::Point3d.new([x,diff,0]))
            plot_group.entities.add_cpoint(Geom::Point3d.new([x,diff,0]))
          end

          #Some table

          #Plot attraction      
          new_group = plot_group.entities.add_group
          attraction_edges = new_group.entities.add_edges(attraction)

          
          face3 = new_group.entities.add_edges(new_face_points_1)
          print_cpoint_with_label("start 1",new_face_points_1[0],plot_group)
          #face3.reverse!
          #face3.material = Sketchup::Color.new(255, 0, 0)
          
          new_group = plot_group.entities.add_group
          face4 = new_group.entities.add_edges(new_face_points_2)
          print_cpoint_with_label("start 2",new_face_points_2[0],plot_group)
          #face4.reverse!
          #face4.material = Sketchup::Color.new(255, 0, 0)

          #Plot Legend
          trans = Geom::Transformation.new(Geom::Point3d.new(0,face1.bounds.height,0))
          temp_group = plot_group.entities.add_group
          text = "Feature " +f1.to_s  + "& " +f2.to_s
          temp_group.entities.add_3d_text(text, TextAlignCenter, "Arial", true, false, 0.5.m, 0.0, 0.5, true, 0)
          temp_group.transform!(trans)

          count = count +1
        end
      end


      
      

      #INTERSECTION POINT GENTLEMENS AGREEMENT
      puts "\n==== Map vertices to intersection points ===="
      print_row(["Fid","Point Id","Vertex idx (sorted)","Distances(sorted)","Type"],[5,10,30,30,20])
      for i in 0..0
        
        all_xpoints_current_feature = xpoints[i] + xpoints_walls[i].to_a
        
        all_xpoints_current_feature = xpoints_deluxe.select {|k,v| [i].to_set.subset?(k)}
        all_xpoints_current_feature.each_pair do |key,point|

          print_xpoint(key,point,plot_group)
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

          print_row([i,j,ids[0..2],dists[0..2],ix_type],[5,10,30,30,20])
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
    def self.read_bfp_points(group)
      #Building Footprint
      pts = Array.new
      puts "==== Reading Building Footprint ===="
      path = File.dirname(__FILE__) + "/Polygon.txt"
      
      File.open(path, "r") do |f|
        f.each_line do |line|
          cols = line.split(' ')
          x = cols[0]
          y = cols[1]
          pts.push(Geom::Point3d.new(x.to_f.m,   y.to_f.m,   0))
        end
      end
      face = group.entities.add_face(pts)
      puts ""
      return face
       
    end

    def self.read_point_cloud(group,comp_def)
      las_pts = Array.new
      puts "\n==== Reading original poin-cloud data ===="
      n_points = 0
      path = File.dirname(__FILE__) + "/Points.txt"
      File.open(path, "r") do |f|
        f.each_line do |line|
          cols = line.split(' ')
          x = cols[0]
          y = cols[1]
          z = cols[2]
          point = Geom::Point3d.new(x.to_f.m,   y.to_f.m,   z.to_f.m)

          trans = Geom::Transformation.new(point)  
          instance = group.entities.add_instance(comp_def, trans)
          instance.material = Sketchup::Color.new(0, 0, 0)
          n_points = n_points+1
        end
        puts "Read a total number of #{n_points}"
      end
    end

    def self.read_features(group)
      puts "==== Reading features ===="
      n_features = 0
      features = Array.new
      vertices = Array.new
      path = File.dirname(__FILE__) + "/myfile.csv"
      File.open(path, "r") do |f|
        f.each_line do |line|

          if line.length < 2 then
            puts ">>>> ADDING FACE <<<<"
            vertices = vertices.map{ |arr| arr.map{ |v| v.to_f.m } } #complicated way of converting to float
            face = group.entities.add_face(vertices)
            features.push(face)
            vertices.clear

            n_features = n_features +1
          else
            temp = line.split(',')
            vertices.push(temp)
          end
          
        end
        return features
      end
      puts n_features.to_s + " n_features in total"      
    end
    def self.read_points_regions(group,comp_def)
      las_pts = Array.new
      puts "==== Reading Points and Regions ===="
      n_points = 0
      region_id = 0
      path = File.dirname(__FILE__) + "/regions_points.csv"
      File.open(path, "r") do |f|
        f.each_line do |line|
          unless line.length < 2 then
            cols = line.split(',')
            x = cols[0]
            y = cols[1]
            z = cols[2]
            #puts "x: #{x}, y: #{y}, z: #{z}"
            point = Geom::Point3d.new(x.to_f.m,   y.to_f.m,   z.to_f.m)
            las_pts.push(point)
            trans = Geom::Transformation.new(point)  
            instance = group.entities.add_instance(comp_def, trans)
            instance.material = @@distinguishable_colors[region_id]
            n_points = n_points+1
          else
            region_id = region_id+1
          end
        end
        
      end
      n_regions = region_id +1
      puts "Read a total number of #{n_points} points in #{n_regions} regions"
    end

    def self.get_centroid(objk)
      pts = objk.outer_loop.vertices.map {|v| v.position }
      total_area = 0
      total_centroids = Geom::Vector3d.new(0,0,0)
      third = Geom::Transformation.scaling(1.0 / 3.0)
      npts = pts.length
      puts npts
      vec1 = Geom::Vector3d.new(pts[1].x - pts[0].x, pts[1].y - pts[0].y, pts[1].z - pts[0].z)
      vec2 = Geom::Vector3d.new(pts[2].x - pts[0].x, pts[2].y - pts[0].y, pts[2].z - pts[0].z)
      ref_sense = vec1.cross vec2
      for i in 0...(npts-2)
        vec1 = Geom::Vector3d.new(pts[i+1].x - pts[0].x, pts[i+1].y - pts[0].y, pts[i+1].z - pts[0].z)
        vec2 = Geom::Vector3d.new(pts[i+2].x - pts[0].x, pts[i+2].y - pts[0].y, pts[i+2].z - pts[0].z)
        vec = vec1.cross vec2
        area = vec.length / 2.0
        if(ref_sense.dot(vec) < 0)
          area *= -1.0
        end
        total_area += area
        centroid = (vec1 + vec2).transform(third)
        t = Geom::Transformation.scaling(area)
        total_centroids += centroid.transform(t)
      end
      c = Geom::Transformation.scaling(1.0 / total_area)
      total_centroids.transform!(c) + Geom::Vector3d.new(pts[0].x,pts[0].y,pts[0].z)
    end
    
    def self.prin_feature_ids(features,group)

      
      for i in 0..features.length-1
        new_group = group.entities.add_group
        feature_name = "Feature " +i.to_s 
        new_group.entities.add_3d_text(feature_name, TextAlignCenter, "Arial", true, false, 1.m, 0.0, 0.5, true, 0)
        c = get_centroid(features[i])
        centroid = Geom::Point3d.new(c.x,   c.y,   c.z)
        puts "centroid: #{centroid}"

        trans=Geom::Transformation.new(centroid,features[i].normal)
        new_group.transform!(trans)
      end
      
    end

    def self.print_xpoint(key,point,group)
      txt = "P " + key.to_a.to_s
      group.entities.add_text(txt,point.offset([0,0,0.m]),[0,0,1.m])
      group.entities.add_cpoint(point)
    end
    def self.print_cpoint_with_label(txt,point,group)
      txt = txt.to_s
      group.entities.add_text(txt,point.offset([0,0,0.m]),[0,0,1.m])
      group.entities.add_cpoint(point)
    end
      
    def self.print_feature_vertex_ids(feature,group)
      c = get_centroid(feature)
      centroid = Geom::Point3d.new(c.x,   c.y,   c.z)

      feature.vertices.each_with_index do |vertex,index|

        
        edge = vertex.edges[0]
        v1 = edge.start.position.vector_to(edge.end.position)

        inwards = feature.normal.cross(v1)

        #v = vertex.position.vector_to(centroid)
        txt_point = vertex.position.offset(inwards,0.5.m)
        trans=Geom::Transformation.new(txt_point,feature.normal)
        

        new_group = group.entities.add_group
        txt = "v" +index.to_s
        new_group.entities.add_3d_text(txt, TextAlignCenter, "Arial", true, false, 20.cm, 0.0, 0.5, true, 0)

        new_group.transform!(trans)
        trans2=Geom::Transformation.new(new_group.bounds.center, feature.normal, 180.degrees+inwards.angle_between(new_group.transformation.xaxis))
        #new_group.transform!(trans2)


      end
      
      
    end
    
    def self.get_part_of_polygon(points,part)
      raise ArgumentError, 'Argument is not a string' unless part.is_a? String  
      if part=="north" then
        part_is_north = true
      elsif part=="south" then
        part_is_north = false
      else
        raise ArgumentError, 'Argument part has to be north or south'
      end
    
      most_right_point_id = points.each_with_index.max { |a, b| a[0].x<=> b[0].x }[1]
      most_left_point_id = points.each_with_index.min { |a, b| a[0].x<=> b[0].x }[1]

      #Create range between min-max id
      all_ids = Set.new(0..points.length-1)

      if most_left_point_id < most_right_point_id then
        group_ids = (most_left_point_id..most_right_point_id).to_a
      else
        group_ids = (most_right_point_id..most_left_point_id).to_a
      end
      
      #Decide if range is in our out
      if group_ids.length > 2 then

        if part_is_north then
          group_ids_should_be_saved = points[group_ids[1]].y > points[group_ids[0]].y 
        else
          group_ids_should_be_saved = points[group_ids[1]].y < points[group_ids[0]].y
        end
        if group_ids_should_be_saved then
          ids_to_save = group_ids
        else
          ids_to_save = all_ids-(group_ids.to_set-Set.new([most_left_point_id,most_right_point_id]))
          ids_to_save = ids_to_save.to_a.rotate
        end
        
        
      else
        #allt eller inget #TODO: implement
        puts "AJAJAJAJAJAJAJ"

      end
      new_points = Array.new
      ids_to_save.each do |id|
        new_points.push(points[id])
      end
      #array has to follow t ascending
      if new_points[0].x > new_points[-1].x then
        new_points.reverse!
        ids_to_save.reverse!
      end
      return new_points,ids_to_save 
    end
    

    def self.clamp(min, max, val)
      return [min, [max, val].min].max
      
    end
    
    def self.point_to_edge_distance(point, edge)
      v = ORIGIN.vector_to(edge.start)
      
      pv = edge.start.position.vector_to(point)
      wv = edge.start.position.vector_to(edge.end.position)
      l2 = wv.length*wv.length
      if l2 == 0 then 
        return pv.length
      else
        t = pv % wv / l2
        t = clamp(0,1,t)

        
        proj_vec = v + wv.transform!(Geom::Transformation.new(t))
        proj_point = Geom::Point3d.new(proj_vec[0],proj_vec[1],proj_vec[2])
        return point.distance(proj_point)
      end
      
    end

    def self.where_on_line(point,line)
      v = ORIGIN.vector_to(line[0])
      pv = line[0].vector_to(point)
      wv = line[0].vector_to(line[0].offset(line[1]))
      l2 = wv.length*wv.length
      t = pv % wv / l2
      return t
    end
    
    def self.print_row(cols,spacings = [5,20,20,20,20,20,20])
      #spacings = [5,20,20,20,20,20,20]
      string_to_print = ""
      for i in 0..cols.length-1
        
        col_str = cols[i].to_s
        spacing =  spacings[i]
        spaces_to_add = [0,spacing - col_str.length].max
        
        string_to_print = string_to_print + col_str + " "*spaces_to_add
      end
      puts string_to_print
    end
    

    # Here we add a menu item for the extension. Note that we again use a
    # load guard to prevent multiple menu items from accidentally being
    # created.
    unless file_loaded?(__FILE__)

      # We fetch a reference to the top level menu we want to add to. Note that
      # we use "Plugins" here which was the old name of the "Extensions" menu.
      # By using "Plugins" you remain backwards compatible.
      menu = UI.menu('Plugins')

      # We add the menu item directly to the root of the menu in this example.
      # But if you plan to add multiple items per extension we recommend you
      # group them into a sub-menu in order to keep things organized.
      menu.add_item('Import StrykIron') {
        self.import_strykiron
      }

      file_loaded(__FILE__)
    end

  end # module HelloCube
end # module Examples