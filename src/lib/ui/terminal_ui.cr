require "ncurses"
require "tallboy"

module TerminalUI
  def self.run(refresh : Channel(TorrentStatus))
    NCurses.start
    loop do
      torrent_status = refresh.receive
      NCurses.clear
      NCurses.scrollok

      name = torrent_status.name
      completed = torrent_status.completed
      total = torrent_status.total
      peers = torrent_status.peers
      active_peers = peers.select {|peer| peer.status != :terminated }
      NCurses.print "Downloading #{name}: #{completed} pieces of #{total} completed (#{active_peers.size} peers)\n"

      status_rows = active_peers.map { |peer|
        [peer.peer, peer.status, peer.piece, peer.downloaded]
      }
      NCurses.print Tallboy.table {
        header ["Peer", "Status", "Piece", "Downloaded"]
        rows status_rows
      }.to_s
      NCurses.refresh
    end
  ensure
    NCurses.end
  end
end