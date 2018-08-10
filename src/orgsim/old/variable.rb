require 'csv'
require 'simulator'

module Simulator
  module Orgsim
    class Variable
      include DynamicClass

      class << self
        attr_accessor :filename

        def define_attr(name)
          class_eval "def #{name}; @#{name}; end"
          class_eval "def #{name}=(val); @#{name}=val; end"
        end

        def columns
          @objs ||= load
          @columns
        end

        def [](k)
          @objs ||= load
          @objs[k.to_s]
        end

        def find(k)
          @objs ||= load
          @objs[k.to_s]
        end

        def getValue(k, column)
          record = find(k)
          raise "invalid index[#{k}] for [#{name}]" unless record
          raise "invalid column[#{column}] for [#{name}]" unless record.respond_to? column
          record.send(column)
        end

        def []=(k,v)
          @objs ||= load
          @objs[k] = v
          @objs[v.id] = v
          @objs[v.name] = v
        end

        def to_a
          row = []
          @columns.each {|name|
            row << self.send(name)
          }
          row
        end

        def load
          objHash = {}
          reader = CSV.open(filename, "rt", :row_sep => "\n")
          @columns = reader.shift
          @columns.each {|col| define_attr(col)}
          reader.each {|row|
            obj = self.new
            @columns.each_with_index {|name,idx| 
              obj.send("#{name}=", row[idx])
            }
            objHash[obj.id] = obj
            objHash[obj.name] = obj
          }
          reader.close
          objHash
        end

        def save
          return unless @objs
          CSV.open(filename, "wb") do |csv|
            csv << @columns
            @objs.each {|obj|
              csv << obj.to_a
            }
          end # end of CSV.Writer
        end

      end

    end

    class Card < Variable
      define_klass :CARD
    end

    class Acquirer < Variable
      define_klass :ACQUIRER
    end

    # class Variable
    #   class << self
    #     def getValue(source, index, column)
    #       klass = source.upcase.to_sym
    #       raise "invalid source[#{source}]" unless @@map.has_key? klass
    #       record = @@map[klass][index]
    #       raise "invalid index[#{index}]" unless record
    #       raise "invalid column name[#{column}]" unless record.respond_to? column
    #       record.send(column)
    #     end

    #     # def getValue(source, index, column)
    #     #   raise "invalid source[#{source}]" if source != 'CARD' && source != 'ACQUIRER'
    #     #   if source == 'CARD'
    #     #     card = Card.filter(:SEQ_NO => index).first
    #     #     raise "invalid index[#{index}]" unless card
    #     #     begin
    #     #       card.send(column.upcase)
    #     #     rescue
    #     #       raise "invalid column name[#{column}]"
    #     #     end
    #     #   else
    #     #     acquirer = Acquirer.filter(:SEQ_NO => index).first
    #     #     raise "invalid index[#{index}]" unless acquirer
    #     #     begin
    #     #       acquirer.send(column.upcase)
    #     #     rescue
    #     #       raise "invalid column name[#{column}]"
    #     #     end
    #     #   end
    #     # end
    #   end # end of class << self
    # end


  end # end of module Orgsim
end # end of module Simulator
