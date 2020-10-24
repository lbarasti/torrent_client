module MinimalUI
  def self.run(refresh : Channel(TorrentStatus))
    loop do
      torrent_status = refresh.receive
      name = torrent_status.name
      completed = torrent_status.completed
      total = torrent_status.total
      peers = torrent_status.peers
      active_peers = peers.select {|peer| peer.status != :terminated }
      print "\rDownloading #{name}: #{completed} pieces of #{total} completed (#{active_peers.size} peers)"
    end
  end
end