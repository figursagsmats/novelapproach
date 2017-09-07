require 'sketchup.rb'
require_relative '../src/importer.rb'
require_relative '../src/model_annotator.rb'
require_relative '../src/console_deluxe.rb'
require_relative '../src/helper_classes.rb'
class FeatureIntersector
    #use hashes instead of 2d arrays
    @xlines= Hash.new             #intersection lines
    @xlines_dists = Hash.new      #distance from feature vertices to xline.
    @xlines_projs = Hash.new      #vertices projected on xline
    @xlines_ts = Hash.new         #where on the xline
    @xlines_proximity_between_ft_vertices = Hash.new #The distances between the two most adjecent vertices in two features. This measure is obtained by comparing all vertex-to-vertex distances between the features.
    @xlines_transformed_points = Hash.new #vertices transformed so that x-line is xaxis t = 0 is origo and projected to xy-plane
    @xlines_transformations = Hash.new  #
    
    @n_features

    @LINE_CONSCENT_THRESH ||= 4.m
    @VERTEX_PROXIMITY_THRESH ||= 2.m
    @WALL_BIAS_FACTOR ||= 0.8
    @XPOINT_DISTANCES_THRESH ||= 2.m
    @ATTRACTION_THRESH ||= 2.m

    def initialize(features)
        @n_features = features.length
    end

    
    
    def initial_calculations()

        # Calculates 
        #   - xlines
        #   - xlines_dists
        #   - xlines_projs
        #   - xlines_ts
        #   - xlines_proximity_between_ft_vertices
        #   - xlines_transformations

        for i in 0...@n_features
            for j in 0...@n_features
                unless i == j || @xlines.has_key?([i,j]) then #no neeed for i-j if j-i exists
                
                puts "Creating xline of feaature #{i} and #{j}"
                line = Geom.intersect_plane_plane(@features[i].plane, @features[j].plane)
                @xlines[[i,j]] = line
                @xlines[[j,i]] = line

                #Prep transformation
                line_xaxis = line[1].clone.normalize 
                line_origo = line[0].clone

                #puts "line_origo: #{line_origo}"
                #puts "line_xaxis: #{line_xaxis}"

                #Transformation
                #line_xaxis.z = 0
                #line_origo.z = 0
                zaxis = Geom::Vector3d.new(0,0,1)
                yaxis = line_xaxis*zaxis
                

                trans = Geom::Transformation.new(line_origo, line_xaxis, yaxis)
                
                #ConsoleDeluxe::print_matrix(trans.to_a,4,4)
                #trans = Geom::Transformation.new(line_xaxis, yaxis,zaxis,line_origo)
                trans.invert!
                

                #Transformation (new)
                translation_vector = line_origo.vector_to(ORIGIN)
                identity = Geom::Transformation.new()
                angle = CustomGeomOperations::angle_between_vectors_xy(X_AXIS,line_xaxis)
                
                rotation = Geom::Transformation.rotation(ORIGIN, Z_AXIS, -angle)
                translation = Geom::Transformation.translation(translation_vector)

                projection = Geom::Transformation.new([1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0, 0.0, 0.0, 0.0, 0.0, 1.0])
                transformation = Geom::Transformation.new()
                angle_degrees = angle.radians
                puts "angle between x-axis and xline: #{angle_degrees}"
                trans = projection*rotation*translation


                #puts "inverse #{trans.to_a}"
                @xlines_transformations[[i,j]] = trans
                @xlines_transformations[[j,i]] = trans

                #First feature closest vertex to xline
                distances_i = Array.new
                proj_points_i = Array.new
                ts_i= Array.new
                transformed_points_i = Array.new

                @features[i].vertices.each do |vertex|
                    distances_i.push(vertex.position.distance_to_line(line))
                    proj_points_i.push(vertex.position.project_to_line(line))
                    ts_i.push(CustomGeomOperations::where_on_line(vertex.position,line))
                    p = vertex.position.clone.transform(trans)
                    p.z = 1.m
                    transformed_points_i.push(p)
                end



                @xlines_dists[[i,j]] = distances_i
                @xlines_projs[[i,j]] = proj_points_i
                @xlines_ts[[i,j]] = ts_i
                @xlines_transformed_points[[i,j]] = transformed_points_i
                #@xlines_transformed_points[[i,j]] = @features[i].transform(trans)
                #Second Feature closest vertex to xline
                distances_j = Array.new
                proj_points_j = Array.new
                ts_j= Array.new
                transformed_points_j = Array.new

                @features[j].vertices.each do |vertex|
                    distances_j.push(vertex.position.distance_to_line(line))     
                    proj_points_j.push(vertex.position.project_to_line(line))
                    ts_j.push(CustomGeomOperations::where_on_line(vertex.position,line))
                    p = vertex.position.transform(trans)
                    p.z = 1.m
                    transformed_points_j.push(p)
                end

                @xlines_dists[[j,i]] = distances_j
                @xlines_projs[[j,i]] = proj_points_j
                @xlines_ts[[j,i]] = ts_j
                @xlines_transformed_points[[j,i]] = transformed_points_j

                #Vertex proximity
                #TODO: make this with edge to vertex instead
                temp_hash = Hash.new
                edge_dists = Array.new
                @features[i].vertices.each_with_index do |first_vertex,k|
                    @features[j].vertices.each_with_index do |second_vertex,l|
                        unless temp_hash.has_key?([[l,k]]) then
                            temp_hash[[k,l]] = true
                            temp_hash[[l,k]] = true
                            edge_dists.push(first_vertex.position.distance(second_vertex))
                            
                        end
                    end
                end
                min_edge_dist = edge_dists.min
                @xlines_proximity_between_ft_vertices[[j,i]] = min_edge_dist
                @xlines_proximity_between_ft_vertices[[i,j]] = min_edge_dist

                end      
            end
        end
    end
    
    def balls_to_the_walls()

        # Creates intersection lines and points for walls intersecting with features. 
        # Also discard bogus intersections via comparing the distance between wall edges 
        # projected to a features plane and its vertcies.

        puts "\n==== BALLS TO THE WALLS ===="
        ConsoleDeluxe::print_row(["Fid","BFP-edge","Min dist","Status"])
        @xlines_walls = Hash.new #TODO implement this
        @xpoints_walls = Array.new(features.length){Set.new}
        for i in 0...@n_features
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
                    distances.push(CustomGeomOperations::point_to_edge_distance(vertex.position,new_edge))
                end
                min_dist = distances.min
                if min_dist > 2.m
                    status = "FIMPAD"
                    new_edge.erase!
                else
                    status = "ok"
                    @xpoints_walls[i].add(x1)
                    @xpoints_walls[i].add(x2)
                end
                ConsoleDeluxe::print_row([i,edge_idx,min_dist,status])
                
                edge_idx = edge_idx+1
            end
        end        
    end

    def remove_bogus_xlines()
        # VASK O FIMP
        puts "\n==== Determine which intersection lines to vask ===="
        ConsoleDeluxe::print_row(["ID","Closest Vertex","Vertex Proximity","Status"])
        for i in 0...@n_features
            f1 = @features[i] 
            for j in 0...@n_features
                unless i == j  then
                    id = i.to_s + "-" + j.to_s
                    closest_vertex_to_line_dist,min_id_i = @xlines_dists[[i,j]].each_with_index.min
                    vertex_proximity = @xlines_proximity_between_ft_vertices[[i,j]]           

                    if closest_vertex_to_line_dist > @LINE_CONSCENT_THRESH || vertex_proximity > @VERTEX_PROXIMITY_THRESH
                        status = "FIMPAD!"
                        @xlines[[i,j]] = nil
                    else
                        status = "ok"
                    end
                    ConsoleDeluxe::print_row([id,closest_vertex_to_line_dist.to_mm.floor,vertex_proximity,status])
            
                end      
            end
        end
    end
    
    def calcualte_relevant_xpoints()
        #Intersection points
        @xpoints = Array.new(@features.length){Array.new}
        @xpoints_deluxe = Hash.new
        #xpoint_id = 0
        puts "\n==== Find intersection points ===="
        ConsoleDeluxe::print_row(["Fid","Features X","Keyz","Feature dists (m)","Sum","Status"],[5,15,20,30,20,30])
        for i in 0...@n_features
        
            feature_id = i
            feature_face = @features[feature_id]

            hash_keys_to_get = get_feature_xline_keys(feature_id)

            #TODO: avid calculating same xpoint many times
            hash_keys_to_get.combination(2).each do |keyz|
                point = Geom.intersect_line_line(@xlines[keyz[0]], @xlines[keyz[1]])

                point_identity = keyz.flatten.uniq
                xpoint_dists_to_creators = Array.new
                for fid in point_identity do
                    dists = Array.new
                    @features[fid].edges.each do |edge|
                        dists.push(CustomGeomOperations::point_to_edge_distance(point, edge))
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
                ConsoleDeluxe::print_row([feature_id,point_identity,keyz,xpoint_dists_to_creators_min_print,xpoint_dists_to_creators_min_sum.to_m.round(2),status],[5,15,20,30,20,30])

                unless vask then
                    @xpoints_deluxe[point_identity.to_set] = point #TODO: make hash that can lookup point from 2 features rather than 3
                    @xpoints[i].push(point)
                end
                #xpoints_group.entities.add_cpoint(point)
                #xpoint_id = xpoint_id+1
            end
        end        
    end
    
    def get_feature_xlines(feature_id)
    end
    
    def get_transformed_feature()
    end

    def get_feature_xline_keys(feature_id)

        hash_keys_to_get = (0...@n_features).reject{|x| x == feature_id}.to_a.product([feature_id]) #get whole row except self
        hash_keys_to_get = hash_keys_to_get.reject{|pair| @xlines[pair].nil?} # remove pair with non-existing line
        return hash_keys_to_get
    end
    
    def get_xpoint_for_feature_pair(key_set)
        shared_xpoints = xpoints_deluxe.select {|k,v| key_set.subset?(k)} #select x-points belonging o f1 and f2
        vpf_x_points = Array.new()
        shared_xpoints.each_pair do |key,point|
            new_x_point = point.clone
            new_x_point.z = 0
            new_x_point.transform!(xlines_transformations[[f1,f2]])
            vpf_x_points.push([key.to_a.join.to_i,new_x_point,-1])
            ModelAnnotator::print_xpoint(key,new_x_point,plot_group)
        end
        return vpf_x_points
    end

    def features_position_from_line(face1, face2)
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
        end



end

