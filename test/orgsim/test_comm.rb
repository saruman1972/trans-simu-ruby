require 'test/unit'
require 'simulator'
require 'comm'

class TestComm < Test::Unit::TestCase
  def test_length_pack_ascii
    Simulator::Orgsim::Config.refresh
    Simulator::Orgsim::Communication.refresh
    Simulator::Orgsim::Config.filename = "config.yaml"
    comm = Simulator::Orgsim::Communication.getCommunication
    assert_equal 8, comm.lenCodec.totalLength
    message = "123456"
    assert_equal "88000699", comm.lenCodec.pack(message.length)
    assert_equal 1234, comm.lenCodec.unpack("881234990098934")
  end

  def test_length_pack_binary
    Simulator::Orgsim::Config.refresh
    Simulator::Orgsim::Communication.refresh
    Simulator::Orgsim::Config.filename = "config_binary.yaml"
    comm = Simulator::Orgsim::Communication.getCommunication
    assert_equal 4, comm.lenCodec.totalLength
    message = "123456"
    assert_equal "\x00\x06\x00\x00", comm.lenCodec.pack(message.length)
    assert_equal 4660, comm.lenCodec.unpack("\x12\x34\x000098934")
  end

  def test_duplex_server
    Simulator::Orgsim::Config.refresh
    Simulator::Orgsim::Communication.refresh
    Simulator::Orgsim::Config.filename = "config.yaml"
    comm = Simulator::Orgsim::Communication.getCommunication
#    comm.openComm
  end

  def test_duplex_client
  end

  def test_simplex
  end
end

