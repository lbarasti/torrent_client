require "uri"
require "http/params"
require "http/client"
require "bencode"
require "./peers"
require "./tracker_resp"
require "./torrent"
require "./torrent_info"

Port = 6881

# Record representing a .torrent file
record TorrentFile, announce : String, info : TorrentInfo do
  include Bencode::Serializable

  delegate piece_length, length, name, info_hash, piece_hashes, to: @info

  def self.open(path : String)
    TorrentFile.from_bencode(File.read(path))
  end

  def build_tracker_url(peer_id : Bytes, port : Int32)
    base = URI.parse(self.announce)
    params = {
      "compact":    "1",
      "downloaded": "0",
      "info_hash":  String.new(self.info_hash),
      "left":       self.length.to_s,
      "peer_id":    String.new(peer_id),
      "port":       Port.to_s,
      "uploaded":   "0",
    }
    base.query = HTTP::Params.encode(params)
    base.to_s
  end

  def request_peers(peer_id : Bytes, port : Int32) : Array(Peer)
    url = self.build_tracker_url peer_id, port
    res = HTTP::Client.get url

    resp = TrackerResp.from_bencode res.body
    Peers.parse(resp.peers.to_slice)
  end

  def to_torrent
    peer_id = Random.new.random_bytes(20)
    peers = self.request_peers(peer_id, Port)

    torrent = Torrent.new(
      peers,
      peer_id,
      self.info_hash,
      self.piece_hashes,
      self.piece_length.to_i32,
      self.length,
      self.name
    )
  end
end
