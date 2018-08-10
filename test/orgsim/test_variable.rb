require 'test/unit'
require 'simulator'
require 'variable'

class TestVariable < Test::Unit::TestCase
  def test_card
    Simulator::Orgsim::Card.filename = "card.csv"
    print Simulator::Orgsim::Card.columns.to_s + "\n"
    card = Simulator::Orgsim::Card.find(1)
    print card.name+"\n"
    card = Simulator::Orgsim::Card['CARD001']
    print card.id+"\n"
  end

  def test_acquirer
    Simulator::Orgsim::Acquirer.filename = "acquirer.csv"
    print Simulator::Orgsim::Acquirer.columns.to_s + "\n"
    acquirer = Simulator::Orgsim::Acquirer['ATM001']
    print acquirer.mcc+"\n"
  end

  def test_getValue
    Simulator::Orgsim::Card.filename = "card.csv"
    Simulator::Orgsim::Acquirer.filename = "acquirer.csv"
    print Simulator::Orgsim::Variable.getValue('CARD',2,'name')
  end
end
