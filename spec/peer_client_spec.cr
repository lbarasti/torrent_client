require "./spec_helper"

server_ready = Channel(Nil).new
bitfield = Bytes[255, 1, 3]

spawn do
  test_server = TCPServer.new("0.0.0.0", 3005)

  server_ready.send nil
  peer_id = Random.new.random_bytes(20)
  test_server.accept do |client|
    h = Handshake.decode(client)
    Handshake.new(h.info_hash, peer_id).encode(client)
    Message::Bitfield.new(bitfield).encode(client)

    Message::Unchoke.decode(client)
    Message::Interested.decode(client)
  end
  test_server.close
end

describe PeerClient do
  server_ready.receive

  peer = Peer.new("0.0.0.0", 3005)
  peer_id = Random.new.random_bytes(20)
  info_hash = Random.new.random_bytes(20)

  it "connects to a peer" do
    c = PeerClient.new(peer, info_hash: info_hash, peer_id: peer_id)
    c.bitfield.bitfield.should eq bitfield
  end
end
