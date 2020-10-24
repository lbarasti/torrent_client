require "json"

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
  getter peer, piece, size
  def initialize(@peer : Peer, @piece : UInt32, @size : Int32); end
end

struct Terminated < Event
  getter peer
  def initialize(@peer : Peer); end
end

struct Initialized < Event
  getter total, todo, name
  def initialize(@name : String, @total : Int32, @todo : Int32); end
end