require "./io_encodable"

record Handshake,
  info_hash : Bytes,
  peer_id : Bytes do
  include IoEncodable

  getter pstr = "BitTorrent protocol" # protocol identifier

  def encode(io : IO)
    # len = pstr.size + 49
    io.write(Bytes[pstr.size])

    io << pstr
    io.write Bytes.new(8, 0)
    io.write @info_hash
    io.write @peer_id
  end

  def self.decode(io)
    pstr_len = io.read_byte.not_nil!.to_i
    pstr = Bytes.new(pstr_len)
    io.read_fully(pstr) # currently unused
    io.skip(8)          # reserved bytes
    info_hash = Bytes.new(20)
    io.read_fully(info_hash)
    peer_id = Bytes.new(20)
    io.read_fully(peer_id)

    Handshake.new(info_hash, peer_id)
  end
end
