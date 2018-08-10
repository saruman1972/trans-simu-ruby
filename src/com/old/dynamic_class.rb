module DynamicClass
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def self.extend_object(obj)
      obj.class_variable_set(:@@klass_map, {})
      obj.class_variable_set(:@@dynamic_klass, obj.name)
      super
    end

    def klass_variable(var_name)
      klass = self
      until klass == nil
        if klass.class_variable_defined?(var_name)
          return klass.class_variable_get(var_name)
        end
        klass = klass.superclass
      end
      nil
    end

    def klass_map
      klass_variable(:@@klass_map)
    end

    def dynamic_class
      klass_variable(:@@dynamic_klass)
    end

    def define_klass(klass_name)
      klass_name = klass_name.to_sym
      klass_map[klass_name] = self
      class_eval "def klass_name() '#{klass_name}' end"
    end

    def get_instance(klass_name, *args)
      klass_name = klass_name.to_sym
      raise "invalid klass_name[#{klass_name}] for [#{dynamic_class}]" unless klass_map.has_key? klass_name
      klass_map[klass_name].new(*args)
    end
  end
end



