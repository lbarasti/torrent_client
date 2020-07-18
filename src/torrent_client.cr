require "log"
require "./lib/reporter"
require "./lib/torrent_file"

Log.define_formatter MyFormat, "#{timestamp} #{severity}: #{source}|#{pid}|#{Fiber.current.name}> #{message}#{exception}"
Log.setup do |c|
  backend = Log::IOBackend.new File.open("app.log", "w"), formatter: MyFormat

  c.bind "*", :debug, backend
end

torrent_path = ARGV[0]
out_path = ARGV[1]?

TorrentFile.open(torrent_path)
  .to_torrent
  .download(out_path, Reporter.new)
