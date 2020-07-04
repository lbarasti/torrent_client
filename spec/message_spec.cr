require "./spec_helper"

describe Message do
  it "can encode Request messages" do
    req = Message::Request.new(4, 567, 4321)
    expected = Bytes[
      0, 0, 0, 13, # payload length
      Message::MsgId::Request, # message id
      0, 0, 0, 4, # index
			0, 0, 2, 55, # piece start
			0, 0, 16, 225] # length
    req.encode.should eq expected
  end

  it "can encode Have messages" do
    have = Message::Have.new(42)
    expected = Bytes[
      0, 0, 0, 5, # payload length
      Message::MsgId::Have, # message id
      0, 0, 0, 42] # index
    have.encode.should eq expected
  end

  it "can decode Have messages" do
    source = Bytes[0, 0, 0, 5, Message::MsgId::Have, 0, 0, 1, 0]
    
    have = Message::Msg.decode(IO::Memory.new(source))
    have.as(Message::Have).index.should eq 256
  end

  it "can decode a Piece message" do
    source = Bytes[0, 0, 0, 15,
      Message::MsgId::Piece,
      0, 0, 1, 0, # index
      0, 0, 1, 1, # piece start
      0, 0, 1, 0, 0, 1] # data
    
    have = Message::Msg.decode(IO::Memory.new(source)).as(Message::Piece)
    have.index.should eq 256
    have.piece_start.should eq 257
    have.data.should eq Bytes[0, 0, 1, 0, 0, 1]
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

end


# target = IO::Memory.new
# RequestMsg.new(3, 2, 256).encode(target)
# puts target.to_slice

# source = Bytes[0, 0, 0, 5, 4, 1, 0, 1, 0]
# target = IO::Memory.new
# m = Msg.decode(IO::Memory.new(source))
# m.encode(target)

# puts target.to_slice == source

# source = Bytes[0, 0, 0, 11, 7, 1, 0, 1, 0, 0, 0, 1, 0, 0, 1]
# target = IO::Memory.new
# m = Msg.decode(IO::Memory.new(source))
# m.encode(target)

# puts m.as(PieceMsg).piece_start, target.to_slice
