require 'test/unit'
require 'simulator'
require 'trans_case'
require 'ui'

class TheApp < Wx::App
  def on_init
    Simulator::Orgsim::Card.filename = "card.csv"
    Simulator::Orgsim::Acquirer.filename = "acquirer.csv"
    cmpd = Simulator::Orgsim::CompoundField::load('package.xml')
    tc = Simulator::Orgsim::TransCase.load(cmpd, 'sale.xml')
    ui = Simulator::Orgsim::UIDesc.load('sale_action_outgoing.xml', tc.actions[0])
    p ui.doUI
    print tc.fldDefs.dump
    false
  end
end

class TestActionEditDialog < Test::Unit::TestCase
  def test_load
    uiDesc = Simulator::Orgsim::UIDesc.load('sale_action_outgoing.xml',nil)
  end

  def test_ui_general
    theApp = TheApp.new
    theApp.main_loop
  end
end

