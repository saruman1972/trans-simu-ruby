require 'getoptlong'
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
            attr_accessor :inst_dir

            def on_init
                dir = @inst_dir
                Config.filename = File.join(dir, "config.yaml")
                config = Config.getConfig
                Card.filename = File.join(dir, config['card_file'])
                Acquirer.filename = File.join(dir, config['acquirer_file'])
                DB.filename = File.join(dir, "logs", config['log_file'])
                TrxnLog.loadTrxnLogs
                cmpd = CompoundField::load(File.join(dir, config['field_def']))
                f = MainFrame.new(nil, -1, "Issuer Testing - #{config['desc']}", Wx::DEFAULT_POSITION, Wx::DEFAULT_SIZE)
                f.fldDefs = cmpd
                TrxnLog.fldDefs = cmpd
                f.show
            end
        end
    end
end

if __FILE__ == $0
    opts = GetoptLong.new(['--help', '-h', GetoptLong::NO_ARGUMENT],
                          ['--institution', '-i', GetoptLong::REQUIRED_ARGUMENT]
                          )
    dir = nil
    opts.each {|opt, arg|
        case opt
        when '--help'
            puts <<-EOF
Orgsim -h -i <dir>
EOF
            exit(0)
        when '--institution'
            dir = arg
        end
    }
    theApp = Simulator::Orgsim::OrgsimApp.new
    theApp.inst_dir = dir
    theApp.main_loop
end

