require "./spec_helper"

describe Message do
  it "can encode Request messages" do
    req = Message::Request.new(4, 567, 4321)
    expected = Bytes[
      0, 0, 0, 13,             # payload length
      Message::MsgId::Request, # message id
      0, 0, 0, 4,              # index
      0, 0, 2, 55,             # piece start
      0, 0, 16, 225]           # length
    req.encode.should eq expected
  end

  it "can encode Have messages" do
    have = Message::Have.new(42)
    expected = Bytes[
      0, 0, 0, 5,           # payload length
      Message::MsgId::Have, # message id
      0, 0, 0, 42]          # index
    have.encode.should eq expected
  end

  it "can encode Bitfield messages" do
    bf = Message::Bitfield.new(Bytes[1, 2, 3, 4, 5])

    expected = Bytes[
      0, 0, 0, (bf.bitfield.size + 1),
      Message::MsgId::Bitfield,
      1, 2, 3, 4, 5
    ]
    bf.encode.should eq expected
  end

  it "can decode Have messages" do
    source = Bytes[0, 0, 0, 5, Message::MsgId::Have, 0, 0, 1, 0]

    have = Message::Msg.decode(IO::Memory.new(source))
    have.as(Message::Have).index.should eq 256
  end

  it "can decode a Piece message" do
    source = Bytes[0, 0, 0, 15,
      Message::MsgId::Piece,
      0, 0, 1, 0,       # index
      0, 0, 1, 1,       # piece start
      0, 0, 1, 0, 0, 1] # data

    have = Message::Msg.decode(IO::Memory.new(source)).as(Message::Piece)
    have.index.should eq 256
    have.piece_start.should eq 257
    have.data.should eq Bytes[0, 0, 1, 0, 0, 1]
  end

  it "can decode a Bitfield" do
    bitfield = Random.new.random_bytes(1024)
    io = IO::Memory.new
    io.write Bytes[0, 0, 4, 1]
    io.write_byte Message::MsgId::Bitfield.to_u8
    io.write bitfield

    bf = Message::Msg.decode(io.rewind)
      .as(Message::Bitfield)
    bf.bitfield.should eq bitfield
  end

  it "raises an exception if the Have payload is too short" do
    source = Bytes[0, 0, 0, 5, Message::MsgId::Have, 0, 0, 1]

    expect_raises(IO::EOFError) {
      have = Message::Msg.decode(IO::Memory.new(source))
    }
  end

  pending "raises an exception if the Have payload is too long" do
    source = Bytes[0, 0, 0, 5, Message::MsgId::Have, 0, 0, 1, 0, 1]

    expect_raises(IO::EOFError) {
      have = Message::Msg.decode(IO::Memory.new(source))
    }
  end

  it "can write data from a Piece message to a slice" do
    data = Bytes[0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff]
    piece = Message::Piece.new(42, 2, data)
    expected = Bytes[0x00, 0x00, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff, 0x00, 0x00]
    target = Bytes.new(10)

    piece.write(index: 42, target: target)

    target.should eq expected

    expect_raises(Exception, /Wrong index/) {
      piece.write(index: 1, target: target)
    }
  end

  it "can check if a piece is available on a Bitfield" do
    bf = Message::Bitfield.new(Bytes[0, 3, 255, 4])
    expected = "00000000 00000011 11111111 00000100"
      .split(" ").flatten
      .map_with_index { |i, idx| {idx.to_u, i == "1"} }

    expected.each { |idx, present|
      {idx, bf.has_piece(idx)}.should eq({idx, present})
    }
  end

  it "supports Bitfield updates" do
    bf = Message::Bitfield.new(Bytes[0, 3, 255, 4])
    
    bf.has_piece(3).should be_false
    bf.set_piece(3)
    bf.has_piece(3).should be_true
  end
end
