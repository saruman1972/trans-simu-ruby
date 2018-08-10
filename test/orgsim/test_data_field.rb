require 'test/unit'
require 'simulator'
require 'data_field'
require 'config'

class TestDataField < Test::Unit::TestCase
  def test_compound_field_operator
    cmpd = Simulator::Orgsim::CompoundField.new
    fld = Simulator::Orgsim::DataField.new
    fld.name = "F01"
    cmpd << fld
    fld = Simulator::Orgsim::DataField.new
    fld.name = "F02"
    cmpd << fld
    fld = Simulator::Orgsim::DataField.new
    fld.name = "F05"
    cmpd << fld

    assert_equal "F01", cmpd["F01"].name
    assert_equal "F02", cmpd["F02"].name
    assert_equal "F05", cmpd["F05"].name

    flds = []
    cmpd.each do |fld|
      flds << fld
    end
    assert_equal "F01", flds[0].name
    assert_equal "F02", flds[1].name
    assert_equal "F05", flds[2].name

    flds[0].value = 'jones'
    assert_equal 'jones', cmpd.F01
    cmpd.F02 = 'andy'
    assert_equal 'andy', flds[1].value

    cpd1 = Simulator::Orgsim::CompoundField.new
    fld = Simulator::Orgsim::DataField.new
    fld.name = "H01"
    cpd1 << fld
    cpd1.name = "CMPD"
    cmpd << cpd1
    fld.value = 'judi'
    assert_equal 'judi', cmpd.CMPD.H01

    fld = Simulator::Orgsim::DataField.new
    fld.name = "H05"
    cpd1 << fld
    cmpd.CMPD.H05 = 'foster'
    assert_equal 'foster', fld.value

    fld = Simulator::Orgsim::DataField.new
    fld.name = "F01"
    cpd1 << fld
    fld.value = 'jackie'
    assert_equal 'jackie', cmpd.CMPD.F01
    assert_equal 'jones', cmpd.F01

    dupCmpd = cmpd.clone
    dupCmpd.F02 = 'james'
    assert_equal 'james', dupCmpd.F02
    assert_equal 'andy', cmpd.F02
    dupCmpd.CMPD.F01 = 'allen'
    assert_equal 'jackie', cmpd.CMPD.F01
    assert_equal 'allen', dupCmpd.CMPD.F01
  end

  def test_load
    Simulator::Orgsim::Config.filename = "config.yaml"
    cmpd = Simulator::Orgsim::CompoundField.load('package.xml')
  end

  def test_pack
    Simulator::Orgsim::Config.filename = "config.yaml"
    config = Simulator::Orgsim::Config.getConfig
    config['body_only'] = true
    cmpd = Simulator::Orgsim::CompoundField.load('package.xml')
    cmpd.body.MessageType = '0200'
    cmpd.body.F002 = '4026740012345678'
    cmpd.body.F052 = "\x01\x02\x03\x04\x05\x06\x07\x08"
    cmpd.body.F090.value = '1234567890ABCDEF1234567890ABCDEF'
#    cmpd.F090.F01 = '0100'
    cmpd.body.F048.CardActivation.F01 = '1'
    cmpd.body.F048.CardActivation.F02 = '12345678'
    cmpd.body.F048.CardActivation.F03 = '1201'
    cmpd.body.F055.tag9F03 = '1234'
    message = cmpd.rootPack
    print message.hex_dump
    print cmpd.dump
    cmpd.clear
    cmpd.rootUnpack(message)
    print cmpd.dump
  end

  def test_message_header
    Simulator::Orgsim::Config.filename = "config.yaml"
    config = Simulator::Orgsim::Config.getConfig
    config['body_only'] = false
    cmpd = Simulator::Orgsim::CompoundField.load('package.xml')
#    cmpd.H01 = ''
#    cmpd.H03 = ''
    cmpd.header.H02 = '01'
    cmpd.header.H04 = '1234567890'
    cmpd.header.H05 = '1234567890'
    cmpd.header.H06 = '000001'
    cmpd.header.H07 = '01'
    cmpd.header.H08 = 'H08'
    cmpd.header.H09 = '01'
    cmpd.header.H10 = '000'
    cmpd.body.MessageType = '0200'
    cmpd.body.F002 = '4026740012345678'
    cmpd.body.F052 = "\x01\x02\x03\x04\x05\x06\x07\x08"
    cmpd.body.F090.value = '1234567890ABCDEF1234567890ABCDEF'
    cmpd.body.F048.FS.F00 = 'FS'
    cmpd.body.F048.FS.F01 = '0100'
    cmpd.body.F048.FS.F02 = '0200'
    cmpd.body.F048.FS.F03 = '0300'
    cmpd.body.F048.FS.F04 = '0400'
    cmpd.body.F048.FS.F05 = '0500'
    cmpd.body.F048.FS.F06 = '0600'
    cmpd.body.F048.FS.F07 = '0700'
    cmpd.body.F048.FS.F08 = '0800'
    cmpd.body.F048.FS.F09 = '0900'
    cmpd.body.F048.FS.F10 = '1000'
    cmpd.body.F048.FS.F11 = '1100'
    cmpd.body.F048.FS.F12 = '1200'
    message = cmpd.rootPack
    print message.hex_dump
  end

  def test_unpack
    Simulator::Orgsim::Config.filename = "config.yaml"
    config = Simulator::Orgsim::Config.getConfig
    config['body_only'] = false
    cmpd = Simulator::Orgsim::CompoundField.load('package.xml')
#    cmpd.H01 = ''
#    cmpd.H03 = ''
    cmpd.header.H02 = '01'
    cmpd.header.H04 = '1234567890'
    cmpd.header.H05 = '1234567890'
    cmpd.header.H06 = '000001'
    cmpd.header.H07 = '01'
    cmpd.header.H08 = 'H08'
    cmpd.header.H09 = '01'
    cmpd.header.H10 = '000'
    cmpd.body.MessageType = '0200'
    cmpd.body.F002 = '4026740012345678'
    cmpd.body.F049 = '156'
    cmpd.body.F052 = "\x01\x02\x03\x04\x05\x06\x07\x08"
    cmpd.body.F090.value = '1234567890ABCDEF1234567890ABCDEF'
    cmpd.body.F048.FS.F00 = 'FS'
    cmpd.body.F048.FS.F01 = '0100'
    cmpd.body.F048.FS.F02 = '0200'
    cmpd.body.F048.FS.F03 = '0300'
    cmpd.body.F048.FS.F04 = '0400'
    cmpd.body.F048.FS.F05 = '0500'
    cmpd.body.F048.FS.F06 = '0600'
    cmpd.body.F048.FS.F07 = '0700'
    cmpd.body.F048.FS.F08 = '0800'
    cmpd.body.F048.FS.F09 = '0900'
    cmpd.body.F048.FS.F10 = '1000'
    cmpd.body.F048.FS.F11 = '1100'
    cmpd.body.F048.FS.F12 = '1200'
    message = cmpd.rootPack
    cmpd.clear
    assert_equal nil, cmpd.header.H02
    assert_equal nil, cmpd.header.H04
    assert_equal nil, cmpd.header.H05
    assert_equal nil, cmpd.header.H06
    assert_equal nil, cmpd.header.H07
    assert_equal nil, cmpd.header.H08
    assert_equal nil, cmpd.header.H09
    assert_equal nil, cmpd.header.H10
    assert_equal nil, cmpd.body.MessageType
    assert_equal nil, cmpd.body.F002
    assert_equal nil, cmpd.body.F052
    assert_equal nil, cmpd.body.F090.value
    cmpd.rootUnpack(message)
    assert_equal "\x2e", cmpd.header.H01
    assert_equal '01', cmpd.header.H02
#    assert_equal '0134', cmpd.H03
    assert_equal '1234567890 ', cmpd.header.H04
    assert_equal '1234567890 ', cmpd.header.H05
    assert_equal '000001', cmpd.header.H06
    assert_equal '01', cmpd.header.H07
    assert_equal 'H08     ', cmpd.header.H08
    assert_equal '01', cmpd.header.H09
    assert_equal '00000', cmpd.header.H10
    assert_equal '0200', cmpd.body.MessageType
    assert_equal true, cmpd.body.bitmap.isset?(2)
    assert_equal true, cmpd.body.bitmap.isset?(52)
    assert_equal true, cmpd.body.bitmap.isset?(90)
    assert_equal '4026740012345678', cmpd.body.F002
    assert_equal "\x01\x02\x03\x04\x05\x06\x07\x08", cmpd.body.F052
    assert_equal "1234567890ABCDEF1234567890ABCDE0000000000F", cmpd.body.F090.value

    print message.hex_dump
    print cmpd.dump
    print cmpd.hex_dump
  end


end

