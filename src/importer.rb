require 'sketchup.rb'

module Importer
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


    @data_dir_path = File.join(File.dirname(__FILE__),'..','data')

    def self.read_bfp_points(group)
      #Building Footprint
      pts = Array.new
      puts "==== Reading Building Footprint ===="
      path = @data_dir_path + "/Polygon.txt"
      
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
      path = @data_dir_path + "/Points.txt"
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
      path = @data_dir_path + "/myfile.csv"
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
      path = @data_dir_path + "/regions_points.csv"
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
end
