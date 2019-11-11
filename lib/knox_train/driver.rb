require 'tty-logger'

module KnoxTrain

  class Driver
    include KnoxTrain::Utils
    include KnoxTrain::Notifications
    include KnoxTrain::ConnectionTest
    include KnoxTrain::Rsync
    
    DEFAULT_OPTS = {
      logging: true,
      notifications: true,
    }

    attr_accessor :log

    def initialize opts={}
      @opts = DEFAULT_OPTS.merge opts
      @log = TTY::Logger.new
    end

    def drive &block
      begin
        timer = Timer.new
        log.info "Starting the noble train of data"
        notify "Starting the noble train of data"
        self.instance_eval(&block)
        elapsed = timer.elapsed
        log.success "Arrived successfully in #{elapsed}"
        notify "Arrived successfully in #{elapsed}"
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

    def notify message, opts = {}
      if @opts[:notifications]
        notify! message, opts
      end
    end
  end
end