require "log"
require "./lib/torrent_file"

# in_path = ARGV[0]
# out_path = ARGV[1]

tor_file = File.join(__DIR__, "../spec/testdata/debian.iso.torrent")

TorrentFile.open(tor_file)
  .download_to_file("./res")
