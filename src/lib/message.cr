require "./io_encodable"

module Message
  enum MsgId
    Choke         # chokes the receiver
    Unchoke       # unchokes the receiver
    Interested    # expresses interest in receiving data
    NotInterested # expresses disinterest in receiving data
    Have          # alerts the receiver that the sender has downloaded a piece
    Bitfield      # encodes which pieces that the sender has downloaded
    Request       # requests a block of data from the receiver
    Piece         # delivers a block of data to fulfill a request
    Cancel        # cancels a request
  end

  abstract class Msg
    include IoEncodable

    abstract def payload_size
    abstract def msg_id
    abstract def payload(io : IO)

    # decodes a stream in the format
    # [length : UInt32 | id : MsgId | payload : Bytes]
    def self.decode(io : IO)
      # FOCUS. Read an unsigned 32 bit integer from IO
      length = io.read_bytes(UInt32, IO::ByteFormat::BigEndian)
      msg_id = MsgId.new(io.read_byte.not_nil!.to_i)

      case msg_id
      when MsgId::Have
        # TODO: Assert length == 4
        index = io.read_bytes(UInt32, IO::ByteFormat::BigEndian)
        Have.new(index)
      when MsgId::Piece
        # TODO: Assert payload size >= 8
        index = io.read_bytes(UInt32, IO::ByteFormat::BigEndian)
        piece_start = io.read_bytes(UInt32, IO::ByteFormat::BigEndian)
        # FOCUS. Fill a slice of given length with input coming from a stream
        data = Bytes.new(length - 9)
        io.read_fully(data) # will throw IO::EOFError if the io is not long enough
        # TODO: Assert IO has ended
        Piece.new(index, piece_start, data)
      else
        raise "Unsupported message id"
      end
    end

    def encode(io : IO)
      length = (self.payload_size + 1).to_u32
      # FOCUS. Write byte-representation of a number to IO
      write_uint(io, length)
      io.write_byte self.msg_id.to_u8
      self.payload(io)
    end

    def write_uint(io, uint : UInt32)
      io.write_bytes(uint, IO::ByteFormat::BigEndian)
    end
  end

  class Have < Msg
    getter payload_size = 4
    getter msg_id = MsgId::Have
    getter index

    def initialize(@index : UInt32)
    end

    def payload(io)
      write_uint(io, @index)
    end
  end

  class Piece < Msg
    getter msg_id = MsgId::Piece
    getter index, piece_start, data
    getter payload_size : Int32

    def initialize(@index : UInt32, @piece_start : UInt32, @data : Bytes)
      @payload_size = 8 + data.size
    end

    def payload(io : IO)
      write_uint(io, @index)
      write_uint(io, @piece_start)
      io.write(@data)
    end

    # Writes the the piece onto a target buffer.
    # The provided index must match the piece index, otherwise, an exception is raised
    def write(index : UInt32, target : Bytes)
      raise "Wrong index #{index}, expected #{@index}" if index != @index
      # Focus. Copy bytes from buffer to buffer, with offset
      (target + self.piece_start).copy_from(self.data)
    end
  end

  class Request < Msg
    getter payload_size = 12
    getter msg_id = MsgId::Request
    getter index, piece_start, length

    def initialize(@index : UInt32, @piece_start : UInt32, @length : UInt32)
    end

    def payload(io)
      write_uint(io, @index)
      write_uint(io, @piece_start)
      write_uint(io, @length)
    end
  end
end
