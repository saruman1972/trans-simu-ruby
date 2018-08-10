
class String

    def rpad(c, len)
        if len > self.length
            self + c*(len-self.length)
        else
            self[0..(len-1)]
        end
    end

    def lpad(c, len)
        if len > self.length
            s = c*(len-self.length) + self
        else
            s = self[-len..(self.length-1)]
        end
    end

    def hexlify
        unpack("H*")[0]
    end

    def unhexlify
        s = ''
        unpack("C*").each_slice(2) {|a| s << a.pack("C2").to_i(16).chr}
        s
    end

    def to_bcd(len = -1)
        # right padding with 'F'
        if len < 0
            len = self.length
        end
        if len % 2 == 1
            len = len + 1
        end

        s = rpad('F',len)
        s.unhexlify
    end

    def from_bcd()
        self.hexlify.gsub(/f*$/, '')
    end

    def to_bc0(len = -1)
        # left padding with '0'
        if len < 0
            len = self.length
        end
        if len % 2 == 1
            len = len + 1
        end
        s = lpad('0', len) 
        s.unhexlify
    end

    def from_bc0(len=-1)
        s = self.hexlify
        if s.length > len
            s[-len..-1]
        else
            s
        end
    end

    def to_bhx(len = -1)
        s = self.hexlify
        if len < 0
            s
        else
            s.rpad('0', len)
        end
    end

    def from_bhx(len = -1)
        s = self.unhexlify
    end

    def hex_dump
        force_encoding("ASCII-8BIT")
        s = ''
        offset = 0
        split(//).each_slice(16) do |sl|
            s << ("%04x: " % offset)
            left = sl[0..7]
            right = sl[8..-1]
            left.each do |c|
                s << ("%02x " % c.ord)
            end
            (8-left.length).times do |i|
                s << '   '
            end
            s << ' '
            if right
                right.each do |c|
                    s << ("%02x " % c.ord)
                end
                (8-right.length).times do |i|
                    s << '   '
                end
            else
                s << '   '*8
            end
            s << ' ; '
            sl.each do |c|
                s << if c.ord >= 0x20 and c.ord < 0x80
                         c
                     else
                         '.'
                     end
            end
            s << "\n"
            offset += 16
        end
        s
    end

    def each_slice(len)
        ((length+len-1) / len).times {|i|
            yield self[i*len .. (i+1)*len-1]
        }
    end
end
