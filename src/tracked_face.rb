require 'sketchup.rb'


class TrackedFace
  # Wrapper around a sketcup face to keep be able to perform clipping operations on the face
  # but still keep track of the original vertix ids

  attr_reader :from_feature
  attr_reader :face
  attr_reader :original_face_points

  def initialize(face_points,group,from_feature)
    @original_face_points = face_points
    @from_feature = from_feature
    @face = group.entities.add_face(face_points)
    @face.visible = false
    
    @ids_to_save = Array(0..@face.vertices.length) #ids of points used in the potential new face
    ObjectSpace.define_finalizer(self, proc { @face.erase! }) #destructor

  end


  def get_new_points()
    new_points = Array.new()
    @ids_to_save.each do |id|
      new_points.push(@face.vertices[id].position)
    end
    return new_points
  end

  def get_as_xline_interest_points()
    xlips = Array.new()
    @ids_to_save.each do |id|
      xlips.push(XlineInterestPoint.new(id,@face.vertices[id].position,@from_feature))
    end
    return xlips
  end

  
  def split_in_half(part)
    points = @face.vertices.collect{|v| v.position}
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
    @ids_to_save = ids_to_save
  end
end