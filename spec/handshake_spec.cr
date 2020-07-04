require "./spec_helper"

describe Handshake do
  h = Handshake.new(Bytes[1, 2, 3], Bytes[4, 5, 6])

  it "can be encoded into IO" do
    actual = h.encode

    (actual + 20 + 8).should eq Bytes[1, 2, 3, 4, 5, 6]
  end

  it "can decode a Handshake message" do
    pstr = "BitTorrent protocol"
    info_hash = Bytes[134, 212, 200, 0, 36, 164, 105, 190, 76, 80, 188, 90, 16, 44, 247, 23, 128, 49, 0, 116]
    peer_id = Bytes[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]
    expected = Bytes[19, 66, 105, 116, 84, 111, 114, 114, 101, 110, 116, 32, 112, 114, 111, 116, 111, 99, 111, 108, 0, 0, 0, 0, 0, 0, 0, 0, 134, 212, 200, 0, 36, 164, 105, 190, 76, 80, 188, 90, 16, 44, 247, 23, 128, 49, 0, 116, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]

    io = IO::Memory.new
    io.write_byte pstr.size.to_u8
    io << pstr
    io.write Bytes.new(8)
    io.write info_hash
    io.write peer_id
    decoded = Handshake.decode(io.rewind)
    decoded.should eq Handshake.new(info_hash, peer_id)
    decoded.encode.should eq expected
  end
end
