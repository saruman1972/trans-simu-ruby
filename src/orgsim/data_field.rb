# -*- coding: gb2312 -*-
require 'simulator'
require 'len_type'
require 'field_codec'
require 'value_type'
require 'config'

module Simulator
    module Orgsim
        class DataField
            attr_accessor :name, :desc, :index, :codec, :lenType, :size, :charSet
            # offset - in packed buffer
            attr_accessor :value, :packedValue, :lenStr, :packedValueWithLength, :offset, :generator
            attr_accessor :parent, :sub, :subHash, :activeSub

            def initialize(parent=nil, charSet=nil)
                @parent = parent
                if charSet == nil
                    @charSet = Charset.getAsciiCodec
                else
                    @charSet = charSet
                end
                @activeSub = nil        # 打包的过程中，用于标记哪个子域被赋值了
            end

            def forwardReference?
                false
            end

            def clear
                @value = nil
                @packedValue = nil
                @lenStr = nil
                @packedValueWithLength = nil
                @offset = nil
                if @sub
                    @sub.each {|cmpd| cmpd.clear}
                end
                @activeSub = nil
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
                    @sub.each {|v| klone << v.clone}
                end
                klone
            end

            def getEffectiveSubField()
                if @sub.length == 1
                    @sub[0]
                else
                    @activeSub
                end
            end

            def packData(offset=0)
                if @sub && @sub.length > 0
                    subField = getEffectiveSubField()
                    @value = if subField 
                                 subField.pack(offset)
                             else
                                 @value
                             end
                end

                if @value == nil && @generator
                    # 系统生成的字段
                    @value = @generator.value
                end
                
                raise "field[#{fullname}] is null" unless @value

                if @lenType.fix?
                    @codec.encode(@value, @size)
                else
                    @codec.encode(@value)
                end
            end

            def pack(offset=0)
                @offset = offset
                @packedValue = packData(offset)
                if @lenType
                    @lenStr = @lenType.encode(if @value; @value.length; else 0 end, @packedValue.length)
                    @packedValueWithLength = @lenStr + @packedValue
                else
                    @lenStr = ''
                    @packedValueWithLength = @packedValue
                end

                @packedValueWithLength
            end

            def unpackData(buf, len, lenByte)
                pv = buf[0..lenByte-1]
                return @codec.decode(pv, len), pv, buf[lenByte..-1]
            end

            def unpack(buf)
                raise "empty message for field[#{fullname}]" unless buf && buf.length>0
                if @lenType
                    len,lenByte,lenStr,buf = @lenType.decode(buf, @size, @codec)
                    if lenByte > 0
                        raise "empty message for field[#{fullname}]" unless buf && buf.length>0
                        @value,@packedValue,buf = unpackData(buf, len, lenByte)
                    else
                        @packedValue = ''
                        @value = ''
                    end
                    @packedValueWithLength = lenStr + @packedValue

                    if @sub && @sub.length > 0
                        subField = getEffectiveSubField()
                        if subField
                            subField.unpack(@packedValue)
                        else
                            @sub.each {|cmpd|
                                next unless cmpd.indicator
                                begin
                                    cmpd.unpack(@packedValue)
                                    if cmpd.indicator.value == cmpd.indicator.generator.value
                                        @activeSub = cmpd
                                        break
                                    end
                                rescue
                                    nil
                                end # end of begin
                            }
                        end # endo of if subField
                    end # end of if @sub && @sub.length > 0
                else      # compound field without length field
                    @value,@packedValue,buf = unpackData(buf, -1, -1)
                    @packedValueWithLength = @packedValue
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
                if @sub && @sub.length > 0
                    subField = getEffectiveSubField()
                    if subField
                        s << subField.dump
                    else
                        @sub.each {|cmpd|
                            if cmpd.indicator && cmpd.indicator.value && cmpd.indicator.value == cmpd.indicator.generator.value
                                s << cmpd.dump
                                break
                            end
                        }
                    end # end of if subField
                end
                s
            end

            def hex_dump
                s = if @packedValueWithLength == nil || @name == nil || @codec == nil
                        ''
                    else
                        "#{fullname} = [#{@packedValueWithLength.hexlify}]\n"
                    end
                if @sub && @sub.length > 0
                    subField = getEffectiveSubField()
                    if subField
                        s << subField.hex_dump
                    else
                        @sub.each {|cmpd|
                            if cmpd.indicator && cmpd.indicator.value && cmpd.indicator.value == cmpd.indicator.generator.value
                                s << cmpd.hex_dump
                                break
                            end
                        }
                    end # end of if subField
                end
                s
            end
        end

        class LengthField < DataField
            attr_accessor :start, :term    # start-从哪个域开始算长度，term-到那个域结束长度（无值的话表示长度一直算到报文结束）

            def initialize(parent, charSet, start, term=nil)
                super(parent, charSet)
                @start = start
                @term = term
            end

            def forwardReference?
                true
            end

            def packData(offset=0)
                @value ||= ''
                super
            end

            def repackField(root, totalLen)
                fldStart = root.findField(@start)
                len = if @term
                          fldTerm = root.findField(@term)
                          fldTerm.offset - fldStart.offset
                      else
                          totalLen - fldStart.offset
                      end
                if @codec.binary?
                    # turn into network byte nibble
                    @value = len.to_b
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

            def packData(offset=0)
                if @size < 64
                    val = @bits.collect {|c| c.chr} .join
                else
                    val = ''
                    hasExtend = true
                    @bits.each_slice(8) do |bs|
                        break unless hasExtend
                        val << bs.collect {|c| c.chr} .join
                        hasExtend = ((bs[0] & 0x80) != 0x00)
                    end
                    val
                end
            end

            def unpackData(buf, len, lenByte)
                buf.force_encoding('ASCII-8BIT')
                if @size >= 64
                    @bits = (buf[0..7]).split(//).collect {|c| c.ord}
                    if (@bits[0] & 0x80) != 0x00
                        @bits += (buf[8..15]).split(//).collect {|c| c.ord}
                        @bits += (buf[16..23]).split(//).collect {|c| c.ord} if (@bits[8]& 0x80) != 0x00
                    end
                    pv = buf[0..@bits.length-1]
                    return pv, pv, buf[@bits.length..-1]
                else
                    @bits = (buf[0..@bytes-1]).split(//).collect {|c| c.ord}
                    pv = buf[0..@bytes-1]
                    return pv, pv, buf[@bytes..-1]
                end
            end

            def dump
                "#{fullname} = #{collect do |idx| idx end}\n"
            end

        end # end of BitmapField

        class CompoundField < DataField
            include Enumerable
            attr_accessor :flds, :fldHash, :fwrdRfrs, :indicator

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
                @packedValueWithLength = nil
                @offset = nil
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

            def rootPack         # calling from action...
                config = Config.getConfig
                if config['body_only']
                    bodyName = config['body_field_name']
                    raise "body field name missing from config" unless bodyName
                    body = findField(bodyName)
                    raise "invalid body field name [#{bodyName}]" unless body
                    val = body.pack(0)
                else
                    val = pack(0)
                end
                repack(val)
            end

            def rootUnpack(buf)
                config = Config.getConfig
                cond =  config['eval_body_cond']
                if cond && eval(cond)
                    bodyName = config['body_field_name']
                    raise "body field name missing from config" unless bodyName
                    body = findField(bodyName)
                    raise "invalid body field name [#{bodyName}]" unless body
                    body.unpack(buf)
                else
                    unpack(buf)
                end
            end

            def repack(buf)
                @fwrdRfrs.each do |fld|
                    next unless fld.offset    # 不打包header时，这些域的offset不会赋值，也没必要repack
                    left = if fld.offset==0 
                               ''
                           else
                               buf[0..fld.offset-1]
                           end
                    right = if fld.offset+fld.packedValueWithLength.length > buf.length
                                ''
                            else
                                buf[fld.offset+fld.packedValueWithLength.length..-1]
                            end
                    buf = left + fld.repackField(self, buf.length) + right
                end
                buf
            end

            def findField(name)
                @flds.each do |fld|
                    f = fld.findField(name)
                    return f if f
                end
                if fullname == name
                    self
                else
                    nil
                end
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
                    # comment for clone, cause instance methods will be cloned along
                    #          raise "duplicated name[#{fld.fullname}]" if self.respond_to? fld.name
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
                        instance_eval "def #{fld.name}=(val); #{hashName}['#{fld.name}'].value=val; end"
                    end # end of fld.kind_of?
                end # end of if isDefaultName? fld.name
            end # end of define_attr
        end # end of DataField

        class BitmapPackage < CompoundField
            attr_accessor :bitmap

            def packData(offset=0)
                pv = ''
                @bitmap.each do |index|
                    val = @fldHash[index].pack(offset)
                    pv << val
                    offset += val.length
                end # end of bitmap.each
                pv
            end # end of pack

            def unpackData(buf, len, lenByte)
                if lenByte > 0     # 子域的情况，已经知道长度
                    pv = buf[0..lenByte-1]
                    buf = buf[lenByte..-1]
                    tmp = pv
                    @bitmap.each {|index| tmp = @fldHash[index].unpack(tmp)}
                else
                    oldBuf = buf
                    buf.force_encoding('ASCII-8BIT')
                    @bitmap.each {|index| buf = @fldHash[index].unpack(buf)}
                    pv = oldBuf[0..oldBuf.length-buf.length-1]
                end
                return pv, pv, buf
            end
        end # end of BitmapPackage

        class PatternPackage < CompoundField
            attr_accessor :omitChars

            def omitChars=(chars)
                @omitChars ||= ''
                @omitChars << chars.gsub(/\\x..|./) {|c|
                    if c.length > 1
                        [c[2..3]].pack("H*")
                    else
                        c
                    end
                }
                @omitRegexp = Regexp.new("[#{@omitChars}]*$")
            end

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

            def packData(offset=0)
                pv = ''
                @flds.each do |fld|
                    fld.value = '' if fld.value == nil && @omitChars     # 对于VISA44域之类的，子域内容为空的情况下，需要填充，最后的空子域删除
                    val = fld.pack(offset)
                    pv << val
                    offset += val.length
                end
                if @omitChars
                    pv.gsub!(@omitRegexp, '')
                end
                pv
            end

            def unpackData(buf, len, lenByte)
                buf.force_encoding('ASCII-8BIT')
                if lenByte > 0     # 子域的情况，已经知道长度
                    pv = buf[0..lenByte-1]
                    buf = buf[lenByte..-1]
                    tmp = pv
                    @flds.each {|fld| 
                        break if (tmp == nil || tmp.length == 0) && @omitChars
                        tmp = fld.unpack(tmp)
                    }
                else
                    oldBuf = buf
                    @flds.each {|fld| buf = fld.unpack(buf)}
                    pv = if buf
                             oldBuf[0..oldBuf.length-buf.length-1]
                         else
                             oldBuf
                         end
                end
                return pv, pv, buf
            end
        end # end of PatternPackage

        class TLVPackage < CompoundField
            def pack_tags
                @pack_tags.inject([]) {|s,t| s << t.hexlify}
            end

            def pack_tags=(tags)
                @pack_tags = tags.inject([]) {|s,t| s << t.unhexlify}
            end

            def packData(offset=0)
                pv = ''
                @pack_tags.each do |tag|
                    fld = @fldHash[tag]
                    if fld && fld.value
                        pv << tag
                        offset += fld.tag.length
                        val = fld.pack(offset)
                        pv << val
                        offset += val.length
                    end
                end
                pv
            end

            def unpackData(buf, len, lenByte)
                pv = buf
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
                return pv, pv, buf
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

                if @parent && @parent.parent && @parent.parent.instance_of?(DataField)
                    # subfield
                    @parent.parent.activeSub = @parent
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

                def load(filename)
                    @fwrdRfrs = []
                    root = loadDataFieldConfig(filename, nil, :PATTERN_PACKAGE)
                    root.fwrdRfrs = @fwrdRfrs
                    @fwrdRfrs = nil

                    # validate length field forward reference
                    root.fwrdRfrs.each do |f|
                        raise "undefined forward refrence[#{f.start}] for [#{f.name}]" unless root.findField(f.start)
                        if f.term
                            raise "undefined forward refrence[#{f.term}] for [#{f.name}]" unless root.findField(f.term)
                        end
                    end

                    root
                end

                def loadDataFieldConfig(filename, parent, type)
                    @dirname = File.dirname(filename)
                    input = File.new(filename)
                    doc = Document.new(input)
                    root = doc.root
                    input.close

                    if root.attributes.has_key?('char_set')
                        charSet = if root.attribute('char_set').value.upcase == 'EBCDIC'
                                      Charset.getEbcdicCodec
                                  else
                                      Charset.getAsciiCodec
                                  end
                    elsif parent
                        charSet = parent.charSet
                    else
                        charSet = Charset.getAsciiCodec
                    end

                    loadCompoundField(root, charSet, parent, type)
                end

                def loadCompoundField(node, charSet, parent, type)
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
                        fld = makeField(cmpd, elm, charSet)
                        cmpd << fld
                        @fwrdRfrs << fld if fld.forwardReference?
                    end # end of doc.elements.each

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

                        if node.attributes.has_key?('omit_char') # 用于设定子域的忽略字符，适用于VISA44域的情况
                            fld.omitChars = node.attribute('omit_char').value
                        end

                        if node.name == 'sub_fields' # 用于设定子域的指示字段，适用于银联48域的情况
                            if node.attributes.has_key?('indicator')
                                fld.indicator = fld[node.attribute('indicator').value]
                                raise "invalidate indicator[#{node.attribute('indicator').value}]" unless fld.indicator
                            end
                        end

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
                                if e.attributes.has_key? 'use_value_length'
                                    fld.lenType.use_value_length = if e.attribute('use_value_length').value.upcase == 'TRUE'
                                                                       true
                                                                   else
                                                                       false
                                                                   end
                                end
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

