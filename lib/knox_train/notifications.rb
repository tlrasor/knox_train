require 'os'

module KnoxTrain
  module Notifications

    # Asset path for the Henry Knox image
    ASSET_IMAGE = File.expand_path("../assets/henry-knox.jpg", __FILE__)

    # Default notification options
    # Uses contentImage to display the image in the notification body
    DEFAULT_OPTS = {
      title: "The noble train of data",
      contentImage: ASSET_IMAGE,
      group: "KnoxTrain"
    }

    if OS.mac?
      require "terminal-notifier"

      # Send a notification with pretty formatting
      #
      # Usage:
      #   notify!("Backup complete", activate: true)
      #   notify!("Status check finished")
      #
      # Options:
      #   :activate  - bring notification to front (default: false for success)
      #   :title     - override default title
      #   :appIcon   - override image path
      #   :group     - notification group (default: "KnoxTrain")
      #   :sound     - play sound (default: none)
      #
      def notify! message, opts = {}
        opts = DEFAULT_OPTS.merge opts
        TerminalNotifier.notify(message, opts)
      end
    else
      # Non-macOS: no-op (silently skip)
      def notify! message, opts = {}
      end
    end
  end
end
