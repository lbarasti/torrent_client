require "socket"

alias Peer = Socket::IPAddress

module Peers
  PEER_SIZE = 6

  def self.parse(binary : Bytes) : Array(Peer)
    num_peers, rem = binary.size.divmod PEER_SIZE
    raise Exception.new("Wrong size for peer") if rem != 0

    (0...num_peers).map { |i|
      offset = i * PEER_SIZE
      ip = binary[offset...(offset+4)].join(".")
      port = binary[(offset+4)...(offset+6)].reduce(0_u16) {|ac, v| (ac << 8) | v }
      Peer.new(ip, port.to_i32)
    }
  end
end
