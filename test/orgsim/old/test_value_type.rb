require 'test/unit'
require 'simulator'
require 'value_type'
require 'field_codec'

class TestValueType < Test::Unit::TestCase
  def test_system_generate_get_generator
    gen = Simulator::Orgsim::ValueType::get_instance(:DATE_TIME)
    gen.format = "%H:%M"
    p gen.value

    gen = Simulator::Orgsim::ValueType::get_instance(:RANDOM)
    gen.max = 999999
    p gen.value
    gen = Simulator::Orgsim::ValueType::get_instance(:RANDOM, Simulator::Orgsim::FieldCodec.get_instance('FE_BCD'))
    gen.max = 999999
    p gen.value
  end
end
