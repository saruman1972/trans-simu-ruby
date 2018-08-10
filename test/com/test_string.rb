require 'test/unit'
require 'simulator'

class TestString < Test::Unit::TestCase
  def test_hexlify
    assert_equal "0102030405060708", "\x01\x02\x03\x04\x05\x06\x07\x08".hexlify
  end

  def test_unhexlify
    assert_equal "\x01\x02\x03\x04\x05\x06\x07\x08", "0102030405060708".unhexlify
  end

  def test_to_bcd
    assert_equal "\x15\x6f", "156".to_bcd
    assert_equal "\x15\x6f\xff\xff\xff", "156".to_bcd(10)
  end

  def test_from_bcd
    assert_equal "156", "\x15\x6f\xff".from_bcd
  end

  def test_to_bc0
    assert_equal "\x01\x56", "156".to_bc0
    assert_equal "\x00\x00\x00\x01\x56", "156".to_bc0(10)
  end

  def test_from_bc0
    assert_equal "0000000156", "\x00\x00\x00\x01\x56".from_bc0
    assert_equal "156", "\x00\x00\x00\x01\x56".from_bc0(3)
    assert_equal "000000000156", "\x00\x00\x00\x01\x56".from_bc0(12)
  end

  def test_hex_dump
    print "\n"
    print "\xFF\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x01\x0234ABCDabcd".hex_dump
    print "\x01\x02\x03\x04".hex_dump
  end
end

