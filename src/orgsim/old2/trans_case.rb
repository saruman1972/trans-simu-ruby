require 'simulator'
require 'value_type'
require 'pack_hook'
require 'data_field'
require 'comm'
require 'ui'

module Simulator
  module Orgsim
    class CaseField
      attr_accessor :name, :generator, :df, :action, :packHook

      def initialize(name, df, action)
        @name = name
        # @df - data field
        @df = df
        @action = action
      end

      def applyHook
        @df.value = @packHook.pack(@df.value) if @packHook
      end

      def genValue
        @df.value = @generator.value
      end

      def setValue(val)
        @df.value = val
      end

      def getValue
        @generator.value
      end

      def clear
        @generator.value = nil
      end
    end

    class Action
      include DynamicClass

      attr_accessor :fldDefs, :transCase, :flds, :fldHash, :cardIndex, :acquirerIndex, :prevIncomingFlddef, :prevOutgoingFlddef, :changed
      attr_accessor :ui

      def initialize(fldDefs)
        @fldDefs = fldDefs
        @flds = []
        @fldHash = {}
        @cardIndex = -1
        @acquiereIndex = -1
        @changed = false
      end

      def changed=(status)
        @changed = status
        @transCase.changed = status
      end

      def <<(fld)
        @flds << fld
        @fldHash[fld.name] = fld
#        define_attr(fld) if fld.generator.kind_of? ValueTypeUserInput
      end

      def insert(idx, fld)
        @flds.insert(idx, fld)
        @fldHash[fld.name] = fld
      end

      def delete(idx)
        fld = @flds[idx]
        @fldHash.delete(fld.name)
        @flds.delete_at(idx)
      end

      def findIndex(name)
        @flds.find_index {|f| f.name == name}
      end

      def hasField?(name)
        @flds.find {|fld| fld.name == name}
      end

      def define_attr(fld)
        instance_eval "def #{fld.name}; @fldHash['#{fld.name}'].generator.value; end"
        instance_eval "def #{fld.name}=(val); @fldHash['#{fld.name}'].generator.value=val; end"
      end

      def unpackPrevMessage
        if @prevIncomingFlddef
          @prevIncomingFlddef.clear
          begin
            @prevIncomingFlddef.rootUnpack(TrxnLog.prevIncoming)
          rescue 
            nil 
          end
        end

        if @prevOutgoingFlddef
          @prevOutgoingFlddef.clear
          begin
            @prevOutgoingFlddef.rootUnpack(TrxnLog.prevOutgoing) 
          rescue
            nil 
          end
        end
      end

      def userInputList
        @flds.select {|fld| fld.generator.kind_of? ValueTypeUserInput}
      end

      def fixedValueList
        @flds.select {|fld| fld.generator.kind_of? ValueTypeFixed}
      end

      def otherList
        @flds.select {|fld| !(fld.generator.kind_of?(ValueTypeUserInput) || fld.generator.kind_of?(ValueTypeFixed))}
      end

      include Enumerable
      def each
        @flds.each do |fld|
          yield(fld)
        end
      end
    end

    class ActionOutgoing < Action
      define_klass :OUTGOING_MESSAGE

      def genValue
        # get user input first
        ui = UIDesc.new(self)
        return false unless ui.doUI

        # then get fixed value
        fixedValueList.each {|fld| fld.genValue}

        # then unpack previous message if exists
        unpackPrevMessage

        # then get variable/system generated value
        otherList.each {|fld| fld.genValue}

        # apply pack hook
        @flds.each {|fld| fld.applyHook}
      end

      def doAction
        return false unless genValue
        message = @fldDefs.rootPack
print @fldDefs.dump
        comm = Communication.getCommunication
        comm.sendMessage(message)
        true
      end
    end

    class ActionIncoming < Action
      define_klass :INCOMING_MESSAGE
      attr_accessor :timeout

      def validate
        # then unpack previous message if exists
        unpackPrevMessage

        @flds.each do |fld|
          if fld.getValue != fld.df.value
            print "field[#{fld.name}] mismatch: value[#{fld.df.value}] expected[#{fld.getValue}]\n"
          end
        end
      end

      def doAction
        comm = Communication.getCommunication
        message = comm.recvMessage(@timeout)
        @fldDefs.clear
        @fldDefs.rootUnpack(message)

print message.hex_dump
print @fldDefs.dump
        validate
        true
      end
    end

    class ActionDelay < Action
      define_klass :DELAY
      attr_accessor :interval

      def initialize(fldDefs)
        super
        @interval = 1
      end

      def interval=(val)
        @interval = if val.kind_of? String
                      val.to_i
                    else
                      val
                    end
      end

      def doAction
#        sleep(@interval)
        true
      end
    end



    class TransCase
      attr_accessor :name, :desc, :actions, :fldDefs, :cardIndex, :acquirerIndex, :changed

      def initialize(fldDefs)
        @fldDefs = fldDefs
        @actions = []
        @changed = false
      end

      def runCase
        @actions.each do |act|
          return false unless act.doAction
        end
      end

      class << self
        require 'rexml/document'
        include REXML

        # fldDefs - field_def compound data field
        def load(fldDefs, filename)
          input = File.new(filename)
          doc = Document.new(input)
          root = doc.root
          input.close

          transCase = self.new(fldDefs)
          transCase.name = root.attribute('name').value if root.attributes.has_key? 'name'
          transCase.desc = root.attribute('desc').value if root.attributes.has_key? 'desc'
          if root.attributes.has_key? 'card_index'
            transCase.cardIndex = root.attribute('card_index').value.to_i
          end
          if root.attributes.has_key? 'acquirer_index'
            transCase.acquirerIndex = root.attribute('acquirer_index').value.to_i
          end

          root.elements.each("action") do |elm|
            transCase.actions << loadAction(transCase, elm)
          end

          transCase
        end # end of load

        def loadAction(transCase, node)
          raise "action type missing" unless node.attributes.has_key? 'type'
          action = Action.get_instance(node.attribute('type').value.upcase.to_sym, transCase.fldDefs)
          action.transCase = transCase
          action.cardIndex = transCase.cardIndex
          action.acquirerIndex = transCase.acquirerIndex

          node.attributes.each do |name,value|
            action.send("#{name}=", value) unless name == 'type'
          end

          node.elements.each("field") do |elm|
            action << loadField(action, elm)
          end
          
          action
        end

        def loadField(action, node)
          name = if node.attributes.has_key? 'name'
                   node.attribute('name').value
                 else
                   elms = node.get_elements('name')
                   raise "name missing in field define" if elms.length == 0
                   elms[0].text.strip
                 end
          df = action.fldDefs.findField(name)
          raise "invalid name[#{name}]" unless df
          fld = CaseField.new(name, df, action)

          node.elements.each do |e|
            case e.name
            when 'value'
              type = e.attribute('type').value.upcase
              fld.generator = ValueType.get_instance(type.to_sym, fld.df.codec)
              raise "invalid value type[#{type}] in field[#{fld.name}]" unless fld.generator
              loadProperty(e, fld.generator)
            when 'pack_hook'
              type = e.attribute('type').value.upcase
              fld.packHook = PackHook.get_instance(type.to_sym)
              raise "invalid pack_hook type[#{type}] in field[#{fld.name}]" unless fld.packHook
              fld.packHook.fld = fld
              loadProperty(e, fld.packHook)
            end # end of case
            unless fld.generator
              fld.generator = if df.generator
                                df.generator
                              else
                                ValueTypeUserInput.new
                              end
            end
          end # end of node.elements.each
          if fld.generator.respond_to? 'card_index'
            fld.generator.card_index = action.cardIndex
          end
          if fld.generator.respond_to? 'acquirer_index'
            fld.generator.acquirer_index = action.acquirerIndex
          end
          if fld.generator.kind_of? ValueTypePreviousOutgoing
            action.prevOutgoingFlddef ||= action.fldDefs.clone
            fld.generator.field_def = action.prevOutgoingFlddef
          end
          if fld.generator.kind_of? ValueTypePreviousIncoming
            action.prevIncomingFlddef ||= action.fldDefs.clone
            fld.generator.field_def = action.prevIncomingFlddef
          end
          if fld.generator.kind_of? ValueTypeCurrentMessage
            fld.generator.field_def = action.fldDefs
          end

          fld
        end # end of loadField

        def loadProperty(node, obj)
          node.elements.each("property") do |e|
            raise "property name missing" unless e.attributes.has_key? 'name'
            value = if e.attributes.has_key? 'value'
                      e.attribute('value').value
                    else
                      e.text.strip
                    end
            obj.send("#{e.attribute('name').value}=", value)
          end
        end

      end # end of class << self

    end # end of class TransCase

  end # end of module Orgsim
end # end of module Simulator
