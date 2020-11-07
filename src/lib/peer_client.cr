require "socket"
require "log"
require "./handshake"
require "./message"

class PeerClient
  MAX_BLOCK_SIZE = 16384_u32
  MAX_BACKLOG    =     5

  class InfoHashMismatch < Exception
  end

  getter bitfield, client

  # May raise
  # * Socket::ConnectError if the connection to the peer takes too long
  # * IO::TimeoutError if reading from the peer takes too long
  # * InfoHashMismatch if the returned info hash does not match the one sent
  def initialize(@peer : Peer, @info_hash : Bytes, @peer_id : Bytes)
    @client = TCPSocket.new(@peer.address, @peer.port, connect_timeout: 3.seconds)
    @client.read_timeout = 3.seconds
    Log.info { "connected to peer #{@peer}" }

    hs = Handshake.new info_hash: @info_hash, peer_id: @peer_id
    hs.encode @client
    return_hs = Handshake.decode @client
    raise InfoHashMismatch.new("#{@peer}") if return_hs.info_hash != hs.info_hash

    Log.debug { "received handshake from #{@peer}" }

    @client.read_timeout = 5.seconds
    @bitfield = Message::Msg.decode(@client)
      .as(Message::Bitfield)

    Log.debug { "received bitfield from #{@peer}" }

    Message::Unchoke.new.encode(client)
    Message::Interested.new.encode(client)

    wait_for_unchoke(max_attempts: 3)
  end

  def wait_for_unchoke(max_attempts : Int32)
    max_attempts.times do |i|
      case msg = Message::Msg.decode(@client)
      when Message::Unchoke
        Log.debug { "unchoked by #{@peer}" }
        break
      else
        Log.debug { "received #{msg} from #{@peer} instead of unchoke" }
        raise "Could not unchoke" if i == max_attempts - 1
      end
    end
  end

  def download(pw : PieceWork) : Bytes
    @client.read_timeout = 5.seconds
    @client.write_timeout = 5.seconds
    buffer = Bytes.new(pw.length)

    q, r = pw.length.divmod(MAX_BLOCK_SIZE)
    number_of_blocks = q + r.sign

    requests = (0...number_of_blocks).map { |block_id|
      offset = MAX_BLOCK_SIZE * block_id
      block_size = Math.min(MAX_BLOCK_SIZE, pw.length - offset).to_u
      Message::Request.new(pw.index, offset, block_size) 
    }

    requests.each_slice(MAX_BACKLOG) { |batch|
      batch.each { |req|
        req.encode @client
      }

      bounced = 0
      batch.each {
        loop do
          case msg = Message::Msg.decode(@client)
          when Message::Have
            @bitfield.set_piece(msg.index)
          when Message::Piece
            # Log.debug { "received block for piece #{pw.index} from #{@peer}" }
            n = msg.write(pw.index, buffer)
            break
          else
            bounced += 1
            raise "Bounced too many times" if bounced >= 3
            sleep rand(3)
          end
        end
      }
    }
    Log.debug { "#{@peer} completed piece ##{pw.index}" }
    buffer
  end
end
