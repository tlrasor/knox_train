module KnoxTrain

  class Driver
    include KnoxTrain::Utils
    include KnoxTrain::Notifications
    include KnoxTrain::ConnectionTest
    include KnoxTrain::Rsync
    include KnoxTrain::Timer
    
    DEFAULT_OPTS = {
      logging: true,
      notifications: true,
    }

    def initialize opts={}
      @opts = DEFAULT_OPTS.merge opts
    end

    def drive &block
      begin
        start_timer!
        log "Starting the noble train of data"
        notify "Starting the noble train of data"
        self.instance_eval(&block)
        log "Arrived successfully in #{stop_timer!}"
        notify "Arrived successfully in #{stop_timer!}"
      rescue
        notify "Encountered error processing train: #{$!}"
        abort! "Encountered error processing train: #{$!}"
      end
    end

    def get key
      @opts[key.to_sym]
    end

    def set key, value=true
      if key.is_a?(Hash)
        @opts.merge! key
      else
        @opts[key.to_sym] = value
      end
    end

    private

    def log message
      if @opts[:logging]
        puts format_log_message(message)
      end
    end

    def log_error message
      if @opts[:logging]
        STDERR.puts format_log_message(message)
      end
    end

    def notify message, opts = {}
      if @opts[:notifications]
        notify! message, opts
      end
    end
  end
end