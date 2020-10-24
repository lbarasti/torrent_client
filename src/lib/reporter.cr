require "./peers"
require "./events"
require "./ui/*"

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

UI = {
  UI_Mode::Ncurses => TerminalUI,
  UI_Mode::Web => WebUI,
  UI_Mode::Minimal => MinimalUI
}

class Reporter
  def initialize(@io : File, ui_mode : UI_Mode)
    @events = Channel(Event).new(1024)
    status_stream = Channel(TorrentStatus).new

    spawn(name: "event_processor") do
      process(@events, status_stream)
    end

    spawn UI[ui_mode].run(status_stream)
  end

  def send(message)
    @events.send message
  end

  def process(events, status_stream)
    peer_data = Hash(Peer, PeerStatus).new
    name = ""
    total, todo, n_done = 0, 0, 0
    loop do
      event = events.receive
      persist event

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
      status_stream.send TorrentStatus.new(name, total - todo + n_done, total, peer_table)
    end
  end

  private def persist(event : Event)
    event.to_json(@io)
    @io << "\n"
  end
end
