require "http/server"

module WebUI
  def self.run(refresh : Channel(TorrentStatus))
    ws_handler = HTTP::WebSocketHandler.new do |ws, ctx|
      loop do
        torrent_status = refresh.receive
        ws.send torrent_status.to_json
      end
    end

    spawn do
      server = HTTP::Server.new([
        ws_handler,
        HTTP::StaticFileHandler.new(File.join(__DIR__, "../../../public"))
      ])

      address = server.bind_tcp 3000
      puts "Listening on http://#{address}"
      server.listen
    end
  end
end