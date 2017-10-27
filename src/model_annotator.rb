require 'sketchup.rb'
require_relative 'custom_geom_operations.rb'

module ModelAnnotator

  def self.print_feature_ids(features,group,ids = nil)

    if ids.nil? then 
      ids = (0...features.length).to_a
    end
    
    for i in 0..features.length-1
      new_group = group.entities.add_group
      feature_name = "Feature " + ids[i].to_s 
      new_group.entities.add_3d_text(feature_name, TextAlignCenter, "Arial", true, false, 1.m, 0.0, 0.5, true, 0)
      c = get_centroid(features[i])
      centroid = Geom::Point3d.new(c.x,   c.y,   c.z)

      trans=Geom::Transformation.new(centroid,features[i].normal)
      new_group.transform!(trans)
    end
    
  end

  def self.print_xpoint(key,point,group)
    unless key.is_a?(Fixnum) then
      txt = "P " + key.to_a.to_s
    else
      txt = "P " + key.to_s 
    end
    group.entities.add_text(txt,point.offset([0,0,0.m]),[0,0,1.m])
    group.entities.add_cpoint(point)
  end

  def self.print_cpoint_with_label(txt,point,group)
    txt = txt.to_s
    group.entities.add_text(txt,point.offset([0,0,0.m]),[0,0,1.m])
    group.entities.add_cpoint(point)
  end
    
  def self.print_feature_vertex_ids(feature,group,padding = 19.5)
    feature.vertices.each_with_index do |vertex,index|
      #Calculate inwards vector
      edge1 = vertex.edges[0]
      edge2 = vertex.edges[1]
      neigbour_vertices = [edge1.start,edge1.end,edge2.start,edge2.end].uniq
      neigbour_vertices.delete_if {|x| x == vertex}
      p1 = neigbour_vertices[0].position
      p2 = neigbour_vertices[1].position
      v1 = vertex.position.vector_to(p1).normalize
      v2 = vertex.position.vector_to(p2).normalize
      v3 = v1-v2
      inwards = feature.normal.cross(v3)

      if feature.classify_point(vertex.position.offset(inwards,padding)) == Sketchup::Face::PointOutside
        inwards.reverse!
      end

      txt_point = vertex.position.offset(inwards,0.5.m)
      
      txt = "v" +index.to_s
      new_group = group.entities.add_group
      new_group.entities.add_3d_text(txt, TextAlignCenter, "Arial", true, false, 20.cm, 0.0, 0.5, true, 0)

      #Translate text inwards
      trans=Geom::Transformation.new(txt_point,feature.normal)
      new_group.transform!(trans)

      #Rotate text
      trans2=Geom::Transformation.new(new_group.bounds.center, feature.normal, 180.degrees+inwards.angle_between(new_group.transformation.xaxis))
      #new_group.transform!(trans2)
    end
  end
  
  def self.get_centroid(objk)
    pts = objk.outer_loop.vertices.map {|v| v.position }
    total_area = 0
    total_centroids = Geom::Vector3d.new(0,0,0)
    third = Geom::Transformation.scaling(1.0 / 3.0)
    npts = pts.length
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

  def self.draw_2d_arrow(start_point,end_point,group,width=0.5.m,sharpness=1)
    head_length = width*sharpness
    length = start_point.distance(end_point)
    v=start_point.vector_to(end_point).normalize
    vc = CustomGeomOperations::scale(v,length-head_length)
    pc = start_point.offset(vc)
    v_perp = (v*[0,0,1]).normalize
    v_perp_1 = CustomGeomOperations::scale(v_perp,width/2)
    v_perp_2 = CustomGeomOperations::scale(v_perp,-(width/2))

    p1 = pc.offset(v_perp_1)
    p2 = pc.offset(v_perp_2)
    points = [pc,p2,end_point,p1]
    group.entities.add_line(start_point,pc)
    group.entities.add_face(points)
  end
  
end
