require "bencode"

# This record maps to the `info` field of a .torrent file.
record TorrentInfo,
  pieces : String,
  piece_length : Int64,
  length : Int64,
  name : String do
  include Bencode::Serializable

  @[Bencode::Field(key: "piece length")]
  getter piece_length : Int64

  # Returns the hash of the bencode representation of this object.
  # This is used to identify a torrent when querying a tracker for peers.
  def info_hash : Bytes
    # SHA1.hash returns a `StaticArray`. `StaticArray#to_slice` is not safe, so we need
    # to `dup`licate it. Why? A staticarray resides on the stack and as soon as we
    # exit the scope in which it was defined, the memory is not reserved to it anymore,
    # while the slice keeps pointing to the same memory (kudos to @oprypin for the explanation).
    OpenSSL::SHA1.hash(self.to_bencode)
      .to_slice
      .dup
  end

  # Returns an array of hashes where `piece_hashes[i]`
  # is the hash of the i-th piece of the file.
  def piece_hashes
    hash_len = 20
    bytes = self.pieces.to_slice
    num_hashes, rem = bytes.size.divmod hash_len
    raise Exception.new("wrong size for piece hashes") if rem != 0
    (0...num_hashes).map { |i|
      bytes[i*hash_len...((i + 1)*hash_len)]
    }
  end
end
