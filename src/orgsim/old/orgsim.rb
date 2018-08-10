require 'wx'
require 'simulator'
require 'main_frame'
require 'variable'
require 'config'
require 'data_field'
require 'trxn_log'

module Simulator
  module Orgsim
    class OrgsimApp < Wx::App
      def on_init
        dir = File.join(File.dirname(__FILE__), "institution", "bos2.1")
        Config.filename = File.join(dir, "config.yaml")
        config = Config.getConfig
        Card.filename = File.join(dir, config['card_file'])
        Acquirer.filename = File.join(dir, config['acquirer_file'])
        DB.filename = File.join(dir, "logs", config['log_file'])
TrxnLog.loadTrxnLogs
        cmpd = CompoundField::loadDataFieldConfig(File.join(dir, config['field_def']))
        f = MainFrame.new(nil, -1, "Issuer Testing - #{config['desc']}", Wx::DEFAULT_POSITION, Wx::DEFAULT_SIZE)
        f.fldDefs = cmpd
        TrxnLog.fldDefs = cmpd
        f.show
      end
    end
  end
end

if __FILE__ == $0
  theApp = Simulator::Orgsim::OrgsimApp.new
  theApp.main_loop
end

