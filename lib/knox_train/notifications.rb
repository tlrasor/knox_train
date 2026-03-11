# frozen_string_literal: true

require 'os'

module KnoxTrain
  module Notifications
    # Asset path for the Henry Knox image
    ASSET_IMAGE = File.expand_path('assets/henry-knox.jpg', __dir__)

    # Default notification options
    # Note: The console icon on the left is a macOS limitation for CLI tools
    # (the app icon comes from terminal-notifier itself). The Henry Knox image
    # displays on the right side in the notification body via contentImage.
    DEFAULT_OPTS = {
      title: 'The noble train of data',
      contentImage: ASSET_IMAGE,
      group: 'KnoxTrain'
    }.freeze

    if OS.mac?
      require 'terminal-notifier'

      # Send a notification with pretty formatting
      #
      # Terminal-notifier displays notifications via macOS Notification Center.
      # The console app icon (left) comes from terminal-notifier itself.
      # The Henry Knox image (right) is the contentImage.
      #
      # To fully replace the app icon would require creating a custom .app bundle,
      # which is impractical for a CLI tool. The current setup provides:
      # - Clear title: "The noble train of data"
      # - Pretty multi-line messages
      # - Historical Henry Knox image for visual context
      #
      # Usage:
      #   notify!("Backup complete", activate: true)
      #   notify!("Status check finished")
      #
      # Options:
      #   :activate    - bring notification to front (default: false for success)
      #   :title       - override default title
      #   :group       - notification group (default: "KnoxTrain")
      #
      def notify!(message, opts = {})
        opts = DEFAULT_OPTS.merge(opts)
        TerminalNotifier.notify(message, opts)
      end
    else
      # Non-macOS: no-op (silently skip)
      def notify!(message, opts = {}); end
    end
  end
end
