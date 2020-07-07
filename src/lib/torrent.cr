require "log"
require "./peers"
require "./peer_client"

record PieceWork,
  index : UInt32,
  hash : Bytes,
  length : Int64

record PieceResult,
  index : UInt32,
  buf : Bytes

record Torrent,
  peers : Array(Peer),
  peer_id : Bytes,
  info_hash : Bytes,
  piece_hashes : Array(Bytes),
  piece_length : Int32,
  length : Int64,
  name : String do
  def start_download_worker(peer : Peer, work_queue : Channel(PieceWork), results : Channel(PieceResult))
    Log.debug { "started worker for #{Fiber.current.name}" }
    exceptions = 0

    client = PeerClient.new(peer, info_hash, peer_id)

    loop do
      pw = work_queue.receive
      unless client.bitfield.has_piece(pw.index)
        work_queue.send pw
        next
      end
      buffer = client.download(pw)
      raise "hash don't match" if pw.hash != OpenSSL::SHA1.hash(String.new(buffer)).to_slice
      Log.debug { "#{peer} sending piece #{pw.index}" }

      Message::Have.new(pw.index).encode(client.@client)
      res = PieceResult.new(pw.index, buffer)
      results.send(res)
    rescue e
      Log.warn { "#{peer} shutting down due to #{e.class}" }
      exceptions += 1
      break if exceptions > 5
      work_queue.send(pw) unless pw.nil?
    end
  end

  def calculate_bounds_for_piece(index)
    begin_point : Int64 = index.to_i64 * self.piece_length
    end_point = Math.min(begin_point + self.piece_length, self.length)
    {begin_point.to_i64, end_point.to_i64}
  end

  def calculate_piece_size(index)
    begin_point, end_point = self.calculate_bounds_for_piece(index)
    end_point - begin_point
  end

  def download
    Log.info { "Starting download for #{self.name}" }
    work_queue = Channel(PieceWork).new(piece_hashes.size)
    results = Channel(PieceResult).new

    todo = self.piece_hashes.map_with_index { |hash, index|
      {hash, index}
    }.reject { |(_, index)|
      File.exists?(File.join("./data/#{index}.part"))
    }.map { |(hash, index)|
      length = self.calculate_piece_size(index)
      work_queue.send PieceWork.new(index.to_u, hash, length)
    }.size

    Log.info { "Pieces to be dowloaded: #{todo}" }

    # start workers
    self.peers.each { |peer|
      spawn(name: "#{peer}_worker") {
      begin
        self.start_download_worker(peer, work_queue, results)
      rescue e
        Log.warn { "#{peer} shutting down due to #{e.class}" }
      end
      }
    } unless todo == 0

    # collect results
    todo.times { |n_done|
      res = results.receive
      piece_start, piece_end = self.calculate_bounds_for_piece(res.index)
      Log.debug { "size: #{res.buf.size} index: #{res.index}: #{piece_start}, #{piece_end}" }

      dest = File.join("./data/#{res.index}.part")
      File.open(dest, "w") do |io|
        io.write res.buf
      end
      percent = n_done.to_f / self.piece_hashes.size * 100
      Log.info { "(#{percent.round(2)}%) Downloaded piece ##{res.index}" }
    }

    work_queue.close
    File.open("./data/debian.iso", "w") { |target|
      Log.info { "Writing" }
      piece_hashes.size.times { |idx|
        File.open("./data/#{idx}.part", "r") { |source|
          IO.copy source, target
          Log.info { "written #{idx}" }
        }
      }
    }
  end
end
