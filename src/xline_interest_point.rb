require 'sketchup.rb'


class XlineInterestPoint

  def initialize(key,point,feature_id)
    if key.is_a?(Set) then
      @key = key.to_a.join.to_i #
    else
      @key = key
    end

    
    @x = point.x
    @point = point

    @feature_id = feature_id
  end

  attr_reader :key
  attr_reader :x
  attr_reader :point
  attr_reader :feature_id
end

