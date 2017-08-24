require 'sketchup.rb'

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
        #BALLS TO THE WALLS
        
        #create feature lines

        #Itertat
        puts "\n==== BALLS TO THE WALLS ===="
        ConsoleDeluxe::print_row(["Fid","BFP-edge","Min dist","Status"])
        xlines_walls = Hash.new
        xpoints_walls = Array.new(features.length){Set.new}
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
                    xpoints_walls[i].add(x1)
                    xpoints_walls[i].add(x2)
                end
                ConsoleDeluxe::print_row([i,edge_idx,min_dist,status])
                
                edge_idx = edge_idx+1
            end
        end        
    end

    def remove_bogus_xlines()

    end
    
    def calcualte_relevant_xpoints()
    end
    
    def get_feature_xlines(feature_id)
    end
    
    def get_transformed_feature()
    end

end

