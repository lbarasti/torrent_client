require "log"
require "./lib/torrent_file"

# in_path = ARGV[0]
# out_path = ARGV[1]

tor_file = File.join(__DIR__, "../spec/testdata/debian-10.2.0-amd64-netinst.iso.torrent")

TorrentFile.open(tor_file)
  .download_to_file("./res")
