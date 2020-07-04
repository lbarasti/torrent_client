module IoEncodable
  def encode : Bytes
    IO::Memory.new.tap { |io|
      encode(io)
    }.to_slice
  end
end
