require "./io_encodable"
require "log"

module Message
  private EmptyUInt32 = Bytes.new(4, 0)
  private KeepAliveInstance = KeepAlive.new

  abstract struct Msg
    include IoEncodable

    abstract def payload_size
    abstract def payload(io : IO)

    # decodes a stream in the format
    # [length : UInt32 | id : MsgId | payload : Bytes]
    def self.decode(io : IO)
      # FOCUS. Read an unsigned 32 bit integer from IO
      length_slice = Bytes.new(4, 0)
      io.read_fully?(length_slice)
      # Log.info { "#{Fiber.current.name}: read #{length_slice}" }
      return KeepAliveInstance if length_slice == EmptyUInt32

      length = read_uint(IO::Memory.new(length_slice))
      msg_id = io.read_byte.try(&.to_i)

      case msg_id
      when Have.msg_id
        # TODO: Assert length == 4
        index = read_uint(io)
        Have.new(index)
      when Piece.msg_id
        # TODO: Assert payload size >= 8
        index = read_uint(io)
        piece_start = read_uint(io)
        # FOCUS. Fill a slice of given length with input coming from a stream
        data = Bytes.new(length - 9)
        io.read_fully(data) # will throw IO::EOFError if the io is not long enough
        # TODO: Assert IO has ended
        Piece.new(index, piece_start, data)
      when Bitfield.msg_id
        data = Bytes.new(length - 1)
        io.read_fully(data)
        Bitfield.new(data)
      when Unchoke.msg_id
        Unchoke.new
      when Interested.msg_id
        Interested.new
      when Choke.msg_id
        Choke.new
      else
        raise "Unsupported message id #{msg_id}"
      end
    end

    def encode(io : IO)
      length = (self.payload_size + 1).to_u32
      # FOCUS. Write byte-representation of a number to IO
      write_uint(io, length)
      io.write_byte {{@type}}.msg_id.to_u8
      self.payload(io)
    end

    def write_uint(io, uint : UInt32)
      io.write_bytes(uint, IO::ByteFormat::BigEndian)
    end

    def self.read_uint(io)
      io.read_bytes(UInt32, IO::ByteFormat::BigEndian)
    end
  end

  # Have: tells the receiver that the sender has downloaded a piece
  record Have < Msg, index : UInt32 do
    getter payload_size = 4
    class_getter msg_id = 4

    def payload(io)
      write_uint(io, @index)
    end
  end

  # Bitfield: encodes which pieces that the sender has downloaded
  record Bitfield < Msg, bitfield : Bytes do
    class_getter msg_id = 5

    def payload_size
      @bitfield.size
    end

    def payload(io)
      io.write @bitfield
    end

    def has_piece(index : UInt32)
      idx, offset = index.divmod 8

      @bitfield[idx] >> (7 - offset) & 1 != 0
    end

    def set_piece(index : UInt32)
      idx, offset = index.divmod 8

      @bitfield[idx] |= 1 << (7 - offset)
    end
  end

  # Piece: delivers a block of data to fulfill a request
  record Piece < Msg, index : UInt32, piece_start : UInt32, data : Bytes do
    class_getter msg_id = 7

    def payload_size
      8 + data.size
    end

    def payload(io : IO)
      write_uint(io, @index)
      write_uint(io, @piece_start)
      io.write(@data)
    end

    # Writes the piece onto a target buffer.
    # The provided index must match the piece index, otherwise, an exception is raised
    def write(index : UInt32, target : Bytes)
      raise "Wrong index #{index}, expected #{@index}" if index != @index
      # Focus. Copy bytes from buffer to buffer, with offset
      (target + self.piece_start).copy_from(self.data)
      self.data.size
    end
  end

  # Request: requests a block of data from the receiver
  record Request < Msg, index : UInt32, piece_start : UInt32, length : UInt32 do
    getter payload_size = 12
    class_getter msg_id = 6

    def payload(io)
      write_uint(io, @index)
      write_uint(io, @piece_start)
      write_uint(io, @length)
    end
  end

  # KeepAlive     : empty message
  # Choke         : chokes the receiver
  # Unchoke       : unchokes the receiver
  # Interested    : expresses interest in receiving data
  # NotInterested : expresses disinterest in receiving data
  {% for t, index in ["KeepAlive", "Choke", "Unchoke", "Interested", "NotInterested"] %}
  struct {{t.id}} < Msg
    getter payload_size = 0
    class_getter msg_id = {{index - 1}}

    def payload(io)
    end
  end
  {% end %}
end
