require "bencode"

record TrackerResp, interval : Int64, peers : String do
  include Bencode::Serializable
end
