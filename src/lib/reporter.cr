require "./peers"
require "tallboy"

abstract struct Event
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
  getter total, todo
  def initialize(@total : Int32, @todo : Int32); end
end

record PeerStatus, peer : String, status : Symbol, piece : UInt32? = nil, downloaded : UInt32 = 0

class Reporter
  def initialize
    @events = Channel(Event).new(1024)
    @refresh = Channel(Nil).new
    peer_data = Hash(Peer, PeerStatus).new
    total = 0
    todo = 0
    n_done = 0

    spawn(name: "reporter") do
      loop do
        event = @events.receive
        case event
        when Initialized
          total = event.total
          todo = event.todo
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
        @refresh.send nil
      end
    end
    spawn(name: "UI") do
      loop do
        @refresh.receive
        puts Tallboy.table {
          header ["Peer", "Status", "Piece", "Downloaded"]
          rows peer_data.map { |_, row| [row.peer, row.status, row.piece, row.downloaded]}
        }
        percent = (total - todo + n_done).to_f / total * 100
        puts "(#{percent.round(2)}%) Downloaded #{total - todo + n_done} pieces out of #{total}"
      end
    end
  end

  def send(message)
    @events.send message
  end
end
