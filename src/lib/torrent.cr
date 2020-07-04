require "log"
require "./peers"

record PieceWork,
  index : Int32,
  hash : Bytes,
  length : Int64

record PieceResult,
  index : Int32,
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
    Log.info { "started worker for #{Fiber.current.name}" }
    res = PieceResult.new(rand(self.piece_hashes.size//2), Bytes[1, 2, 3])
    sleep rand(20)
    results.send(res)
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

    self.piece_hashes.each_with_index { |hash, index|
      length = self.calculate_piece_size(index)
      work_queue.send PieceWork.new(index, hash, length)
    }

    # start workers
    self.peers.each { |peer|
      spawn(name: "#{peer}_worker") {
        self.start_download_worker(peer, work_queue, results)
      }
    }

    # collect results
    buf = Bytes.new(self.length//2)
    piece_hashes.size.times { |n_done|
      res = results.receive
      piece_start, piece_end = self.calculate_bounds_for_piece(res.index)
      Log.info { "size: #{res.buf.size} index: #{res.index}: #{piece_start}, #{piece_end}" }

      # TODO is it necessary to limit res.buf to not go out of bound?
      res.buf.copy_to(buf + piece_start)

      percent = n_done.to_f / self.piece_hashes.size * 100
      Log.info { "(#{percent.round(2)}%) Downloaded piece ##{res.index} from n peers" }
    }

    work_queue.close
    return buf
  end
end
