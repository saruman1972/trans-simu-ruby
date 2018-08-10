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
