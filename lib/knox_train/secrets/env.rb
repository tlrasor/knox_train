require "knox_train/secrets/keychain"   # ensures Secrets::Error is defined

module KnoxTrain
  module Secrets
    module Env
      # Returns the value of the named environment variable.
      # Raises Secrets::Error if the variable is absent or empty.
      #
      #   password { env_secret("RESTIC_PASSWORD") }  # non-macOS fallback
      #
      def self.fetch(var_name)
        value = ENV[var_name]
        if value.nil? || value.empty?
          raise Error, "Environment variable '#{var_name}' is not set or empty"
        end
        value
      end
    end
  end
end
