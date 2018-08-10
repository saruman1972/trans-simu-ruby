require 'simulator'
require 'security'

module Simulator
  module Orgsim
    class PackHook
      include DynamicClass
      attr_accessor :fld
    end # end of class PackHook

    class PackHookPIN < PackHook
      define_klass :PIN
      include Com::Security
      attr_accessor :pinblock_format

      def initialize
        @pinblock_format = Com::Security::PINBLOCK_FORMAT_01
      end

      def pack(value)
        config = Config.getConfig()
        pan_field_name = config['pan_field_name']
        raise "pan_field_name missing from config file" unless pan_field_name
        pan = @fld.action.fldDefs.findField(pan_field_name).value
        zpk = config['zpk']
        raise "zpk missing from config file" unless zpk
        makePINBlock(zpk.unhexlify, pan, value, pinblock_format)
      end
    end # end of class PackHookPIN

    class PackHookARQC < PackHook
      define_klass :ARQC
      include Com::Security

      def pack(value)
        config = Config.getConfig()
        tag_list = config['ac_tags']
        raise "tag list for arqc missing from config file" unless tag_list
        tags = tag_list.split ','
        mk_ac = config['mk_ac']
        raise "mk_ac missing from config file" unless mk_ac
        pan_field_name = config['pan_field_name']
        raise "pan_field_name missing from config file" unless pan_field_name
        pan = @fld.action.fldDefs.findField(pan_field_name).value
        pan_sn_field_name = config['pan_sn_field_name']
        raise "pan_sn_field_name missing from config file" unless pan_sn_field_name
        pan_sn = @fld.action.fldDefs.findField(pan_sn_field_name).value
        ic_field_name = config['ic_field_name']
        raise "ic_field_name missing from config file" unless ic_field_name
        ic_field = @fld.action.fldDefs.findField(ic_field_name)
        df = @fld.action.fldDefs.findField("#{ic_field_name}.tag9F36")
        df.pack(0)
        atc = df.packedValue
        genAC(mk_ac.unhexlify, pan, pan_sn, atc, ic_field, tags)
      end
    end # end of class PackHookARQC

  end # end of module Orgsim
end # end of module Simulator
