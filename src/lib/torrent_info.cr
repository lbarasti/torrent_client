require "bencode"

# This record maps to the `info` field of  .torrent files.
record TorrentInfo,
  pieces : String,
  piece_length : Int64,
  length : Int64,
  name : String do
  include Bencode::Serializable
  
  @[Bencode::Field(key: "piece length")]
  getter piece_length : Int64

  def hash : StaticArray(UInt8, 20)
    OpenSSL::SHA1.hash self.to_bencode
  end

  def split_piece_hashes
    hash_len = 20
    bytes = self.pieces.to_slice.dup
    num_hashes, rem = bytes.size.divmod hash_len
    raise Exception.new("wrong size for piece hashes") if rem != 0
    (0...num_hashes).map { |i|
      bytes[i*hash_len...((i+1)*hash_len)]
    }
  end
end
