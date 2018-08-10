require 'test/unit'
require 'simulator'

class TestCharset < Test::Unit::TestCase
  def test_atoe
    charset = Charset.getEbcdicCodec
    assert_equal "\xF0\xF1\xF2\xF3\xF4\xF5\xF6\xF7\xF8\xF9", charset.encode("0123456789")
  end

  def test_etoa
    charset = Charset.getEbcdicCodec
    assert_equal "0123456789", charset.decode("\xF0\xF1\xF2\xF3\xF4\xF5\xF6\xF7\xF8\xF9")
  end
end


