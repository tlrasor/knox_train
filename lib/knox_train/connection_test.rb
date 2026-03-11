# frozen_string_literal: true

module KnoxTrain
  module ConnectionTest
    DEFAULT_SERVER = ENV['CT_DEFAULT_SERVER'] || ''
    DEFAULT_PORT = ENV['CT_DEFAULT_PORT'] || '22'
    DEFAULT_TIMEOUT = ENV['CT_DEFAULT_TIMEOUT'] || '3'

    DEFAULT_OPTIONS = {
      port: DEFAULT_PORT,
      timeout: DEFAULT_TIMEOUT
    }.freeze

    def reachable?(server = DEFAULT_SERVER, **opts)
      opts = DEFAULT_OPTIONS.merge(opts)
      return false if server.nil? || server.empty?

      args = { 'server_ip' => server,  'server_port' => opts[:port].to_s, 't' => opts[:timeout].to_s }
      cmd = "timeout $t bash -c 'cat < /dev/null > /dev/tcp/${server_ip}/${server_port}' > /dev/null 2>&1"
      system(args, cmd)
    end

    def unreachable?(server = DEFAULT_SERVER, **)
      !reachable?(server, **)
    end

    # Works like #reachable? but throws on errors
    def reachable!(server, **)
      raise ArgumentError, 'No server specified. Expected an ip or domain name' if server.nil? || server.empty?
      return if reachable?(server, **)

      raise("Unable to reach server #{server}!")
    end
  end
end
