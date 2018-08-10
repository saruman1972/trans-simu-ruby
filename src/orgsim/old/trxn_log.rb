require 'dbi'
require 'simulator'

module Simulator
  module Orgsim
    class DB
      class << self
        attr_accessor :filename

        def dbh
          return @dbh if @dbh
          @dbh = DBI.connect("DBI:SQLite3:#{filename}", "","")
          @dbh['AutoCommit'] = true
          @dbh
        end
      end # end of class << self
    end # end of class DB

    class TrxnLog
      class << self
        attr_accessor :prevOutgoing, :prevIncoming, :logPanel, :fldDefs

        def fldDefs=(fds)
          @fldDefs = fds.clone
        end

        def insert(direction, message)
          if direction == 'O'
            @prevOutgoing = message
          else
            @prevIncoming = message
          end
          DB.dbh.do("insert into LOGS (DIRECTION,TIMESTAMP,MESSAGE) values (?,?,?)", direction, Time.now.to_s, message.hexlify)
          if @fldDefs && @logPanel
            @logPanel.append_text(if direction == 'O'
                                    "Outgoing Message =======>\n"
                                  else
                                    "Incoming Message =======>\n"
                                  end)
            @logPanel.append_text(message.hex_dump)
            @fldDefs.unpack(message)
            log = @fldDefs.dump
            @logPanel.append_text(log)
            @logPanel.append_text("\n")
          end
        end

        def delete(id)
          DB.dbh.do("delete from LOGS where id=#{id}")
        end

        def find(id)
          DB.dbh.select_one("select from LOGS where id=#{id}")
        end

        def loadTrxnLogs
          sth = DB.dbh.execute("select DIRECTION,TIMESTAMP,MESSAGE from LOGS order by TIMESTAMP")
          rows = sth.fetch_all
          sth.finish
          prevOutgoingRow = rows.find {|row| row[:DIRECTION] == 'O'}
          @prevOutgoing = prevOutgoingRow[:MESSAGE].unhexlify if prevOutgoingRow
          prevIncomingRow = rows.find {|row| row[:DIRECTION] = 'I'}
          @prevIncoming = prevIncomingRow[:MESSAGE].unhexlify if prevIncomingRow
          rows
        end
      end # end of class << self
    end # end of class TrxnLog
  end # end of module Orgsim
end # end of module Simulator
