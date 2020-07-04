require "./spec_helper"

describe TorrentFile do
  torrent = TorrentFile.new(
    "http://bttracker.debian.org:6969/announce",
    TorrentInfo.new("longpieces", 262144, 351272960, "debian-10.2.0-amd64-netinst.iso")
  )

  peer_id = Bytes[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]
  port = 6882

  pending "can download to file" do
    t = TorrentFile.open("./spec/testdata/debian.iso.torrent")

    t.download_to_file("./res")
  end

  it "reads from file" do
    t = TorrentFile.open("./spec/testdata/archlinux-2019.12.01-x86_64.iso.torrent")
    t.announce.should eq "http://tracker.archlinux.org:6969/announce"
    t.piece_length.should eq 524288
    t.name.should eq "archlinux-2019.12.01-x86_64.iso"
  end

  it "can interpret a tracker's response" do
    File.open(File.join(__DIR__, "./testdata/tracker.response")) { |io|
      tr = TrackerResp.from_bencode io
      tr.interval.should eq 900
      tr.peers.bytesize.should eq 300
    }
  end

  it "can build a tracker URL" do
    url = torrent.build_tracker_url(peer_id, port)
    expected = "http://bttracker.debian.org:6969/announce?compact=1&downloaded=0&info_hash=C%FCnr%A7%AB%EA%8B%ADp%BE%B1%F2%BD8u%5C7%EA%2F&left=351272960&peer_id=%01%02%03%04%05%06%07%08%09%0A%0B%0C%0D%0E%0F%10%11%12%13%14&port=6881&uploaded=0"

    url.should eq expected
  end

  it "decodes Bencode info" do
    info = TorrentInfo.new(pieces: "hello", piece_length: 1_i64, length: 12_i64, name: "my best")
    encoded = info.to_bencode
    encoded.should contain "piece length"
    Bencode.parse(encoded).as(Hash)["piece length"].should eq info.piece_length

    TorrentInfo.from_bencode(encoded).should eq info
  end
end
