require 'test/unit'
require 'simulator'
require 'main_frame'

class TheApp < Wx::App
  def on_init
    f = Simulator::Orgsim::MainFrame.new(nil, -1, "Test Main Frame", Wx::DEFAULT_POSITION, Wx::DEFAULT_SIZE)
    f.show
  end
end

class TestActionEditDialog < Test::Unit::TestCase
  def test_ui_general
    theApp = TheApp.new
    theApp.main_loop
  end
end

