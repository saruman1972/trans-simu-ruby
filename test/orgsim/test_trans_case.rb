require 'test/unit'
require 'simulator'
require 'data_field'
require 'trans_case'
require 'variable'
require 'config'
require 'trxn_log'

class TestTransCase < Test::Unit::TestCase
  def test_case_load
    cmpd = Simulator::Orgsim::CompoundField::load('package.xml')
    tc = Simulator::Orgsim::TransCase.load(cmpd, 'sale.xml')
  end

  def test_case_gen_value
    Simulator::Orgsim::DB.filename = "orgsim.db"
    Simulator::Orgsim::Config.filename = "config.yaml"
    Simulator::Orgsim::Card.filename = "card.csv"
    Simulator::Orgsim::Acquirer.filename = "acquirer.csv"
    cmpd = Simulator::Orgsim::CompoundField::load('package.xml')
    tc = Simulator::Orgsim::TransCase.load(cmpd, 'sale.xml')
    cmpd.header.H02 = '01'
    cmpd.header.H04 = '123456'
    cmpd.header.H05 = '13456'
    cmpd.header.H06 = '000000'
    cmpd.header.H07 = '00'
    cmpd.header.H08 = '00'
    cmpd.header.H09 = '00'
    cmpd.header.H10 = '00000'
    cmpd.body.MessageType = "0800"
    cmpd.body.F011 = "000002"
    cmpd.body.F007 = "0817112100"
    cmpd.body.F032 = "03112900"
    cmpd.body.F033 = "03112900"
    Simulator::Orgsim::TrxnLog.prevOutgoing = cmpd.rootPack
    cmpd.clear

#    tc.genValue do |t|
#      t.fldDefs.body.F004 = "1234"
#      t.fldDefs.body.F003 = "020000"
#      t.fldDefs.body.F090.F01 = "0100"
#      t.fldDefs.body.F090.F02 = "0200"
#      t.fldDefs.body.F090.F03 = "0300"
#      t.fldDefs.body.F090.F04 = "0400"
#      t.fldDefs.body.F090.F05 = "0500"
#    end
#    print cmpd.dump
    print "start time:#{Time.now}-#{Time.now.tv_usec}\n"
    message = tc.runCase
    print "end time:#{Time.now}-#{Time.now.tv_usec}\n"
 #   print message.hex_dump
 #   cmpd.clear
 #   cmpd.unpack(message)
 #   print cmpd.dump
  end
end
