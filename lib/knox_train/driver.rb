# frozen_string_literal: true

require 'English'
require 'tty-logger'

module KnoxTrain
  class Driver
    include KnoxTrain::Utils
    include KnoxTrain::Notifications
    include KnoxTrain::ConnectionTest

    DEFAULT_OPTS = {
      logging: true,
      notifications: true
    }.freeze

    attr_accessor :log

    def initialize(opts = {})
      @opts = DEFAULT_OPTS.merge opts
      @log = TTY::Logger.new
    end

    def drive(&)
      timer = Timer.new
      log.info 'Starting the noble train of data'
      notify 'Starting the noble train of data'
      instance_eval(&)
      elapsed = timer.elapsed
      log.success "Arrived successfully in #{elapsed}"
      notify "Arrived successfully in #{elapsed}"
    rescue StandardError
      notify "Encountered error processing train: #{$ERROR_INFO}"
      abort! "Encountered error processing train: #{$ERROR_INFO}"
    end

    def get(key)
      @opts[key.to_sym]
    end

    def set(key, value = true)
      if key.is_a?(Hash)
        @opts.merge! key
      else
        @opts[key.to_sym] = value
      end
    end

    private

    def notify(message, opts = {})
      return unless @opts[:notifications]

      notify! message, opts
    end
  end
end
