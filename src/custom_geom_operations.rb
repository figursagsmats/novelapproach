require 'sketchup.rb'

module CustomGeomOperations

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
            
            selected_ids = (most_left_point_id..most_right_point_id).to_a
        else
            selected_ids = (most_right_point_id..most_left_point_id).to_a
        end
        
        #Decide if range is in our out
        if selected_ids.length > 2 then 

            center_vector = points[most_left_point_id].vector_to(points[most_right_point_id])
            center_line = [ points[most_left_point_id],  center_vector]
            projected_point =  points[selected_ids[1]].project_to_line(center_line)
            cool_vector = points[selected_ids[1]].vector_to(projected_point)

            if part_is_north then
                should_selected_be_saved = cool_vector.y < 0
            else
                should_selected_be_saved = cool_vector.y > 0
            end
            if should_selected_be_saved then
                ids_to_save = selected_ids
            else
                ids_to_save = all_ids-(selected_ids.to_set-Set.new([most_left_point_id,most_right_point_id]))
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
        #if new_points[0].x > new_points[-1].x then
            # puts "reversing ids!"
            # new_points.reverse!
            # ids_to_save.reverse!
        #end
        return new_points,ids_to_save 
    end
    
    def self.replace_vertices_on_face(face,rejectees,new_points,group)
        new_ids = (Set.new((0...face.vertices.length).to_a) - Set.new(rejectees)).to_a
        insert_position = new_ids[rejectees.min-1]
        new_face_points = replace_vertices_on_face_core(face,new_ids,new_points, insert_position)
        return group.entities.add_face(new_face_points)
    end
    
    def self.replace_vertices_on_face_2(face,new_points,insert_position,group)

        new_ids = (0...face.vertices.length).to_a
        new_face_points = replace_vertices_on_face_core(face,new_ids,new_points, insert_position)
        return group.entities.add_face(new_face_points) 
    end
    
    def self.replace_vertices_on_face_core(face,new_ids,new_points, insert_position)
        new_face_points = Array.new
        new_ids.each do |index|
            vertex = face.vertices[index]
            if(index == insert_position) then
                new_face_points.concat(new_points)
            else
                new_face_points.push(vertex.position)
            end
        end
        return new_face_points
        
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

    def self.angle_between_vectors_xy(vector1,vector2)
        #https://stackoverflow.com/questions/21483999/using-atan2-to-find-angle-between-two-vectors

        signed_angle = Math.atan2(vector2.y, vector2.x) - Math.atan2(vector1.y, vector1.x);

        if (signed_angle < 0) then 
            signed_angle += 2 * Math::PI;
        end

        return signed_angle
        
    end

    def self.scale(v,s) 
        vtmp = v.clone;
        vtmp.length = vtmp.length * s
        vtmp
    end
    
    def self.linear_interp_x(x0,x1,y0,y1,y)
        x = x0 + ((y-y0)*(x1-x0))/(y1-y0)
    end
    
    def self.snap_feature(feature,remove_interval,new_points)
        
        return new_feature
    end
end