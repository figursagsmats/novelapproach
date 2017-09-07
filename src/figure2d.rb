require 'sketchup.rb'


class Figure2d
    @@figures = []
    @plot_group
    def initialize(group)
        @plot_group = group
    end

    def add_polygon()
        
    end

    def calculate_plot_area(plot_group)
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
        draw_axes(xaxis_end,ymax)


        
    end
    def draw_axes(xaxis_end,yaxis_end)
        ModelAnnotator::draw_2d_arrow(Geom::Point3d.new([0,0,0]),Geom::Point3d.new([0,yaxis_end,0]),plot_group) #y-axis
        ModelAnnotator::draw_2d_arrow(Geom::Point3d.new([0,0,0]),Geom::Point3d.new([xaxis_end,0,0]),plot_group) #y-axis
    end

end

