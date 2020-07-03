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

  delegate piece_length, length, name, to: @info

  def info_hash
    self.info.hash.to_slice.dup
  end

  def piece_hashes
    self.info.split_piece_hashes
  end

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

    puts res.body
    resp = TrackerResp.from_bencode res.body
    Peers.parse(resp.peers.to_slice)
  end

  def download_to_file(path : String)
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

    # blocking call, will return once the download is completed
    buf = torrent.download

    File.write(path, buf)
  end
end
