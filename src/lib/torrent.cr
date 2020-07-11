require "log"
require "./peers"
require "./peer_client"
require "./reporter"

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
  def start_download_worker(peer : Peer, work_queue : Channel(PieceWork), results : Channel(PieceResult), reporter : Reporter)
    Log.debug { "started worker for #{Fiber.current.name}" }
    exceptions = 0

    client = PeerClient.new(peer, info_hash, peer_id)

    reporter.send({peer: peer, status: :connected})
    loop do
      pw = work_queue.receive
      unless client.bitfield.has_piece(pw.index)
        work_queue.send pw
        next
      end
      reporter.send({peer: peer, piece: pw.index, status: :started})
      buffer = client.download(pw)
      raise "hash mismatch" if pw.hash != OpenSSL::SHA1.hash(String.new(buffer)).to_slice
      Log.debug { "#{peer} sending piece #{pw.index}" }

      Message::Have.new(pw.index).encode(client.@client)
      res = PieceResult.new(pw.index, buffer)
      reporter.send({peer: peer, piece: pw.index, status: :completed})
      results.send(res)
    rescue e
      Log.warn { "#{peer} shutting down due to #{e.class}" }
      exceptions += 1
      work_queue.send(pw) unless pw.nil?
      break if exceptions > 5
    end
  end

  def piece_size(index)
    begin_point : Int64 = index.to_i64 * self.piece_length
    end_point = Math.min(begin_point + self.piece_length, self.length)
    end_point - begin_point
  end

  def download(maybe_path, reporter)
    Log.info { "Starting download for #{self.name}" }
    part_dir = "./data/#{self.name}_parts"
    out_path = maybe_path || "./data/#{self.name}"
    part_path = ->(index : UInt32) { File.join(part_dir, "#{index}.part") }

    Dir.mkdir(part_dir) unless Dir.exists?(part_dir)
    piece_total = self.piece_hashes.size
    work_queue = Channel(PieceWork).new(piece_total)
    results = Channel(PieceResult).new

    todo = self.piece_hashes.map_with_index { |hash, index|
      {hash, index}
    }.reject { |(_, index)|
      File.exists? part_path.call(index.to_u)
    }.map { |(hash, index)|
      length = self.piece_size(index)
      work_queue.send PieceWork.new(index.to_u, hash, length)
    }.size

    Log.info { "Pieces to be dowloaded: #{todo}" }

    # start workers
    self.peers.each { |peer|
      spawn(name: "#{peer}_worker") {
        begin
          self.start_download_worker(peer, work_queue, results, reporter)
        rescue e
          Log.warn(exception: e) { "#{peer} shutting down due to #{e.class}" }
        end
      }
    } unless todo == 0

    # collect results
    todo.times { |n_done|
      res = results.receive

      Log.debug { "size: #{res.buf.size} index: #{res.index}" }

      dest = part_path.call(res.index)
      File.open(dest, "w") do |io|
        io.write res.buf
      end
      percent = (piece_total - todo + n_done + 1).to_f / piece_total * 100
      Log.info { "(#{percent.round(2)}%) Downloaded piece ##{res.index}" }
    }

    work_queue.close
    File.open(out_path, "w") { |target|
      Log.info { "Writing to #{out_path}" }
      piece_total.times { |idx|
        File.open(part_path.call(idx.to_u), "r") { |source|
          IO.copy source, target
        }
      }
      Log.info { "Written to #{out_path}" }
    }
  end
end
