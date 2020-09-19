require "./spec_helper"
require "../src/lib/reporter"

describe Event do
  it "can encode Request messages" do
    c = Connected.new(Peer.new("0.0.0.0", 80))
    puts c.to_json
  end
end
