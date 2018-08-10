require 'test/unit'
require 'simulator'
require 'security'

class TestSecurity < Test::Unit::TestCase
  include Simulator::Com::Security

  def test_calcMAC
    mac = calcMAC("1111111122222222", "12345678", 8)
    assert_equal "5B9118B41DF8C887".unhexlify, mac
  end
end
