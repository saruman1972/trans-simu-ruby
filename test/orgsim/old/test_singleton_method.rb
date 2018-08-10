require 'simulator'

class AA
  attr_accessor :nums

  def initialize
    @nums = []
  end
end

aa = AA.new
bb = AA.new
aa.instance_eval "def name; @aa; end"
aa.instance_eval "def name=(val); @aa=val; end"
aa.name = 'aa'
aa.nums = [1,2,3,4]

#cc = aa.deep_clone
cc = aa.clone
cc.name = 'cc'
cc.nums[2] = 'cc'

p aa.name
p aa.nums
p cc.name
p cc.nums
