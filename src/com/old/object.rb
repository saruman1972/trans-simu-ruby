class Object
  def deep_clone
    case self
      when Fixnum, Bignum, Float, NilClass, FalseClass, TrueClass
        klone = self
      when Hash
        klone = self.clone
        self.each {|k,v| klone[k] = v.deep_clone}
      when Array
        klone = self.clone
        klone.clear
        self.each {|v| klone << v.deep_clone}
      else
        klone = self.clone
    end
    klone.instance_variables.each {|v|
      klone.instance_variable_set(v, klone.instance_variable_get(v).deep_clone)
    }
    klone
  end
end
