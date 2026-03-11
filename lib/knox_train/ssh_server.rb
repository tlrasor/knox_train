# frozen_string_literal: true

require 'tty-logger'

module KnoxTrain
  class SshServer
    include KnoxTrain::ConnectionTest

    POLL_INTERVAL = 5 # seconds between reachability checks
    private_constant :POLL_INTERVAL

    attr_reader :host, :user, :mac, :ip, :wake_timeout, :shutdown_timeout

    def initialize(host:, user:, mac:, ip: nil, wake_timeout: 300, shutdown_timeout: 120)
      @host             = host
      @user             = user
      @mac              = mac
      @ip               = ip || host
      @wake_timeout     = wake_timeout
      @shutdown_timeout = shutdown_timeout
      @we_woke_it       = false
    end

    # Sends a Wake-on-LAN packet and blocks until the host is reachable.
    # Idempotent: does nothing if the host is already online.
    def wake
      if online?
        log.info "#{@host} already online — skipping wake"
        @we_woke_it = false
        return
      end
      log.info "Sending Wake-on-LAN to #{@host} (#{@mac})"
      Commands.new.exec("wakeonlan -i #{@ip} #{@mac}")
      poll_until(:online, @wake_timeout)
      @we_woke_it = true
      log.success "#{@host} is online"
    end

    # Shuts down the host over SSH, but only if *this instance* woke it.
    # Safe to call even if wake was never called.
    def shutdown
      unless @we_woke_it
        log.info "#{@host} was already online at backup start — skipping shutdown"
        return
      end
      log.info "Shutting down #{@host}"
      exec('/sbin/poweroff')
      poll_until(:offline, @shutdown_timeout)
      @we_woke_it = false
      log.success "#{@host} is offline"
    end

    # Returns true if the host is reachable via TCP on port 22.
    def online?
      reachable?(@ip)
    end

    # Runs a command on the host via SSH.
    def exec(command)
      Commands.new.exec("ssh -o ConnectTimeout=5 #{@user}@#{@ip} #{command}")
    end

    private

    def poll_until(desired_state, timeout)
      deadline = Time.now + timeout
      loop do
        return if (online? ? :online : :offline) == desired_state
        raise "Timed out after #{timeout}s waiting for #{@host} to be #{desired_state}" if Time.now >= deadline

        sleep POLL_INTERVAL
      end
    end

    def log
      @log ||= TTY::Logger.new
    end
  end
end
