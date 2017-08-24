require 'sketchup.rb'

class AttractionTableRow
  def initialize(index,fid,vertex,x_val,attraction,attraction_status,step_type,zone,is_zone)
    @id = index
    @fid = fid
    @vertex = vertex
    @x_val = x_val
    @attraction = attraction
    @attraction_status = attraction_status
    @step_type = step_type
    @zone = zone
    @is_zone = is_zone
  end

  attr_reader :id
  attr_reader :fid
  attr_reader :vertex
  attr_reader :x_val
  attr_reader :attraction
  attr_reader :step_type
  attr_reader :candidate
  attr_reader :action
  attr_reader :zone

  def make_print_row()
      return [@id,@fid,@vertex,@x_val.to_m.round(2),@attraction.to_m.round(2),@attraction_status,@step_type,@zone.id,@is_zone]
  end

end

class Step
  def initialize(id,fid,vertex,x_val,attraction,attraction_status,step_type,zone,is_zone)
    @id = id
    @fid = fid
    @vertex = vertex
    @x_val = x_val
    @attraction = attraction
    @attraction_status = attraction_status
    @step_type = step_type
    @zone = zone
    @is_zone = is_zone
  end

  attr_reader :fid
  attr_reader :x_val
  attr_reader :attraction
  attr_reader :step_type
  attr_reader :candidate
  attr_reader :action

  def make_print_row()
      return [@fid,@vertex,@x_val.to_m.round(2),@attraction.to_m.round(2),@attraction_status,@step_type,@zone,@is_zone]
  end
end

module StepTypes
  VERTEX = "v"
  XPOINT = "X-point"
  ZONE = "Zone"
  ZONE_START ="Zone start"
  ZONE_END ="Zone end"
end


class AttractionTable
  
  def initialize()
    @n_steps = 0
    @steps = Array.new
    @zones= Array.new(2)
    @snaps = Array.new
  end
  
  def self.add_step(fid,vertex,x_val,attraction,attraction_status,step_type,zone,in_zone)
    step_id = n_steps
    new_step = Step.new(step_id,fid,vertex,x_val,current_attraction,is_current_step_attractive,step_type,zone,in_zone)
    if in_zone then
      @zones[zone].push(step_id)
    end
    
    if(step_type == StepTypes::ZONE || step_type == StepTypes::XPOINT) then
      
    end
    
    @steps.push(new_step)
    @n_steps = @n_steps+1
  end
  
  def self.make_print_row_last()
    return @steps.last.make_print_row()
  end
  
  def self.snap_zones()
    
  end

  def self.retrive_polygon_change_info()
    
  end
  
end



class XPointSnap

  def initialize(key,point)
    @xpoint_key = key
    @xpoint = point
    @candidates = SortedSet.new()
    
    end

    def add_candidate(id,dist)
      @candidates.add(IdValuePair.new(id,dist))
    end

  def get_best_candidate()

    unless @candidates.empty?
      @candidates.to_a.first.id
    else
      nil
    end
    
  end
  def get_all_candidate_ids()
    @candidates.to_a.collect{|idvalpair| idvalpair.id}
  end
  
  
  attr_accessor :xpoint_key, :xpoint, :candidates

end



class IdValuePair
  include Comparable
  attr :id,:value

  def initialize(id,value)
    @id = id
    @value = value
  end

  def <=>(anOther)
    value <=> anOther.value
  end
  def inspect
    [@id,@value]
  end

end

class Zone
  attr_accessor :id,:start_step,:end_step
  def initialize(id,start_step, end_step)
    @id = id
    @start_step = start_step
    @end_step = end_step
  end

  def to_s
    "Zone #{@id}: #{@start_step} -> #{@end_step}"
  end

  def inspect
    [@start_step,@end_step]
  end

end
