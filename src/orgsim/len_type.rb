# -*- coding: gb2312 -*-
require 'simulator'

module Simulator
    module Orgsim
        class LenType
            include DynamicClass
            attr_accessor :charSet, :use_value_length

            def initialize(charSet=nil)
                if charSet == nil
                    @charSet = Charset.getAsciiCodec
                else
                    @charSet = charSet
                end
                @use_value_length = false
            end

            # len - pack之前变量的长度
            # lenByte - pack之后变量的长度（字节长度）
            def encode(len, lenByte)
                ''
            end

            def decode(buf, maxLen, codec)
                if @use_value_length
                    return maxLen, '', buf
                else
                    return maxLen, codec.packedLength(maxLen), '', buf
                end
            end

            def fix?
                true
            end

            def use_value_length?
                @use_value_length
            end
        end

        # dummy class
        class LenType_FIX < LenType
            define_klass :FT_FIXED
        end

        class LenType_LLFIX < LenType_FIX
            define_klass :FT_LLFIX

            def encode(len, lenByte)
                raise "#{len} is too long for LLVAR" if len > 99
                @charSet.encode("%02d" % lenByte)
            end

            def decode(buf, maxLen, codec)
                len = @charSet.decode(buf[0..1]).to_i
                if @use_value_length
                    raise "length[#{len}] is too long, max[#{maxLen}]" if len > maxLen
                    return len, codec.packedLength(len), buf[0..1], buf[2..-1]
                else
                    raise "length[#{len}] is too long, max[#{codec.packedLength(maxLen)}]" if len > codec.packedLength(maxLen)
                    return len, len, buf[0..1], buf[2..-1]
                end
            end
        end

        class LenType_LLLFIX < LenType_FIX
            define_klass :FT_LLLFIX

            def encode(len, lenByte)
                raise "#{len} is too long for LLLVAR" if len > 999
                @charSet.encode("%03d" % lenByte)
            end

            def decode(buf, maxLen, codec)
                len = @charSet.decode(buf[0..2]).to_i
                if @use_value_length
                    raise "length[#{len}] is too long, max[#{maxLen}]" if len > maxLen
                    return len, codec.packedLength(len), buf[0..2], buf[3..-1]
                else
                    raise "length[#{len}] is too long, max[#{codec.packedLength(maxLen)}]" if len > codec.packedValue(maxLen)
                    return len, len, buf[0..2], buf[3..-1]
                end
            end
        end

        class LenType_LLVAR < LenType_FIX
            define_klass :FT_LLVAR

            def encode(len, lenByte)
                raise "#{len} is too long for LLVAR" if len > 99
                @charSet.encode("%02d" % lenByte)
            end

            def decode(buf, maxLen, codec)
                len = @charSet.decode(buf[0..1]).to_i
                if @use_value_length
                    raise "length[#{len}] is too long, max[#{maxLen}]" if len > maxLen
                    return len, codec.packedLength(len), buf[0..1], buf[2..-1]
                else
                    raise "length[#{len}] is too long, max[#{codec.packedLength(maxLen)}]" if len > codec.packedLength(maxLen)
                    return len, len, buf[0..1], buf[2..-1]
                end
            end

            def fix?
                false
            end
        end

        class LenType_LLLVAR < LenType_FIX
            define_klass :FT_LLLVAR

            def encode(len, lenByte)
                raise "#{len} is too long for LLLVAR" if len > 999
                @charSet.encode("%03d" % lenByte)
            end

            def decode(buf, maxLen, codec)
                len = @charSet.decode(buf[0..2]).to_i
                if @use_value_length
                    raise "length[#{len}] is too long, max[#{maxLen}]" if len > maxLen
                    return len, codec.packedLength(len), buf[0..2], buf[3..-1]
                else
                    raise "length[#{len}] is too long, max[#{codec.packedLength(maxLen)}]" if len > codec.packedLength(maxLen)
                    return len, len, buf[0..2], buf[3..-1]
                end
            end

            def fix?
                false
            end
        end

        # 没有长度位的边长域，占据从当前位置开始一直到报文结束的长度
        class LenType_ALLVAR < LenType_FIX
            define_klass :FT_ALLVAR

            def encode(len, lenByte)
                ''
            end

            def decode(buf, maxLen, codec)
                len = buf.length
                if @use_value_length
                    return len, codec.packedLength(len), '', buf
                else
                    return len, len, '', buf
                end
            end

            def fix?
                false
            end
        end

        # variable length, binary BCD digit count
        class LenType_V1VAR < LenType_FIX
            define_klass :FT_V1VAR

            def encode(len, lenByte)
                raise "#{len} is too long for V1VAR" if len > 15
                if @use_value_length
                    len.chr
                else
                    lenByte.chr
                end
            end

            def decode(buf, maxLen, codec)
                len = buf[0].ord
                if @use_value_length
                    raise "length[#{len}] is too long, max[#{maxLen}]" if len > maxLen
                    return len, codec.packedLength(len), buf[0], buf[1..-1]
                else
                    raise "length[#{len}] is too long, max[#{codec.packedLength(maxLen)}]" if len > codec.packedLength(maxLen)
                    return len, len, buf[0], buf[1..-1]
                end
            end

            def fix?
                false
            end
        end

        # variable length, binary BCD digit count
        class LenType_V2VAR < LenType_FIX
            define_klass :FT_V2VAR

            def encode(len, lenByte)
                raise "#{len} is too long for V2VAR" if len > 255
                if @use_value_length
                    len.chr
                else
                    lenByte.chr
                end
            end

            def decode(buf, maxLen, codec)
                len = buf[0].ord
                if @use_value_length
                    raise "length[#{len}] is too long, max[#{maxLen}]" if len > maxLen
                    return len, codec.packedLength(len), buf[0], buf[1..-1]
                else
                    raise "length[#{len}] is too long, max[#{codec.packedLength(maxLen)}]" if len > codec.packedLength(maxLen)
                    return len, len, buf[0], buf[1..-1]
                end
            end

            def fix?
                false
            end
        end

        # variable length, binary BCD digit count
        class LenType_V3VAR < LenType_FIX
            define_klass :FT_V3VAR

            def encode(len, lenByte)
                raise "#{len} is too long for V3VAR" if len > 65535
                if @use_value_length
                    (len/255).chr + (len%255).chr
                else
                    (lenByte/255).chr + (lenByte%255).chr
                end
            end

            def decode(buf, maxLen, codec)
                len = buf[0].ord*256 + buf[1].ord
                if @use_value_length
                    raise "length[#{len}] is too long, max[#{maxLen}]" if len > maxLen
                    return len, len, buf[0..1], buf[2..-1]
                else
                    raise "length[#{len}] is too long, max[#{codec.packedLength(maxLen)}]" if len > codec.packedLength(maxLen)
                    return len, len, buf[0..1], buf[2..-1]
                end
            end

            def fix?
                false
            end
        end

        # variable length, binary BCD digit count
        class LenType_BCD2VAR < LenType_FIX
            define_klass :FT_BCD2VAR

            def encode(len, lenByte)
                raise "#{len} is too long for BCD2VAR" if len > 99
                if @use_value_length
                    ("%02d" % len).unhexlify
                else
                    ("%02d" % lenByte).unhexlify
                end
            end

            def decode(buf, maxLen, codec)
                len = buf[0].hexlify.to_i
                if @use_value_length
                    raise "length[#{len}] is too long, max[#{maxLen}]" if len > maxLen
                    return len, codec.packedLength(len), buf[0], buf[1..-1]
                else
                    raise "length[#{len}] is too long, max[#{codec.packedLength(maxLen)}]" if len > codec.packedLength(maxLen)
                    return len, len, buf[0], buf[1..-1]
                end
            end

            def fix?
                false
            end
        end

        # variable length, binary BCD digit count
        class LenType_BCD3VAR < LenType_FIX
            define_klass :FT_BCD3VAR

            def encode(len, lenByte)
                raise "#{len} is too long for BCD3VAR" if len > 999
                if @use_value_length
                    ("%04d" % len).unhexlify
                else
                    ("%04d" % lenByte).unhexlify
                end
            end

            def decode(buf, maxLen, codec)
                len = buf[0..1].hexlify.to_i
                if @use_value_length
                    raise "length[#{len}] is too long, max[#{maxLen}]" if len > maxLen
                    return len, codec.packedLength(len), buf[0..1], buf[2..-1]
                else
                    raise "length[#{len}] is too long, max[#{codec.packedLength(maxLen)}]" if len > codec.packedLength(maxLen)
                    return len, len, buf[0..1], buf[2..-1]
                end
            end

            def fix?
                false
            end
        end

        # tlv length type
        class LenType_FIXTLV < LenType_FIX
            define_klass :FT_FIXTLV

            def encode(len, lenByte)
                if @use_value_length
                    if len > 127
                        "\x81" + len.chr
                    else
                        len.chr
                    end
                else
                    if lenByte > 127
                        "\x81" + lenByte.chr
                    else
                        lenByte.chr
                    end
                end
            end

            def decode(buf, maxLen, codec)
                len = buf[0].ord
                if len & 0x80 != 0x00
                    ll = len & 0x80
                    lb = buf[1..ll]
                    len = 0
                    lb.each_byte do |b|
                        len = len*256 + b
                    end
                else
                    ll = 0
                end # end of if len & 0x80

                raise "length[#{len}] is too long, max[#{maxLen}]" if len > codec.packedLength(maxLen)
                unpackedLength = codec.unpackedLength(len)
                unpackedLength = maxLen if unpackedLength > maxLen  # 对于curr_cd这样的情况，maxLen为3，len为2，需要取最小值3
                return unpackedLength, len, buf[0..ll], buf[ll+1..-1]
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
