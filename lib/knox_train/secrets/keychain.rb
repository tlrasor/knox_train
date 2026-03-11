# frozen_string_literal: true

require 'open3'

module KnoxTrain
  module Secrets
    class Error < StandardError; end

    module Keychain
      SECURITY_BIN = '/usr/bin/security'
      private_constant :SECURITY_BIN

      # Returns true if the macOS security binary is present and executable.
      def self.available?
        File.executable?(SECURITY_BIN)
      end

      # Fetches a password from the macOS Keychain.
      # Called at execution time (Phase 4), inside a stored password Proc.
      #
      #   password { keychain("restic-documents") }  # proc stored at declaration
      #   backend.password.call                       # calls this at execution
      #
      # Raises Secrets::Error if:
      #   - /usr/bin/security is not executable (non-macOS or missing)
      #   - security exits non-zero (entry not found, permission denied, etc.)
      def self.fetch(service)
        unless available?
          raise Error, "macOS Keychain not available (#{SECURITY_BIN} not found). " \
                       'Use env_secret() as a non-macOS fallback.'
        end

        account = ENV.fetch('USER', ENV.fetch('LOGNAME', nil))
        stdout, stderr, status = Open3.capture3(
          SECURITY_BIN, 'find-generic-password', '-s', service.to_s, '-a', account.to_s, '-w'
        )

        raise Error, "Keychain lookup failed for service '#{service}': #{stderr.strip}" unless status.success?

        stdout.chomp
      end
    end
  end
end
