module KnoxTrain
  class SshServer
    attr_reader :host, :user, :mac, :ip, :wake_timeout, :shutdown_timeout

    def initialize(host:, user:, mac:, ip: nil, wake_timeout: 300, shutdown_timeout: 120)
      @host             = host
      @user             = user
      @mac              = mac
      @ip               = ip || host
      @wake_timeout     = wake_timeout
      @shutdown_timeout = shutdown_timeout
    end
  end
end
