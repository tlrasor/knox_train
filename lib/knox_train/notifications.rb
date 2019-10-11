require 'os'

module KnoxTrain
  module Notifications

    DEFAULT_OPTS = {
      title: "The noble train of data",
      appIcon: "https://i.imgur.com/b3rhnzJ.png",
      group: "KnoxTrain"
    }

    if OS.mac?
      require "terminal-notifier"
      
      # Makes a notification, see terminal-notifier doc:
      #
      ## The available options are `:appIcon`, `:title`, `:group`, `:activate`, `:open`,
      ## `:execute`, `:sender`, and `:sound`. For a description of each option see:
      def notify message, opts={}
        opts = DEFAULT_OPTS.merge opts
        TerminalNotifier.notify(message, opts)
      end
    else
      puts "Warning: Notifications are only supported on macos. Notifications will be no-ops."
      def notify message, opts={}
      end
    end
  end
end
