require 'simulator'

module Simulator
  module Orgsim
    class LenType
      include DynamicClass
      attr_accessor :charSet

      def initialize(charSet=nil)
        if charSet == nil
          @charSet = Charset.getAsciiCodec
        else
          @charSet = charSet
        end
      end

      def encode(len)
        ''
      end

      def decode(buf, maxPackedLen)
        return maxPackedLen, '', buf
      end

      def fix?
        true
      end
    end

    # dummy class
    class LenType_FIX < LenType
      define_klass :FT_FIXED
    end

    class LenType_LLFIX < LenType_FIX
      define_klass :FT_LLFIX

      def encode(len)
        raise "#{len} is too long for LLVAR" if len > 99
        @charSet.encode("%02d" % len)
      end

      def decode(buf, maxPackedLen)
        len = @charSet.decode(buf[0..1]).to_i
        raise "length[#{len}] is too long, max[#{maxPackedLen}]" if len > maxPackedLen
        return len, buf[0..1], buf[2..-1]
      end
    end

    class LenType_LLLFIX < LenType_FIX
      define_klass :FT_LLLFIX

      def encode(len)
        raise "#{len} is too long for LLLVAR" if len > 999
        @charSet.encode("%03d" % len)
      end

      def decode(buf, maxPackedLen)
        len = @charSet.decode(buf[0..2]).to_i
        raise "length[#{len}] is too long, max[#{maxPackedLen}]" if len > maxPackedLen
        return len, buf[0..2], buf[3..-1]
      end
    end

    class LenType_LLVAR < LenType_FIX
      define_klass :FT_LLVAR

      def encode(len)
        raise "#{len} is too long for LLVAR" if len > 99
        @charSet.encode("%02d" % len)
      end

      def decode(buf, maxPackedLen)
        len = @charSet.decode(buf[0..1]).to_i
        raise "length[#{len}] is too long, max[#{maxPackedLen}]" if len > maxPackedLen
        return len, buf[0..1], buf[2..-1]
      end

      def fix?
        false
      end
    end

    class LenType_LLLVAR < LenType_FIX
      define_klass :FT_LLLVAR

      def encode(len)
        raise "#{len} is too long for LLLVAR" if len > 999
        @charSet.encode("%03d" % len)
      end

      def decode(buf, maxPackedLen)
        len = @charSet.decode(buf[0..2]).to_i
        raise "length[#{len}] is too long, max[#{maxPackedLen}]" if len > maxPackedLen
        return len, buf[0..2], buf[3..-1]
      end

      def fix?
        false
      end
    end

    # variable length, binary BCD digit count
    class LenType_V1VAR < LenType_FIX
      define_klass :FT_V1VAR

      def encode(len)
        raise "#{len} is too long for V1VAR" if len > 15
        len.chr
      end

      def decode(buf, maxPackedLen)
        len = buf[0].org
        raise "length[#{len}] is too long, max[#{maxPackedLen}]" if len > maxPackedLen
        return len, buf[0], buf[1..-1]
      end

      def fix?
        false
      end
    end

    # variable length, binary BCD digit count
    class LenType_V2VAR < LenType_FIX
      define_klass :FT_V2VAR

      def encode(len)
        raise "#{len} is too long for V2VAR" if len > 255
        len.chr
      end

      def decode(buf, maxPackedLen)
        len = buf[0].ord
        raise "length[#{len}] is too long, max[#{maxPackedLen}]" if len > maxPackedLen
        return len, buf[0], buf[1..-1]
      end

      def fix?
        false
      end
    end

    # variable length, binary BCD digit count
    class LenType_V3VAR < LenType_FIX
      define_klass :FT_V3VAR

      def encode(len)
        raise "#{len} is too long for V3VAR" if len > 65535
        (len/255).chr + (len%255).chr
      end

      def decode(buf, maxPackedLen)
        len = buf[0].ord*256 + buf[1].ord
        raise "length[#{len}] is too long, max[#{maxPackedLen}]" if len > maxPackedLen
        return len, buf[0..1], buf[2..-1]
      end

      def fix?
        false
      end
    end

    # variable length, binary BCD digit count
    class LenType_BCD2VAR < LenType_FIX
      define_klass :FT_BCD2VAR

      def encode(len)
        raise "#{len} is too long for BCD2VAR" if len > 99
        ("%02d" % len).unhexlify
      end

      def decode(buf, maxPackedLen)
        len = buf[0].hexlify.to_i
        raise "length[#{len}] is too long, max[#{maxPackedLen}]" if len > maxPackedLen
        return len, buf[0], buf[1..-1]
      end

      def fix?
        false
      end
    end

    # variable length, binary BCD digit count
    class LenType_BCD3VAR < LenType_FIX
      define_klass :FT_BCD3VAR

      def encode(len)
        raise "#{len} is too long for BCD3VAR" if len > 999
        ("%04d" % len).unhexlify
      end

      def decode(buf, maxPackedLen)
        len = buf[0..1].hexlify.to_i
        raise "length[#{len}] is too long, max[#{maxPackedLen}]" if len > maxPackedLen
        return len, buf[0..1], buf[2..-1]
      end

      def fix?
        false
      end
    end

    # tlv length type
    class LenType_FIXTLV < LenType_FIX
      define_klass :FT_FIXTLV

      def encode(len)
        if len > 127
          "\x81" + len.chr
        else
          len.chr
        end
      end

      def decode(buf, maxPackedLen)
        len = buf[0].ord
        if len & 0x80 != 0x00
          ll = len & 0x80
          lb = buf[1..ll]
          len = 0
          lb.each_byte do |b|
            len = len*256 + b
          end
          raise "length[#{len}] is too long, max[#{maxPackedLen}]" if len > maxPackedLen
          return len, buf[0..ll], buf[ll+1..-1]
        else
          raise "length[#{len}] is too long, max[#{maxPackedLen}]" if len > maxPackedLen
          return len, buf[0], buf[1..-1]
        end # end of if len & 0x80
      end  # end of decode
    end

    class LenType_VARTLV < LenType_FIXTLV
      define_klass :FT_VARTLV

      def fix?
        false
      end
    end
  end #end of Orgsim
end # end of Simulator
