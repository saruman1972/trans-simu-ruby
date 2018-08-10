require 'test/unit'
require 'simulator'
require 'data_field'

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

  def test_loadDataFieldConfig
    cmpd = Simulator::Orgsim::CompoundField.loadDataFieldConfig('package.xml')
  end

  def test_pack
    cmpd = Simulator::Orgsim::CompoundField.loadDataFieldConfig('package.xml')
    cmpd.MessageType = '0200'
    cmpd.F002 = '4026740012345678'
    cmpd.F052 = "\x01\x02\x03\x04\x05\x06\x07\x08"
    cmpd.F090.value = '1234567890ABCDEF1234567890ABCDEF'
#    cmpd.F090.F01 = '0100'
    cmpd.F048.CardActivation.F01 = '1'
    cmpd.F048.CardActivation.F02 = '12345678'
    cmpd.F048.CardActivation.F03 = '1201'
    cmpd.F055.tag9F03 = '1234'
    message = cmpd.pack
    print message.hex_dump
    print cmpd.dump
    cmpd.clear
    cmpd.unpack(message)
    print cmpd.dump
  end

  def test_message_header
    cmpd = Simulator::Orgsim::CompoundField.loadDataFieldConfig('header.xml')
#    cmpd.H01 = ''
#    cmpd.H03 = ''
    cmpd.H02 = '01'
    cmpd.H04 = '1234567890'
    cmpd.H05 = '1234567890'
    cmpd.H06 = '000001'
    cmpd.H07 = '01'
    cmpd.H08 = 'H08'
    cmpd.H09 = '01'
    cmpd.H10 = '000'
    cmpd.body.MessageType = '0200'
    cmpd.body.F002 = '4026740012345678'
    cmpd.body.F052 = "\x01\x02\x03\x04\x05\x06\x07\x08"
    cmpd.body.F090.value = '1234567890ABCDEF1234567890ABCDEF'
    message = cmpd.pack
    print message.hex_dump
  end

  def test_unpack
    cmpd = Simulator::Orgsim::CompoundField.loadDataFieldConfig('header.xml')
#    cmpd.H01 = ''
#    cmpd.H03 = ''
    cmpd.H02 = '01'
    cmpd.H04 = '1234567890'
    cmpd.H05 = '1234567890'
    cmpd.H06 = '000001'
    cmpd.H07 = '01'
    cmpd.H08 = 'H08'
    cmpd.H09 = '01'
    cmpd.H10 = '000'
    cmpd.body.MessageType = '0200'
    cmpd.body.F002 = '4026740012345678'
    cmpd.body.F049 = '156'
    cmpd.body.F052 = "\x01\x02\x03\x04\x05\x06\x07\x08"
    cmpd.body.F090.value = '1234567890ABCDEF1234567890ABCDEF'
    message = cmpd.pack
    cmpd.clear
    assert_equal nil, cmpd.H02
    assert_equal nil, cmpd.H04
    assert_equal nil, cmpd.H05
    assert_equal nil, cmpd.H06
    assert_equal nil, cmpd.H07
    assert_equal nil, cmpd.H08
    assert_equal nil, cmpd.H09
    assert_equal nil, cmpd.H10
    assert_equal nil, cmpd.body.MessageType
    assert_equal nil, cmpd.body.F002
    assert_equal nil, cmpd.body.F052
    assert_equal nil, cmpd.body.F090.value
    cmpd.unpack(message)
    assert_equal "\x2e", cmpd.H01
    assert_equal '01', cmpd.H02
#    assert_equal '0134', cmpd.H03
    assert_equal '1234567890 ', cmpd.H04
    assert_equal '1234567890 ', cmpd.H05
    assert_equal '000001', cmpd.H06
    assert_equal '01', cmpd.H07
    assert_equal 'H08     ', cmpd.H08
    assert_equal '01', cmpd.H09
    assert_equal '00000', cmpd.H10
    assert_equal '0200', cmpd.body.MessageType
    assert_equal true, cmpd.body.bitmap.isset?(2)
    assert_equal true, cmpd.body.bitmap.isset?(52)
    assert_equal true, cmpd.body.bitmap.isset?(90)
    assert_equal '4026740012345678', cmpd.body.F002
    assert_equal "\x01\x02\x03\x04\x05\x06\x07\x08", cmpd.body.F052
    assert_equal "1234567890ABCDEF1234567890ABCDEF          ", cmpd.body.F090.value

    print cmpd.dump
    print cmpd.hex_dump
  end


end

