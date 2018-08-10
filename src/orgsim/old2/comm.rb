require 'socket'
require 'thread'
require 'timeout'
require 'config'
require 'trxn_log'

module Simulator
  module Orgsim
    class LenCodec
      include DynamicClass
      attr_accessor :paddingAfter, :paddingBefore, :length

      def initialize(len)
        @length = len
        @totalLength = len
        @binary = false
      end

      def binary?
        @binary
      end

      def totalLength
        @totalLength
      end

      def length=(len)
        @length = len
        @totalLength = len
        @totalLength += @paddingBefore.length if @paddingBefore
        @totalLength += @paddingAfter.length if @paddingAfter
      end

      def paddingAfter=(pad)
        @paddingAfter = if binary? 
                          pad.unhexlify
                        else 
                          pad
                        end
        @totalLength = @length+@paddingAfter.length
        @totalLength += @paddingBefore.length if @paddingBefore
      end

      def paddingBefore=(pad)
        @paddingBefore = if binary?
                           pad.unhexlify
                         else
                           pad
                         end
        @totalLength = @length+@paddingBefore.length
        @totalLength += @paddingAfter.length if @paddingAfter
      end

      def pack(len)
        msg = doPack(len)
        msg = @paddingBefore + msg if @paddingBefore
        msg = msg + @paddingAfter if @paddingAfter
        msg
      end

      def unpack(buf)
        buf = buf[@paddingBefore.length..-1] if @paddingBefore
        doUnpack(buf)
      end
    end

    class LenCodec_Ascii < LenCodec
      define_klass :LENGTH_ASCII
      
      def doPack(len)
        "%0*d" % [@length,len]
      end

      def doUnpack(buf)
        buf[0..@length-1].to_i
      end
    end

    class LenCodec_Binary < LenCodec
      define_klass :LENGTH_BINARY

      def binary?
        true
      end

      def doPack(len)
        buf = ''
        while len>0 do
          buf << (len & 0xFF).chr
          len = len >> 8
        end
        buf.lpad("\x00", @length)
      end

      def doUnpack(buf)
        len = 0
        buf[0..@length-1].each_byte do |c|
          len = (len << 8) + c
        end
        len
      end
    end

    class Communication
      include DynamicClass

      @@instances = {}
      class << self
        def refresh
          @@instances = {}
        end

        def getCommunication
          config = Config.getConfig
          config = config['communication']
          raise "missing communication config" unless config
          raise "missing communication type" unless config.has_key? 'type'
          raise "missing lengthLen for communication" unless config.has_key? 'lengthLen'
          raise "missing lengthCodecStr for communication" unless config.has_key? 'lengthCodecStr'
          name = config['type'].to_sym
          @@instances[name] ||= get_instance(name, config['lengthCodecStr'],config['lengthLen'],config['paddingAfter'],config['paddingBefore'])
          inst = @@instances[name]
          config.each do |k,v|
            next if k == 'type' or k == 'lengthCodecStr' or k == 'lengthLen' or k == 'paddingAfter' or k == 'paddingBefore'
            inst.send("#{k}=", v) if inst.respond_to? "#{k}="
          end
          inst
        end
      end # end of class << self

      attr_accessor :localPort, :remoteIP, :remotePort
      attr_reader :lenCodec
      attr_accessor :active
      attr_accessor :sendSock, :recvSock, :timeout
      attr_reader :sendQueue, :recvQueue

      def initialize(lengthCodecStr, lengthLen, paddingAfter=nil, paddingBefore=nil)
        @lenCodec = LenCodec.get_instance(lengthCodecStr.to_sym, lengthLen)
        @lenCodec.paddingAfter = paddingAfter if paddingAfter
        @lenCodec.paddingBefore = paddingBefore if paddingBefore

        @active = false
        @timeout = 1
        @sendQueue = Queue.new
        @recvQueue = Queue.new
        @sendBroken = false
        @recvBroken = false
      end

      def quit
        @active = false
      end

      def sendMessage(message)
        @sendQueue << message
      end

      def recvMessage(timeout=30)
        now = Time.now
        while !(@recvQueue.empty?)
          t, message = @recvQueue.pop
          return message if now.to_i - t.to_i < timeout
        end
        begin
          Timeout.timeout(timeout) {
            t, message = @recvQueue.pop
          }
        rescue
          message = nil
        end
        message
      end

      def sendMessage(message)
        @message = message
        TrxnLog.insert('O', message)
      end

      def recvMessage(timeout=30)
        TrxnLog.insert('I', @message)
        @message
      end

      def readBytes(len, timeout=30)
        message = ''
        while @active && len>0 && timeout > 0
          rl,wl,el = select([@recvSock],nil,nil,@timeout)
          timeout -= 1
          next unless rl
          msg = @recvSock.recv(len)
          message << msg
          len -= msg.len
          timeout -= @timeout
        end
        if len > 0
          # timeout or inactive
          return nil, timeout
        else
          return message, timeout
        end
      end

      def runServerThread
        sock = TCPServer.new(@localPort)
        begin
          while @active
            rl,wl,el = select([sock], nil, nil, @timeout)
            next unless rl
            s = sock.accept
            print "connect by #{s}\n"
            setServerSock(s)

            while @active
              sleep(1)
              break if @recvBroken
            end
            s.close
            clearServerSock
            # wait 2 seconds to synchronize the other thread
            sleep(2)
            clearRecvBrokenEvent
          end
        rescue
          sock.close
        end
        print "communication is down"
      end # end of runServerThread

      def runClientThread
        while @active
          begin
            sock = TCPSocket.new(@remoteIP, @remotePort)
          rescue
            print "connect to #{@remoteIP}:#{@remotePort} timeout\n"
            next
          end

          print "connected to #{sock}"
          setClientSock(sock)

          while @active
            sleep(1)
            break if @sendBroken
          end
          sock.close
          clearClientSock
          # wait 2 seconds to synchronize the other thread
          sleep(2)
          clearSendBrokenEvent
        end
        print "communication is down"
      end # end of runClientThread

      def runSendThread
        while @active && !@sendBroken
          begin
            Timeout.timeout(1) {
              message = @recvQueue.pop
            }
          rescue
            # timeout
            next
          end

          begin
            len = @lenCodec.pack(message.length)
            @sendSock.send(len)
            @sendSock.send(message)
          rescue
            setSendBrokenEvent
            print "broken pipe from send thread\n"
            break
          end # end of begin
        end # end of while
        print "send thread is down\n"
      end # end of runSendThread

      def runRecvThread
        while @active && !@recvBroken
          timeout = 30
          begin
            message,timeout = readBytes(@lenCodec.totalLength, timeout)
            next unless message
            len = @lenCodec.unpack(message)
            message,timeout = readBytes(len, timeout)
            next unless message
          rescue
            print "broken pipe from receive thread\n"
            setRecvBrokenEvent
            break
          end
          @recvQueue << [Time.now, message]
        end # end of while
        print "receive thread is down\n"
      end # end of runRecvThread
    end # end of class Communication
    
    class DuplexCommServer < Communication
      define_klass :DUPLEX_SERVER

      def openComm
        @active = true
        t = Thread.new(self) {|comm|
          comm.runServerThread
        }
        t.join
      end

      def setServerSock(sock)
        @sendSock = sock
        Thread.new(self) {|comm|
          comm.runSendThread
        }
        @recvSock = sock
        Thread.new(self) {|comm|
          comm.runRecvThread
        }
      end

      def clearServerSock
        @sendSock = nil
        @recvSock = nil
      end

      def setSendBrokenEvent
        @sendBroken = true
        @recvBroken = true
      end

      def setRecvBrokenEvent
        @sendBroken = true
        @recvBroken = true
      end

      def clearRecvBrokenEvent
        @sendBroken = false
        @recvBroken = false
      end
    end

    class DuplexCommClient < Communication
      define_klass :DUPLEX_CLIENT

      def openComm
        @active = true
        Thread.new(self) {|comm|
          comm.runClientThread
        }
      end

      def setClientSock(sock)
        @sendSock = sock
        Thread.new(self) {|comm|
          comm.runSendThread
        }
        @recvSock = sock
        Thread.new(self) {|comm|
          comm.runRecvThread
        }
      end

      def clearClientSock
        @sendSock = nil
        @recvSock = nil
      end

      def setSendBrokenEvent
        @sendBroken = true
        @recvBroken = true
      end

      def setRecvBrokenEvent
        @sendBroken = true
        @recvBroken = true
      end

      def clearRecvBrokenEvent
        @sendBroken = false
        @recvBroken = false
      end
    end

    class SimplexComm < Communication
      define_klass :SIMPLEX

      def openComm
        @active = true
        Thread.new(self) {|comm|
          comm.runServerThread
        }
        Thread.new(self) {|comm|
          comm.runClientThread
        }
      end

      def setClientSock(sock)
        @sendSock = sock
        Thread.new(self) {|comm|
          comm.runSendThread
        }
      end

      def clearClientSock
        @sendSock = nil
      end

      def setServerSock(sock)
        @recvSock = sock
        Thread.new(self) {|comm|
          comm.runRecvThread
        }
      end

      def clearServerSock
        @recvSock = nil
      end

      def setSendBrokenEvent
        @sendBroken = true
      end

      def clearSendBrokenEvent
        @sendBroken = false
      end

      def setRecvBrokenEvent
        @recvBroken = true
      end

      def clearRecvBrokenEvent
        @recvBroken = false
      end
    end

  end # end of Orgsim
end # end of Simulator




