require 'sketchup.rb'


class Figure2d
    # CLASS VARIABLES
    @@model = Sketchup.active_model
    @@move_down_trans = Geom::Transformation.new([0, 0, -1.m])

    @@graph_line_layer = @@model.layers.add("Plot Graph lines")
    @@graph_marker_layer = @@model.layers.add("Plot Graph markers")
    @@polygon_layer = @@model.layers.add("Plot Polygons")

    attr_reader :x_min
    
    
    def initialize(group)
        @plot_group = group
        @plot_group.name = "figure"
            # INSTANCE VARIABLES
        @tracked_faces = Array.new
        @faces = Array.new
        @face_ids = Array.new
        # @graph_line_group = @plot_group.entities.add_group
        # @graph_line_group.layer = @@graph_line_layer

        # @graph_marker_group = @plot_group.entities.add_group
        # @graph_marker_group = @@graph_marker_layer

        # @polygon_group = @plot_group.entities.add_group
        # @polygon_group.layer = @@polygon_layer   
        
    end

    def add_tracked_face(tf)
        @tracked_faces.push(tf)
        add_polygon(tf.original_face_points,tf.from_feature)
    end

    def add_polygon(face_points,id)
        @faces.push(@plot_group.entities.add_face(face_points))
        @face_ids.push(id)
    end

    def add_graph(xvals,yvals)
        graph_points = Array.new

        xvals.each_with_index do |x,index|
            point = Geom::Point3d.new([x,yvals[index],0])
            graph_points.push(point)
            @plot_group.entities.add_cpoint(point)
        end
        graph_edges = @plot_group.entities.add_edges(graph_points)        
    end

    def hide_plygon_edges()
        @faces.each do |face|
            face.edges.each {|e| e.visible = false}
        end
    end

    def annotate_poloygons()
        # faces = @tracked_faces.collect{|tf| tf.faces}
        # feature_ids = @tracked_faces.collect{|tf| tf.from_feature}
        ModelAnnotator::print_feature_ids(@faces,@plot_group,@face_ids)
        @faces.each do |face|
            ModelAnnotator::print_feature_vertex_ids(face,@plot_group)
        end
    end

    def claim_plot_area()
        #calculate plot area
        move_down = Geom::Transformation.new([0, 0, -1.m]) 
        xmax = @plot_group.bounds.max[0]
        xmin = @plot_group.bounds.min[0]
        ymax = @plot_group.bounds.max[1]
        ymin = @plot_group.bounds.min[1]
        width = @plot_group.bounds.width

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
        @plot_group.entities.add_edges(bb_points)


        @faces.each do |face| #to avoid z=0 quirk
            @plot_group.entities.transform_entities(move_down,face)
        end

        draw_axes(xaxis_end,ymax)
        @x_min = xmin
    end

    def draw_axes(xaxis_end,yaxis_end)
        @axis_group = @plot_group.entities.add_group
        ModelAnnotator::draw_2d_arrow(Geom::Point3d.new([0,0,0]),Geom::Point3d.new([0,yaxis_end,0]),@axis_group) #y-axis
        ModelAnnotator::draw_2d_arrow(Geom::Point3d.new([0,0,0]),Geom::Point3d.new([xaxis_end,0,0]),@axis_group) #y-axis
    end

end

