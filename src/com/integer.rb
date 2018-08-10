class Integer
    def to_b
        s = ""
        v = self
        while v != 0
            s = (v & 0xFF).chr + s
            v = v >> 8
        end
        s
    end
end

