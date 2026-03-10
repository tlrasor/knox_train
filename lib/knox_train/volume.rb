require "tty-logger"

module KnoxTrain
  class Volume
    POLL_INTERVAL = 3
    private_constant :POLL_INTERVAL

    attr_reader :path, :smb, :mount_timeout

    def initialize(path:, smb:, mount_timeout: 30)
      @path          = path
      @smb           = smb
      @mount_timeout = mount_timeout
      @we_mounted_it = false
    end

    # Idempotent. Raises DSL::SkipProfile if mount fails within timeout.
    def mount!
      if mounted?
        log.info "#{@path} already mounted — skipping"
        return
      end
      log.info "Mounting #{@smb} → #{@path}"
      do_mount
      poll_until(:mounted, @mount_timeout)
      @we_mounted_it = true
      log.success "#{@path} is mounted"
    rescue RuntimeError => e
      raise KnoxTrain::DSL::SkipProfile, "Could not mount #{@smb}: #{e.message}"
    end

    # Only unmounts if this instance mounted it.
    def unmount
      unless @we_mounted_it
        log.info "#{@path} was already mounted — skipping unmount"
        return
      end
      log.info "Unmounting #{@path}"
      do_unmount
      @we_mounted_it = false
      log.success "#{@path} unmounted"
    end

    # True when @path is a different filesystem device than its parent —
    # the reliable macOS check that something is actually mounted there.
    def mounted?
      File.directory?(@path) &&
        File.stat(@path).dev != File.stat(File.dirname(@path)).dev
    end

    private

    # Uses osascript to mount the SMB share. macOS creates the mountpoint in /Volumes/
    # automatically — no mkdir or sudo needed. Keychain credentials are used silently
    # (same mechanism as Finder cmd+K). Works in a LaunchAgent (user session) context.
    def do_mount
      unless system("osascript", "-e", %(mount volume "#{@smb}"))
        raise "osascript mount volume failed (exit #{$?.exitstatus})"
      end
    end

    def do_unmount
      system("diskutil", "unmount", @path)
    end

    def poll_until(desired_state, timeout)
      deadline = Time.now + timeout
      loop do
        return if (mounted? ? :mounted : :unmounted) == desired_state
        raise "Timed out after #{timeout}s waiting for #{@path} to be #{desired_state}" if Time.now >= deadline
        sleep POLL_INTERVAL
      end
    end

    def log
      @log ||= TTY::Logger.new
    end
  end
end
