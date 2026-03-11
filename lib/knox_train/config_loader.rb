# frozen_string_literal: true

module KnoxTrain
  class ConfigLoader
    class Error < StandardError; end

    CONFIG_ENV_KEY = 'KNOX_CONFIG'
    DEFAULT_PATHS  = [
      File.join(Dir.pwd, 'knox_train.rb'),
      File.expand_path('~/.config/knox_train/config.rb')
    ].freeze

    # Returns the first path that exists, or nil.
    # Priority: explicit_path → KNOX_CONFIG env → ./knox_train.rb → ~/.config/knox_train/config.rb
    def self.find(explicit_path: nil)
      [explicit_path, ENV.fetch(CONFIG_ENV_KEY, nil), *DEFAULT_PATHS].compact.find { |p| File.exist?(p) }
    end

    # Kernel.load (not require) so the file can be re-loaded between tests.
    # The loaded file calls KnoxTrain.configure { ... }, which sets KnoxTrain.registry.
    def self.load(path)
      Kernel.load(File.expand_path(path))
    rescue SyntaxError => e
      raise Error, "Syntax error in #{path}: #{e.message}"
    rescue LoadError => e
      raise Error, "Cannot load #{path}: #{e.message}"
    end
  end
end
