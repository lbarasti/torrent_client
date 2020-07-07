require "./spec_helper"

server_ready = Channel(Nil).new

spawn do
  test_server = TCPServer.new("localhost", 3000)

  server_ready.send nil
  peer_id = Random.new.random_bytes(20)
  loop do
    test_server.accept do |client|
      puts "waiting for hs"
      h = Handshake.decode(client)
      puts "received hs"
      Handshake.new(h.info_hash, peer_id).encode(client)
      Message::Bitfield.new(Bytes[255, 1, 3]).encode(client)
    end
  end
end

describe PeerClient do
  server_ready.receive

  peer = Peer.new("0.0.0.0", 3000)
  peer_id = Random.new.random_bytes(20)
  info_hash = Random.new.random_bytes(20)
  
  it "connects to a peer" do
    c = PeerClient.new(peer, info_hash: info_hash, peer_id: peer_id)
    c.bitfield.bitfield.should eq Bytes[255, 1, 3]
  end
end