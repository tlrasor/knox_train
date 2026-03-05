require "erb"
require "fileutils"
require "tty-which"

module KnoxTrain
  module Scheduler
    class Launchd
      LABEL  = "local.knox"
      BINARY = TTY::Which.which("knox") || "/opt/homebrew/bin/knox"
      private_constant :BINARY

      PLIST_DIR = File.expand_path("~/Library/LaunchAgents")
      LOG_DIR   = File.expand_path("~/Library/Logs/knox")
      private_constant :PLIST_DIR, :LOG_DIR

      TEMPLATE = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
          "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>Label</key>
          <string><%= LABEL %></string>
          <key>ProgramArguments</key>
          <array>
            <string><%= BINARY %></string>
            <string>backup</string>
            <string>--all</string>
          </array>
          <key>EnvironmentVariables</key>
          <dict>
            <key>KNOX_CONFIG</key>
            <string><%= @config_path %></string>
          </dict>
          <key>StartCalendarInterval</key>
          <dict>
            <key>Hour</key>
            <integer><%= @hour %></integer>
            <key>Minute</key>
            <integer><%= @minute %></integer>
          </dict>
          <key>StandardOutPath</key>
          <string><%= File.join(LOG_DIR, "backup.log") %></string>
          <key>StandardErrorPath</key>
          <string><%= File.join(LOG_DIR, "backup.log") %></string>
        </dict>
        </plist>
      XML
      private_constant :TEMPLATE

      def initialize(config_path: nil, hour: nil, minute: nil)
        @config_path = config_path
        @hour        = hour
        @minute      = minute
      end

      def install
        ensure_log_dir
        launchctl("unload", plist_path) if File.exist?(plist_path)
        File.write(plist_path, ERB.new(TEMPLATE, trim_mode: "-").result(binding))
        launchctl("load", plist_path)
      end

      def uninstall
        return unless File.exist?(plist_path)
        launchctl("unload", plist_path)
        File.delete(plist_path)
      end

      def plist_path
        File.join(PLIST_DIR, "#{LABEL}.plist")
      end

      private

      def ensure_log_dir
        FileUtils.mkdir_p(LOG_DIR)
      end

      def launchctl(subcommand, path)
        system("launchctl", subcommand, path)
      end
    end
  end
end
