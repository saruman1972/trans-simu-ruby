require 'simulator'
require 'variable'
require 'config'
require 'trxn_log'

module Simulator
  module Orgsim
    class ValueType
      include DynamicClass
      attr_accessor :codec, :value

      def initialize(codec = nil)
        @codec = codec
      end

    end

    class ValueTypeUserInput < ValueType
      define_klass :USER_INPUT

      def value=(val)
        if @codec.binary?
          @value = val.unhexlify
        else
          @value = val
        end
      end

      def value
        @value
      end
    end

    class ValueTypeFromConfig < ValueType
      define_klass :CONFIG
      attr_accessor :name
      
      def value
        config = Config.getConfig
        config[name]
      end
    end

    class ValueTypeVariableCard < ValueType
      define_klass :VARIABLE_CARD
      attr_accessor :card_index, :column

      def value
        Card.getValue(card_index, column)
      end
    end

    class ValueTypeVariableAcquirer < ValueType
      define_klass :VARIABLE_ACQUIRER
      attr_accessor :acquirer_index, :column

      def value
        Acquirer.getValue(acquirer_index, column)
      end
    end

    class ValueTypeFixed < ValueType
      define_klass :FIXED

      def value
        @value
      end

      def value=(val)
        if @codec.binary?
          @value = val.unhexlify
        else
          @value = val
        end
      end
    end

    class ValueTypeCopyFromMessage < ValueType
      attr_accessor :field_def, :field_name

      def value
        @field_def.findField(@field_name).value
      end
    end

    class ValueTypeCurrentMessage < ValueTypeCopyFromMessage
      define_klass :CURRENT_MESSAGE
    end

    class ValueTypePreviousOutgoing < ValueTypeCopyFromMessage
      define_klass :PREVIOUS_OUTGOING
    end

    class ValueTypePreviousIncoming < ValueTypeCopyFromMessage
      define_klass :PREVIOUS_INCOMING
    end

    class ValueTypeDateTime < ValueType
      define_klass :DATE_TIME
      attr_accessor :format

      def value
        now = Time.now
        now.strftime(@format)
      end
    end # end of ValueTypeSystemGenerateDateTime

    class ValueTypeSeqNo < ValueType
      define_klass :SEQ_NO
      attr_accessor :max

      def initialize(codec = nil)
        super
        @curr_val = 1
        @max = -1
      end

      def max=(max)
        @max = if max.kind_of? Numeric
                 max
               else
                 max.to_i
               end
      end

      def value
        val = @curr_val
        @curr_val = if @max < 0
                      @curr_val + 1
                    elsif @curr_val <= @max
                      @curr_val + 1
                    else
                      1
                    end
        val
      end
    end

    class ValueTypeRandom < ValueType
      @@seed = 0
      define_klass :RANDOM
      attr_accessor :max

      def initialize(codec = nil)
        super
        @gen = Random.new(Time.now.to_i+@@seed)
        @@seed += 1
        @max = 999999
      end

      def max=(max)
        @max = if max.kind_of? Numeric
                 max
               else
                 max.to_i
               end
      end

      def value
        @gen.rand(@max)
      end
    end
  end # end of module Orgsim
end # end of module Simulator

