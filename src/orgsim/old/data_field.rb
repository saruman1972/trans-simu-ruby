require 'simulator'
require 'len_type'
require 'field_codec'
require 'value_type'

module Simulator
  module Orgsim
    class DataField
      attr_accessor :name, :desc, :index, :codec, :lenType, :size, :charSet
      # offset - in packed buffer
      attr_accessor :value, :packedValue, :offset, :generator
      attr_accessor :parent, :sub, :subHash

      def initialize(parent=nil, charSet=nil)
        @parent = parent
        if charSet == nil
          @charSet = Charset.getAsciiCodec
        else
          @charSet = charSet
        end
      end

      def forwardReference?
        false
      end

      def clear
        @value = nil
        @packedValue = nil
        @offset = 0
        if @sub
          @sub.each {|cmpd| cmpd.clear}
        end
      end

      def <<(cmpd)
        @sub ||= []
        @sub << cmpd
        @subHash ||= {}
        @subHash[cmpd.name] = cmpd if cmpd.name
        @subHash[cmpd.index] = cpmd if cmpd.index
        define_attr(cmpd)
        cmpd.parent = self
      end

      def clone
        klone = super
        if @sub
          klone.sub = []
          klone.subHash = {}
          @sub.each {|v| 
            klone << v.clone
          }
        end
        klone
      end

      def pack(offset)
        @offset = offset
        return '' unless @value  # this is for evalParent
        dataStr = if @lenType.fix?
                    @codec.encode(@value, @size)
                  else
                    @codec.encode(@value)
                  end
        lenStr = @lenType.encode(dataStr.length)
        @packedValue = lenStr + dataStr
      end

      def unpack(buf)
        raise "empty message for field[#{fullname}]" unless buf && buf.length>0
        len,lenStr,buf = @lenType.decode(buf, @codec.packedLength(@size))
        if len > 0
          raise "empty message for field[#{fullname}]" unless buf && buf.length>0
          @value = @codec.decode(buf[0..len-1])
          buf = buf[len..-1]
        else
          @value = ''
        end
        @packedValue = lenStr + @value

        if @sub && @sub.length == 1
          @sub[0].unpack(@value)
        end

        buf
      end

      def fullname
        return @fullname if @fullname
        p = @parent
        @fullname = @name
        while p do
          @fullname = "#{p.name}." + @fullname unless p.name == nil || p.isDefaultName?(p.name)
          p = p.parent
        end
        @fullname
      end

      def findField(name)
        return self if name == fullname
        if @sub
          @sub.each do |s|
            fld = s.findField(name)
            return fld if fld
          end
        end
        return nil
      end

      def fullnameList
        return [[fullname,desc]] unless @sub
        @sub.inject([[fullname,desc]]) {|s,sub| s = s + sub.fullnameList}
      end

      def dump
        s = if @value == nil
              ''
            elsif @codec.binary?
              "#{fullname} = [#{@value.hexlify}]\n"
            else
              "#{fullname} = [#{@value}]\n"
            end
        if @sub && @sub.length == 1
          s << @sub[0].dump
        end
        s
      end

      def hex_dump
        s = if @packedValue == nil || @name == nil || @codec == nil
              ''
            else
              "#{fullname} = [#{@packedValue.hexlify}]\n"
            end
        if @sub && @sub.length == 1
          s << @sub[0].hex_dump
        end
        s
      end
    end

    class LengthField < DataField
      attr_accessor :start, :term

      def initialize(parent, charSet, start, term=nil)
        super(parent, charSet)
        @start = start
        @term = term
      end

      def clear
        super
        @value = ''
      end

      def forwardReference?
        true
      end

      def pack(offset)
        @value ||= ''
        super
      end

      def repack
        len = if @term
                 @parent[@term].offset
              else
                 @parent.offset + @parent.packedValue.length
              end - @parent[@start].offset
        if @codec.binary?
          # turn into network byte nibble
          if len > 255
            @value = (len/256).chr + (len%256).chr
          else
            @value = len.chr
          end
        else
          @value = "%d" % len
        end
        pack(@offset)
      end
    end

    class TLVField < DataField
      attr_accessor :tag
    end

    class BitmapField < DataField
      include Enumerable
      attr_accessor :bits

      def initialize(parent=nil, size=192)
        super(parent)
        @size = size
        @bytes = size/8
        @bits = [0x00]*@bytes
      end

      def bytes
        @bytes
      end

      def clone
        klone = super
        klone.bits = @bits.clone
        klone
      end

      def to_a
        bita = []
        @bits.each do |c|
          mask = 0x80
          8.times do |i|
            bita << if c & mask
                      1
                    else
                      0
                    end
          end # end of 8.times
        end # end of @bits.each_byte
      end

      def from_a(bita)
        @bits = []
        bita.each_slice(8) do |bs|
          c = 0x00
          mask = 0x80
          bs.each do |b|
            c |= mask if b == 1
            mask >>= 1
          end
          @bits << c
        end
        @bits
      end

      def set(index)
        raise "invalid index[#{index}] for bitmap, size[#{@size}]" if index > @size or index <= 0
        index -= 1
        @bits[index/8] |= (0x80 >> (index%8))
        if index >= 64
          @bits[0] |= 0x80
        end
        if index >= 128
          @bits[8] |= 0x80
        end
      end # end of set

      def unset(index)
        raise "invalid index[#{index}] for bitmap, size[#{@size}]" if index > @size
        index -= 1
        @bits[index/8] &= (0xFF^(0x80 >> (index%8)))
        if index >= 128
          @bits[8] &= 0x7f if @bits[16..-1].inject(0) {|sum,v| sum+v} == 0
        end
        if index >= 64
          @bits[0] &= 0x7f if @bits[0..-1].inject(0) {|sum,v| sum+v} == 0
        end
      end

      def isset?(index)
        raise "invalid index[#{index}] for bitmap, size[#{@size}]" if index > @size
        index -= 1
        (@bits[index/8] & (0x80 >> (index%8))) != 0x00
      end

      def clear
        @bits = [0x00]*@bytes
      end

      def each
        index = 1
        @bits.each do |c|
          mask = 0x80
          8.times do |i|
            yield(index) if (((c & mask)!=0x00) && ((@size < 64) || (index != 1 && index != 65 && index != 129)))
            mask >>= 1
            index += 1
          end
        end
      end

      def pack(offset)
        @offset = offset
        if @size < 64
          @packedValue = @bits.collect {|c| c.chr} .join
        else
          @packedValue = ''
          hasExtend = true
          @bits.each_slice(8) do |bs|
            break unless hasExtend
            @packedValue << bs.collect {|c| c.chr} .join
            hasExtend = ((bs[0] & 0x80) != 0x00)
          end
          @packedValue
        end
      end

      def unpack(buf)
        buf.force_encoding('ASCII-8BIT')
        if @size >= 64
          @bits = (buf[0..7]).split(//).collect {|c| c.ord}
          if (@bits[0] & 0x80) != 0x00
            @bits += (buf[8..15]).split(//).collect {|c| c.ord}
            @bits += (buf[16..23]).split(//).collect {|c| c.ord} if (@bits[8]& 0x80) != 0x00
          end
          @packedValue = buf[0..@bits.length-1]
          buf[@bits.length..-1]
        else
          @bits = (buf[0..@bytes-1]).split(//).collect {|c| c.ord}
          @packedValue = buf[0..@bytes-1]
          buf[@bytes..-1]
        end
      end

      def dump
        "#{fullname} = #{collect do |idx| idx end}\n"
      end

    end # end of BitmapField

    class CompoundField < DataField
      include Enumerable
      attr_accessor :flds, :fldHash, :fwrdRfrs

      def initialize(parent=nil, charSet=nil)
        super
        @flds = []
        @fldHash = {}
        @fwrdRfrs = []
      end

      def clear
        @flds.each do |fld|
          fld.clear
        end
        @value = nil
        @packedValue = nil
        @offset = 0
      end

      def [](idx)
        @fldHash[idx]
      end

      def []=(idx, fld)
        @fldHash[idx] = val
      end

      def <<(fld)
        @flds << fld
        @fldHash[fld.name] = fld
        @fldHash[fld.index] = fld if fld.index
        @fldHash[fld.tag] = fld if fld.respond_to? :tag
        # no name compound field, no need for sub access methods
        define_attr(fld) unless isDefaultName? name

        if fld.forwardReference?
          @fwrdRfrs << fld
        end
        fld.parent = self
      end

      def clone
        klone = super
        if @flds
          klone.flds = []
          klone.fldHash = {}
          klone.fwrdRfrs = []
          @flds.each {|v| 
            klone << v.clone
          }
        end
        klone
      end

      def length
        @flds.length
      end

      def each
        @flds.each do |fld|
          yield(fld)
        end
      end

      def dump
        @flds.inject('') {|s,fld| s + fld.dump}
      end

      def hex_dump
        @flds.inject('') {|s,fld| s + fld.hex_dump}
      end

      def repack(buf)
        @fwrdRfrs.each do |fld|
          left = if fld.offset==0 
                   ''
                 else
                   buf[0..fld.offset-1]
                 end
          right = if fld.offset+fld.packedValue.length > buf.length
                    ''
                  else
                    buf[fld.offset+fld.packedValue.length..-1]
                  end
          buf = left + fld.repack + right
        end
        buf
      end

      def findField(name)
        @flds.each do |fld|
          f = fld.findField(name)
          return f if f
        end
        return nil
      end

      def fullnameList
        @flds.inject([]) {|sum,fld| sum = sum + fld.fullnameList}
      end
    end # end of class CompoundField

    class DataField
      def isDefaultName?(name)
        name =~ /^__FIELD_[0-9]+__$/
      end

      def define_attr(fld, indirect=nil)
        if isDefaultName?(fld.name)
          if fld.kind_of? CompoundField
            fld.each {|f| define_attr(f, fld.name)}
          end
        else
#          raise "duplicated name[#{name}]" if self.respond_to? fld.name
          hashName = if @sub
                       if indirect
                         "@subHash['#{indirect}']"
                       else
                         '@subHash'
                       end
                     else
                       if indirect
                         "@fldHash['#{indirect}']"
                       else
                         '@fldHash'
                       end
                     end
          if fld.kind_of?(CompoundField) || fld.kind_of?(BitmapField) || fld.sub
            instance_eval "def #{fld.name}; #{hashName}['#{fld.name}']; end"
          else
            instance_eval "def #{fld.name}; #{hashName}['#{fld.name}'].value; end"
            evalStr = if indirect
                        if @sub
                          "evalSelf; "
                        end
                      else
                        if @parent && @parent.sub
                          "evalParent; "
                        end
                      end
            instance_eval "def #{fld.name}=(val); #{hashName}['#{fld.name}'].value=val; #{evalStr} end"
          end # end of fld.kind_of?
        end # end of if isDefaultName? fld.name
      end # end of define_attr

      def evalSelf
        return unless @sub && @sub.length == 1
        @value = @sub[0].pack
      end

      def evalParent
        return unless @parent && @parent.sub
        @parent.value = pack
      end
    end

    class BitmapPackage < CompoundField
      attr_accessor :bitmap

      def pack(offset=0)
        @offset = offset
        @packedValue = ''
        @bitmap.each do |index|
          val = @fldHash[index].pack(offset)
          @packedValue << val
          offset += val.length
        end # end of bitmap.each
        # fix forward reference
        repack(@packedValue)
      end # end of pack

      def unpack(buf)
        oldBuf = buf
        buf.force_encoding('ASCII-8BIT')
        @bitmap.each do |index|
          buf = @fldHash[index].unpack(buf)
        end
        @packedValue = oldBuf[0..oldBuf.length-buf.length-1]
        buf
      end
    end # end of BitmapPackage

    class PatternPackage < CompoundField
      def clone
        klone = super
        # reset bitmap reference
        klone.flds.each do |fld|
          if fld.kind_of? BitmapPackage
            fld.bitmap = klone.fldHash[fld.bitmap.name]
          end
        end
        klone
      end

      def pack(offset=0)
        @offset = offset
        @packedValue = ''
        @flds.each do |fld|
          val = fld.pack(offset)
          @packedValue << val
          offset += val.length
        end
        # fix forward reference
        repack(@packedValue)
      end

      def unpack(buf)
        oldBuf = buf
        buf.force_encoding('ASCII-8BIT')
        @flds.each do |fld|
          buf = fld.unpack(buf)
        end
        @packedValue = if buf
                         oldBuf[0..oldBuf.length-buf.length-1]
                       else
                         oldBuf
                       end
        buf
      end
    end # end of PatternPackage

    class TLVPackage < CompoundField
      def pack_tags
        @pack_tags.inject([]) {|s,t| s << t.hexlify}
      end

      def pack_tags=(tags)
        @pack_tags = tags.inject([]) {|s,t| s << t.unhexlify}
      end

      def pack(offset=0)
        @offset = offset
        @packedValue = ''
        @pack_tags.each do |tag|
          fld = @fldHash[tag]
          if fld && fld.value
            @packedValue << tag
            offset += fld.tag.length
            val = fld.pack(offset)
            @packedValue << val
            offset += val.length
          end
        end
        @packedValue
      end

      def unpack(buf)
        @packedValue = buf
        buf.force_encoding('ASCII-8BIT')
        while buf.length > 0
          tag = buf[0]
          if buf[0].ord & 0x1F == 0x1F      # lower 5 nibble all '1', means tag name span 2 bytes
            tag = buf[0..1]
            buf = buf[2..-1]
          else
            tag = buf[0]
            buf = buf[1..-1]
          end
          unless @fldHash[tag]     # unknown tag, create a new tag definition
            fld = TLVField.new(self, self.charSet)
            fld.name = "tag#{tag.hexlify}"
            fld.tag = tag
            fld.codec = FieldCodec.get_instance('FE_B')
            fld.lenType = LenType.get_instance('FT_VARTLV')
            fld.size = 999
            fld.desc = 'unknown'
            self << fld
          end
          fld = @fldHash[tag]
          buf = fld.unpack(buf)
        end
        ''
      end
    end

    class DataField
      def value=(value)
        return (@value = nil) unless value

        if value.kind_of? String
          @value = value
        elsif value.kind_of? Integer
          if @codec.binary?
            @value = value.to_b
          else
            @value = value.to_s
          end
        else
          raise "unsupport value type [#{value.class}]"
        end

        if @sub && @sub.length == 1
          @sub[0].unpack(@value)
        end
        setBitmapFlag
      end

      def setBitmapFlag
        return unless @parent
        if @parent.kind_of? BitmapPackage
          @parent.bitmap.set(@index)
        end
        @parent.setBitmapFlag
      end
    end

    class CompoundField
      @@defaultNameIdx = 0

      # class methods for load config
      class << self
        require 'rexml/document'
        include REXML

        attr_accessor :dirname

        def getDefaultName
          @@defaultNameIdx += 1
          "__FIELD_%06d__" % @@defaultNameIdx
        end

        def loadDataFieldConfig(filename, parent=nil, type=:PATTERN_PACKAGE)
          @dirname = File.dirname(filename)
          input = File.new(filename)
          doc = Document.new(input)
          root = doc.root
          input.close

          charSet = Charset.getAsciiCodec
          if root.attributes.has_key?('char_set') && root.attribute('char_set').value.upcase == 'EBCDIC'
            charSet = Charset.getEbcdicCodec
          end

          loadCompoundField(root, charSet, parent, type)
        end

        def loadCompoundField(node, charSet, parent, type=:PATTERN_PACKAGE)
          cmpd = case type
                 when :PATTERN_PACKAGE
                   PatternPackage.new(parent, charSet)
                 when :BITMAP_PACKAGE
                   BitmapPackage.new(parent, charSet)
                 when :TLV_PACKAGE
                   raise "pack_tags missing for TLV_PACKAGE" unless node.attributes.has_key? 'pack_tags'
                   c = TLVPackage.new(parent, charSet)
                   c.pack_tags = node.attribute('pack_tags').value.split(',')
                   c
                 else
                   PatternPackage.new(parent, charSet)
                 end

          node.elements.each("field") do |elm|
            cmpd << makeField(cmpd, elm, charSet)
          end # end of doc.elements.each

          # validate length field forward reference
          cmpd.fwrdRfrs.each do |f|
            raise "undefined forward refrence[#{f.start}] for [#{f.name}]" unless cmpd[f.start]
            if f.term
              raise "undefined forward refrence[#{f.term}] for [#{f.name}]" unless cmpd[f.term]
            end
          end

          cmpd
        end # end of loadCompoundField

        def makeField(parent, node, charSet)
          elem = node.elements.find {|e| e.name == 'tag'}
          tag = if elem
                  elem.text.strip
                end
          name = if node.attributes.has_key? 'name'
                   node.attribute('name').value
                 else
                   elem = node.elements.find {|e| e.name == 'name'}
                   if elem
                     elem.text.strip
                   elsif node.name == 'sub_fields'
                     getDefaultName
                   elsif tag
                     "tag#{tag}"
                   else
#                     raise 'field missing name' unless elem
                     getDefaultName
                   end
                 end
          type = if node.attributes.has_key?('type')
                   node.attribute('type').value.upcase
                 elsif node.name == 'sub_fields'
                   'PATTERN_PACKAGE'
                 else
                   'SIMPLE'
                 end
          if type == 'BITMAP_PACKAGE' ||
             type == 'PATTERN_PACKAGE' ||
             type == 'TLV_PACKAGE'
            # load compound field
            fld = if node.attributes.has_key? 'field_def'
                    filename = File.join(@dirname, node.attribute('field_def').value)
                    loadDataFieldConfig(filename, parent, type.to_sym)
                  else
                    loadCompoundField(node, charSet, parent, type.to_sym)
                  end
            raise "load compound field [#{name}] failed" unless fld
            raise "compound field[#{name}] has no fields" unless fld.length > 0

            if type == 'BITMAP_PACKAGE'
              raise "bitmap_package[#{name}] has no bitmap associated" unless node.attributes.has_key? 'bitmap'
              fld.bitmap = parent[node.attribute('bitmap').value]
              raise "can't find bitmap[#{node.attribute('bitmap').value}]" unless fld.bitmap
            end
          elsif type == 'BITMAP'
            size = node.elements.find {|e| e.name == 'size'}
            raise 'bitmap[#{name}] field missing size' unless size
            fld = BitmapField.new(parent, size.text.to_i)
          elsif type == 'LENGTH'
            raise 'length field[#{name}] missing start attr' unless node.attributes.has_key? 'start'
            start = node.attribute('start').value
            term = if node.attributes.has_key? 'end'
                     node.attribute('end').value
                   else
                     nil
                   end
            fld = LengthField.new(parent, charSet, start, term)
          elsif tag
            fld = TLVField.new(parent, charSet)
            fld.tag = tag.unhexlify
          else
            fld = DataField.new(parent, charSet)
          end
          fld.name = name

          setFieldAttr(fld, node, charSet)
          healthCheck(fld)

          fld
        end # end of makeField

        def setFieldAttr(fld, node, charSet)
          node.elements.each do |e|
            case e.name
              when 'index'
                fld.index = e.text.to_i
              when 'desc'
                fld.desc = e.text.strip
              when 'description'
                fld.desc = e.text.strip
              when 'field_encode'
                begin
                  fld.codec = FieldCodec.get_instance(e.text.strip, charSet)
                rescue
                  raise "undefined field encode[#{e.text.strip}] in field[#{name}]"
                end
              when 'field_type'
                begin
                  fld.lenType = LenType.get_instance(e.text.strip, charSet)
                rescue
                  raise "undefined field type[#{e.text.strip}] in field[#{name}]"
                end
              when 'size'
                fld.size = e.text.to_i
              when 'sub_fields'
                fld << makeField(fld, e, charSet)
              when 'generator'
                raise "generator name missing in field[#{fld.name}]" unless e.attributes.has_key? 'name'
                begin
                  fld.generator = ValueType.get_instance(e.attribute('name').value.upcase.to_sym, fld.codec)
                  loadGenerator(fld.generator, e)
                rescue
                  raise "undefined generator[#{e.attribute('name').value}] for field[#{fld.name}]"
                end
            end # end of case
          end # end of node.elements.each
        end # end of setFieldAttr

        def loadGenerator(generator,node)
          node.elements.each("property") do |e|
            raise "property name missing" unless e.attributes.has_key? 'name'
            value = if e.attributes.has_key? 'value'
                      e.attribute('value').value
                    else
                      e.text.strip
                    end
            generator.send("#{e.attribute('name').value}=", value)
          end
        end

        def healthCheck(fld)
          # health check
          if fld.instance_of? TLVField
            unless fld.lenType.kind_of?(LenType_FIXTLV) || fld.lenType.kind_of?(LenType_VARTLV)
              raise "invalid field_type[#{fld.lenType}] for TLV field[#{tag}]"
            end
          end

          fld
        end # end of healthCheck

      end # end of singleton

    end # end of class Compound

  end # end of module Orgsim
end # end of module Simulator

