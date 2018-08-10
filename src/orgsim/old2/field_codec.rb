require 'simulator'

module Simulator
  module Orgsim
    class FieldCodec
      include DynamicClass
      attr_accessor :charSet

      def initialize(charSet=nil)
        if charSet == nil
          @charSet = Charset.getAsciiCodec
        else
          @charSet = charSet
        end
      end

      def binary?
        false
      end

      def numeric?
        false
      end

      def packedLength(len)
        len
      end

      def unpackedLength(len)
        len
      end
    end

    class FieldCodec_A < FieldCodec
      define_klass :FE_A

      def encode(var, len=-1)
        if len < 0
          @charSet.encode(var)
        else
          @charSet.encode(var.rpad(' ', len))
        end
      end

      def decode(buf, len=-1)
        @charSet.decode(buf)
      end
    end

    class FieldCodec_N < FieldCodec
      define_klass :FE_N

      def numeric?
        true
      end

      def encode(var, len=-1)
        if len < 0
          @charSet.encode(var)
        else
          @charSet.encode(var.lpad('0', len))
        end
      end

      def decode(buf, len=-1)
        @charSet.decode(buf)
      end
    end

    class FieldCodec_S < FieldCodec_A
      define_klass :FE_S
    end

    class FieldCodec_AN < FieldCodec_A
      define_klass :FE_AN
    end

    class FieldCodec_AS < FieldCodec_A
      define_klass :FE_AS
    end

    class FieldCodec_NS < FieldCodec_A
      define_klass :FE_NS
    end

    class FieldCodec_ANS < FieldCodec_A
      define_klass :FE_ANS
    end

    class FieldCodec_B < FieldCodec_A
      define_klass :FE_B

      def encode(var, len=-1)
        if len < 0
          var
        else
          var.rpad("\x00", len)
        end
      end

      def decode(buf, len=-1)
        buf
      end

      def binary?
        true
      end

    end

    class FieldCodec_B0 < FieldCodec_A
      define_klass :FE_B0

      def encode(var, len=-1)
        if len < 0
          var
        else
          var.lpad("\x00", len)
        end
      end

      def decode(buf, len=-1)
        buf
      end

      def binary?
        true
      end

    end

    class FieldCodec_BHX < FieldCodec
      define_klass :FE_BHX

      def encode(var, len=-1)
        var.to_bc0(len)
      end

      def decode(buf, len=-1)
        buf.hexlify
      end

      def packedLength(len)
        (len-1)/2+1
      end

      def unpackedLength(len)
        len*2
      end
    end

    class FieldCodec_BCD < FieldCodec
      define_klass :FE_BCD

      def encode(var, len=-1)
        var.to_bcd(len)
      end

      def decode(buf, len=-1)
        buf.from_bcd
      end

      def numeric?
        true
      end

      def packedLength(len)
        (len-1)/2+1
      end

      def unpackedLength(len)
        len*2
      end
    end

    class FieldCodec_BC0 < FieldCodec
      define_klass :FE_BC0

      def encode(var, len=-1)
        var.to_bc0(len)
      end

      def decode(buf, len=-1)
        buf.from_bc0(len)
      end

      def numeric?
        true
      end

      def packedLength(len)
        (len-1)/2+1
      end

      def unpackedLength(len)
        len*2
      end
    end

    # (C-Credit/D-Debit) + number
    class FieldCodec_X < FieldCodec
      define_klass :FE_X

      def encode(var, len=-1)
        if len < 0
          @charSet.encode(var)
        else
          @charSet.encode(var[0] + var[1..-1].lpad('0',len-1))
        end
      end

      def decode(buf, len=-1)
        @charSet.decode(buf)
      end
    end

    class FieldCodec_BCX < FieldCodec
      define_klass :FE_BCX

      def encode(var, len=-1)
        @charSet.encode(var[0]) + var[1..-1].to_bcd(len-1)
      end

      def decode(buf, len=-1)
        sign = @charSet.decode(buf[0])
        sign+buf[1..-1].from_bcd
      end

      def packedLength(len)
        1+(len-1-1)/2+1
      end

      def unpackedLength(len)
        1+(len-1)*2
      end
    end

    class FieldCodec_BCZ < FieldCodec
      define_klass :FE_BCZ

      def encode(var, len=-1)
        var.gsub(/[^0-9]/,'d').to_bcd(len)
      end

      def decode(buf, len=-1)
        buf.from_bcd.gsub(/[dD]/,'=')
      end

      def packedLength(len)
        (len-1)/2+1
      end

      def unpackedLength(len)
        len*2
      end
    end

    class FieldCodec_BZ0 < FieldCodec
      define_klass :FE_BZ0

      def encode(var, len=-1)
        var.gsub(/[^0-9]/,'d').to_bc0(len)
      end

      def decode(buf, len=-1)
        buf.from_bc0(len).gsub(/[dD]/, '=')
      end

      def packedLength(len)
        (len-1)/2+1
      end

      def unpackedLength(len)
        len*2
      end
    end

    # track data
    class FieldCodec_Z < FieldCodec
      define_klass :FE_Z

      def encode(var, len=-1)
        if len < 0
          @charSet.encode(var.gsub(/[^0-9]/,'='))
        else
          @charSet.encode(var.gsub(/[^0-9]/,'=').rpad('=', len))
        end
      end

      def decode(buf, len=-1)
        @charSet.decode(buf).gsub(/d/,'=')
      end
    end

  end # end of module Orgsim
end # end of module Simulator
