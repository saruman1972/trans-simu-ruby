require 'openssl'
require 'simulator'

module Simulator
  module Com
    module Security
      class Des
        def initialize(key)
          raise "invalid key length[#{key.hexlify}], should be 8" unless key.length == 8
          @key = key
          @cipher = OpenSSL::Cipher.new("DES")
        end

        def encrypt(data)
          raise "invalid data length[#{data.hexlify}], should be divided by 8" unless data.length % 8 == 0
          val = ''
          data.each_slice(8) {|s|
            @cipher.encrypt
            @cipher.key = @key
            val << @cipher.update(s)
          }
          val
        end

        def decrypt(data)
          raise "invalid data length[#{data.hexlify}], should be divided by 8" unless data.length % 8 == 0
          val = ''
          data.each_slice(8) {|s|
            @cipher.decrypt
            @cipher.key = @key
            @cipher.update(s)   # don't know why should update twice
            val << @cipher.update(s)
          }
          val
        end
      end

      class Des3
        def initialize(key)
          raise "invalid key length[#{key.hexlify}], should be 16" unless key.length == 16
          @keyL = key[0..7]
          @keyR = key[8..15]
          @cipherL = OpenSSL::Cipher.new("DES")
          @cipherR = OpenSSL::Cipher.new("DES")
        end

        def encrypt(data)
          raise "invalid data length[#{data.hexlify}], should be divided by 8" unless data.length % 8 == 0
          val = ''
          data.each_slice(8) {|s|
            @cipherL.encrypt
            @cipherL.key = @keyL
            e1 = @cipherL.update(s)
            @cipherR.decrypt
            @cipherR.key = @keyR
            @cipherR.update(e1)      # don't know why should update twice
            e2 = @cipherR.update(e1)
            @cipherL.encrypt
            @cipherL.key = @keyL
            e3 = @cipherL.update(e2)
            val << e3
          }
          val
        end

        def decrypt(data)
          raise "invalid data length[#{data.hexlify}], should be divided by 8" unless data.length % 8 == 0
          val = ''
          data.each_slice(8) {|s|
            @cipherL.decrypt
            @cipherL.key = @keyL
            @cipherL.update(s)   # don't know why should update twice
            d1 = @cipherL.update(s)
            @cipherR.encrypt
            @cipherR.key = @keyR
            d2 = @cipherR.update(d1)
            @cipherL.decrypt
            @cipherL.key = @keyL
            @cipherL.update(d2)
            d3 = @cipherL.update(d2)
            val << d3
          }
          val
        end
      end

      def getEncryptCipher(key)
        cipher = nil
        if key.length > 8
          cipher = OpenSSL::Cipher.new("DES3")
          cipher.encrypt
          cipher.key = key.rpad("0x00", 24)
        else
          cipher = OpenSSL::Cipher.new("DES")
          cipher.encrypt
          cipher.key = key
        end
        cipher
      end

      def getDecryptCipher(key)
        cipher = nil
        if key.length > 8
          cipher = OpenSSL::Cipher.new("DES3")
          cipher.encrypt
          cipher.key = key.rpad("0x00", 24)
        else
          cipher = OpenSSL::Cipher.new("DES")
          cipher.encrypt
          cipher.key = key
        end
        cipher
      end

      def blockXOR(b1, b2, length=8)
        result = ''
        length.times {|i|
          result[i] = (b1[i].ord ^ b2[i].ord).chr
        }
        result
      end

      def calcMAC(key, data, retlen=8)
        cipher = Des.new(key[0..7])
        final = if key.length > 8
                  Des.new(key[8..-1])
                end
        r = data.length % 8
        b = data.length / 8
        if r != 0
          b += 1
          data << "\x00" * (8-r)
        end
        
        mac = "\x00\x00\x00\x00\x00\x00\x00\x00"
        b.times {|i|
          t = blockXOR(mac, data[i*8..(i+1)*8-1])
          mac = cipher.encrypt(t)
p mac.hexlify
        }
        if final
p "in final"
          mac = final.decrypt(mac)
p mac.hexlify
          mac = cipher.encrypt(mac)
p mac.hexlify
        end
        mac[0..retlen-1]
      end # end of calcMAC

      PINBLOCK_FORMAT_01 = "01"
      PINBLOCK_FORMAT_08 = "08"

      def makePINBlock(key, pan, pin, format=PINBLOCK_FORMAT_01)
        pan = "0x00"*8 unless pan.length > 0
        case format
        when PINBLOCK_FORMAT_01
          pan = pan
        when PINBLOCK_FORMAT_08
          pan = "0x00"*8
        end
        pinblock = "0#{pin.length}#{pin}".rpad('F', 16).unhexlify
        sn = "0000#{pan[-13..-2]}".unhexlify
        pinblock = blockXOR(pinblock, sn)
        
        cipher = Des.new(key)
        cipher.encrypt(pinblock)
      end # enf od makePINBlock

      def genUDK(mk, pan, pan_sn)
        cipher = Des3.new(mk)

        data = pan + pan_sn
        if data.length > 16
          data = data[-16..-1]
        elsif data.length < 16
          data = data.lpad("0" * (16-data.length))
        end
        
        leftHalf = data.unhexlify
        rightHalf = blockXOR(data.unhexlify, "\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF")
        udk = cipher.encrypt(leftHalf) + cipher.encrypt(rightHalf)
p "mk=" + mk.hexlify
p "pan.pan_sn=" + data
p "udk=" + udk.hexlify
        udk
      end

      def genSessionKey(udk, atc)
        cipher = Des3.new(udk)

        leftHalf = "\x00\x00\x00\x00\x00\x00" + atc
        rightHalf = "\x00\x00\x00\x00\x00\x00" + blockXOR(atc, "\xFF\xFF", 2)
        sessionKey = cipher.encrypt(leftHalf) + cipher.encrypt(rightHalf)
p "sessionKey=" + sessionKey.hexlify
        sessionKey
      end

      def padDataBlock(data, moduler=8)
        data << "\x80"
        remain = data.length % moduler
        if remain > 0
          padLen = moduler - data.length % moduler
          data += "\x00" * padLen
        end
        data
      end

      def genAC(mk_ac, pan, pan_sn, atc, cmpd, tags)
        data = tags.inject("") {|s,tag|
          fd = cmpd.findField("#{cmpd.fullname}.tag#{tag}")
          raise "tag[#{tag}] missing from action config" unless fd
          fd.pack(0)   # use packed value to calc AC
          val = fd.packedValue
          s += if tag == "9F10"
                 val[3..6]
               else
                 val
               end
        }
p data.hexlify
        udk = genUDK(mk_ac, pan, pan_sn)
        sessionKey = genSessionKey(udk, atc)
        block = padDataBlock(data)
        calcMAC(sessionKey, block, 8)
      end

      def genARPC(mk_ac, pan, pan_sn, atc, arqc, resp_cd)
        udk = genUDK(mk_ac, pan, pan_sn)
        sessionKey = genSessionKey(udk, atc)
        cipher = Des3.new(sessionKey)

        data = blockXOR(arqc, resp_cd + "\x00\x00\x00\x00\x00\x00")
        cipher.encrypt(data)
      end

      def unpackScript(script)
        cla = script[0]
        ins = script[1]
        p1 = script[2]
        p2 = script[3]
        lc = script[4]
        data = script[5..-5]
        mac = script[-4..-1]
        return cla, ins, p1, p2, lc, data, mac
      end

      def genScriptMAC(mk_smi, pan, pan_sn, ac, atc, cla, ins, p1, p2, lc, data)
        block = cla + ins + p1 + p2 + lc + atc + ac + data
        block = padDataBlock(block)
        udk = genUDK(mk_smi, pan, pan_sn)
        sessionKey = genSessionKey(udk, atc)
        calcMAC(sessionKey, block, 4)
      end

    end # end of module Security
  end # end of module Com
end
