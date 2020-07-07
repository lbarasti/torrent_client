require "socket"
require "log"
require "./handshake"
require "./message"

class PeerClient
  MAX_BLOCK_SIZE = 16384
  MAX_BACKLOG = 5
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
  end

  def download(pw : PieceWork) : Bytes
    @client.read_timeout = 30.seconds
    requested = 0_u32
    dowloaded = 0_u32
    buffer = Bytes.new(pw.length)

    while dowloaded < pw.length
      while requested < pw.length
        MAX_BACKLOG.times { # pipelining requests
          break if requested >= pw.length
          block_size = Math.min(MAX_BLOCK_SIZE, pw.length - requested).to_u
          req = Message::Request.new(
            pw.index, requested, block_size)
          
          req.encode @client
          requested += block_size
        }

        backlog = 0
        loop do
          case msg = Message::Msg.decode(@client)
          when Message::Have
            @bitfield.set_piece(msg.index)
          when Message::Piece
            n = msg.write(pw.index, buffer)
            dowloaded += n
            backlog += 1
            break if backlog == MAX_BACKLOG || dowloaded == pw.length
          end
        end
      end
    end
    Log.debug { "#{@peer} completed piece ##{pw.index}" }
    buffer
  end
end