module KnoxTrain
  module ConnectionTest

    DEFAULT_SERVER = ENV["CT_DEFAULT_SERVER"] || ""
    DEFAULT_PORT = ENV["CT_DEFAULT_PORT"] || "22"

    def reachable? server=DEFAULT_SERVER, port: DEFAULT_PORT
      if (server.nil? || server.empty?)
        return false
      end
      args = { "server_ip" => server,  "server_port" => port.to_s }
      cmd = 'timeout 1 bash -c "cat < /dev/null > /dev/tcp/${server_ip}/${server_port}" > /dev/null 2>&1'
      system(args, cmd)
    end

    def unreachable? server=DEFAULT_SERVER, port: DEFAULT_PORT
      !reachable?(server, port: port)
    end

    # Works like #reachable? but throws on errors
    def test! server, opts = {}
      raise ArgumentError.new("No server specified. Expected an ip or domain name") if (server.nil? || server.empty?)
      raise("Unable to reach server #{server}!") unless reachable?(server, opts)
    end
  end
end