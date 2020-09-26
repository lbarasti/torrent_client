require "./peers"
require "tallboy"
require "http/server"
require "json"
require "ncurses"

abstract struct Event
  include JSON::Serializable

  use_json_discriminator "type", {connected: Connected, started: Started, completed: Completed, terminated: Terminated, initialized: Initialized}

  getter type : String
  
  macro inherited
    getter type : String = {{@type.stringify.downcase}}
  end
end

struct Connected < Event
  getter peer
  def initialize(@peer : Peer); end
end

struct Started < Event
  getter peer, piece
  def initialize(@peer : Peer, @piece : UInt32); end
end

struct Completed < Event
  getter peer, piece
  def initialize(@peer : Peer, @piece : UInt32); end
end

struct Terminated < Event
  getter peer
  def initialize(@peer : Peer); end
end

struct Initialized < Event
  getter total, todo, name
  def initialize(@name : String, @total : Int32, @todo : Int32); end
end

record PeerStatus, peer : String, status : Symbol, piece : UInt32? = nil, downloaded : UInt32 = 0 do
  include JSON::Serializable
end

record TorrentStatus, name : String, completed : Int32, total : Int32, peers : Array(PeerStatus) do
  include JSON::Serializable
end

enum UI_Mode
  Web
  Ncurses
  Minimal
end

class Reporter
  def initialize(@io : File, @mode : UI_Mode)
    @events = Channel(Event).new(1024)
    @refresh = Channel(TorrentStatus).new

    spawn(name: "reporter") do
      peer_data = Hash(Peer, PeerStatus).new
      name = ""
      total = 0
      todo = 0
      n_done = 0
      loop do
        event = @events.receive
        event.to_json(@io)
        @io << "\n"

        case event
        when Initialized
          total = event.total
          todo = event.todo
          name = event.name
        when Connected
          peer_data[event.peer] = PeerStatus.new(event.peer.address, :connected)
        when Started
          peer_data[event.peer] = peer_data[event.peer].copy_with(status: :downloading, piece: event.piece)
        when Completed
          downloaded = peer_data[event.peer].downloaded + 1
          peer_data[event.peer] = peer_data[event.peer].copy_with(status: :finished, piece: event.piece, downloaded: downloaded)
          n_done += 1
        when Terminated
          curr = peer_data[event.peer]?
          peer_data[event.peer] = PeerStatus.new(event.peer.address, :terminated, curr.try(&.piece), curr.try(&.downloaded) || 0_u32)
        end
        peer_table = peer_data.values
        @refresh.send TorrentStatus.new(name, total - todo + n_done, total, peer_table)
      end
    end
    case @mode
    when UI_Mode::Ncurses
      spawn(name: "UI") do
        NCurses.start
        loop do
          torrent_status = @refresh.receive
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
        NCurses.end
      end
    when  UI_Mode::Web
      ws_handler = HTTP::WebSocketHandler.new do |ws, ctx|
        loop do
          torrent_status = @refresh.receive
          ws.send torrent_status.to_json
        end
      end

      spawn do
        server = HTTP::Server.new([
          ws_handler,
          HTTP::StaticFileHandler.new(File.join(__DIR__, "../../public"))
        ])

        address = server.bind_tcp 3000
        puts "Listening on http://#{address}"
        server.listen
      end
    else
      spawn(name: "Minimal UI") do
        loop do
          torrent_status = @refresh.receive
          name = torrent_status.name
          completed = torrent_status.completed
          total = torrent_status.total
          peers = torrent_status.peers
          active_peers = peers.select {|peer| peer.status != :terminated }
          print "\rDownloading #{name}: #{completed} pieces of #{total} completed (#{active_peers.size} peers)"
        end
      end
    end
  end

  def send(message)
    @events.send message
  end
end
