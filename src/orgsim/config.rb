require 'simulator'
begin
    require 'yaml'
rescue LoadError
end

module Simulator
    module Orgsim
        class Config
            class << self
                attr_accessor :filename

                def getConfig
                    @config ||= YAML.load(File.open(@filename))
#@config={"name"=>"VISA vip test", "desc"=>"VISA vip test", "field_def"=>"header.xml", "card_file"=>"card.csv", "acquirer_file"=>"acquirer.csv", "log_file"=>"orgsim.db", "pan_field_name"=>"body.F002", "pan_sn_field_name"=>"body.F023", "zpk"=>"1111111111111111", "communication"=>{"type"=>"DUPLEX_CLIENT", "localPort"=>7403, "lengthCodecStr"=>"LENGTH_BINARY", "lengthLen"=>2, "paddingAfter"=>"\u0000\u0000"}}
                end

                def refresh
                    @config = nil
                end

                def save
                    File.open(@filename, "w") {|f| YAML.dump(@config, f)}
                end
            end
        end # end of class Config
    end # end of module Orgsim
end # end of module Simulator
