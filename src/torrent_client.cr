require "log"
require "clim"
require "./lib/reporter"
require "./lib/torrent_file"

Log.define_formatter MyFormat, "#{timestamp} #{severity}: #{source}|#{pid}|#{Fiber.current.name}> #{message}#{exception}"
Log.setup do |c|
  backend = Log::IOBackend.new File.open("app.log", "w"), formatter: MyFormat

  c.bind "*", :debug, backend
end

class CLI < Clim
  main do
    desc "Download a torrent file"
    usage "CRYSTAL_WORKERS=<n-workers>  ./torrent_client <torrent_path> [options]"
    option "-r", "--replay", type: Bool, desc: "Will replay events from the previous run.", default: false
    option "-o <destination_path>", "--output=<destination_path>", type: String, desc: "Download destination", default: nil
    option "-m <minimal|ncurses|web>", "--mode=<minimal|ncurses|web>", type: String, desc: "UI mode", default: "minimal"
    argument "torrent_path", type: String, desc: "The torrent file you want to download."#, required: true

    run do |opts, args|
      ui_mode = UI_Mode.parse(opts.mode)
      if opts.replay
        reporter = Reporter.new(File.open(File::NULL, "w"), mode: ui_mode)
        event_log = File.new(File.join(__DIR__, "../history.log"), "r")

        event_log.each_line { |line|
          reporter.send(Event.from_json(line))
          sleep 0.3
        }
      else
        event_log = File.new(File.join(__DIR__, "../history.log"), "w")

        reporter = Reporter.new(event_log, mode: ui_mode)

        TorrentFile.open(args.torrent_path.not_nil!)
          .to_torrent
          .download(opts.output, reporter)
      end
    end
  end
end

CLI.start(ARGV)