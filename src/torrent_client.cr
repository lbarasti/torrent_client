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

if torrent_path == "--replay"
  reporter = Reporter.new(File.open(File::NULL, "w"))
  event_log = File.new(File.join(__DIR__, "../history.log"), "r")

  event_log.each_line { |line|
    reporter.send(Event.from_json(line))
    sleep 0.3
  }
else
  event_log = File.new(File.join(__DIR__, "../history.log"), "w")

  reporter = Reporter.new(event_log)

  TorrentFile.open(torrent_path)
    .to_torrent
    .download(out_path, reporter)
end