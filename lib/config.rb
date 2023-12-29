require 'async'
require 'socket'

require 'yaml'
CONFIG = YAML.load_file 'config.yml'

def server
  Sync do
    svr = TCPServer.new CONFIG['bind-port']
    puts "listening on #{CONFIG['bind-port']}"
    loop do
      Async(svr.accept) do |_,sock|
        yield sock
      end
    end
  end
end
