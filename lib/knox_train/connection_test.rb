module KnoxTrain
  module ConnectionTest

    DEFAULT_SERVER = ENV["CT_DEFAULT_SERVER"] || ""
    DEFAULT_PORT = ENV["CT_DEFAULT_PORT"] || "22"
    DEFAULT_TIMEOUT = ENV["CT_DEFAULT_PORT"] || "3"
    
    DEFAULT_OPTIONS = {
      port: DEFAULT_PORT, 
      timeout: DEFAULT_TIMEOUT
    }.freeze

    def reachable? server=DEFAULT_SERVER, **opts
      opts = DEFAULT_OPTIONS.merge(opts)
      if (server.nil? || server.empty?)
        return false
      end
      args = { "server_ip" => server,  "server_port" => opts[:port].to_s, "t" => opts[:timeout].to_s }
      cmd = "timeout $t bash -c 'cat < /dev/null > /dev/tcp/${server_ip}/${server_port}' > /dev/null 2>&1"
      system(args, cmd)
    end

    def unreachable? server=DEFAULT_SERVER, opts = {}
      !reachable?(server, **opts)
    end

    # Works like #reachable? but throws on errors
    def reachable! server, opts = {}
      if (server.nil? || server.empty?)
        raise ArgumentError.new("No server specified. Expected an ip or domain name") 
      end
      unless reachable?(server, opts)
        raise("Unable to reach server #{server}!") 
      end
    end
  end
end