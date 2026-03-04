require "knox_train/profile"
require "knox_train/ssh_server"

module KnoxTrain
  module DSL

    # ── Exceptions ─────────────────────────────────────────────────────────
    class UnknownKeyError < StandardError; end
    class ValidationError < StandardError; end

    # ── GlobalConfig ────────────────────────────────────────────────────────
    GlobalConfig = Struct.new(:priority, :notifications, keyword_init: true)

    # ── GlobalDSL ──────────────────────────────────────────────────────────
    # Evaluated inside `global do ... end` blocks.
    class GlobalDSL
      def initialize
        @priority      = :normal
        @notifications = true
      end

      def priority(val)      = @priority      = val
      def notifications(val) = @notifications = val

      def method_missing(name, *_args, &_block)
        loc = caller_locations(1, 1).first
        raise UnknownKeyError,
              "Unknown global key '#{name}' at #{loc.absolute_path}:#{loc.lineno}"
      end

      def respond_to_missing?(_name, _include_private = false) = false

      def build
        GlobalConfig.new(priority: @priority, notifications: @notifications)
      end
    end

    # ── BackendDSL ─────────────────────────────────────────────────────────
    # Evaluated inside `backend :type do ... end` blocks.
    class BackendDSL
      VALID_RETENTION_KEYS = %i[daily weekly monthly yearly].freeze

      def initialize(type)
        @type        = type.to_sym
        @repo        = nil
        @password    = nil
        @retention   = nil
        @run_befores = []
        @run_afters  = []
      end

      def repo(string)     = @repo     = string
      def password(&block) = @password = block

      # Accepts a hash: retention daily: 30, weekly: 52
      # or a hash variable: retention NAS_RETENTION
      # Ruby treats a trailing symbol-keyed hash as a positional arg.
      def retention(hash)
        unknown = hash.keys - VALID_RETENTION_KEYS
        unless unknown.empty?
          loc = caller_locations(1, 1).first
          raise UnknownKeyError,
                "Unknown retention keys #{unknown.inspect} at #{loc.absolute_path}:#{loc.lineno}"
        end
        @retention = hash
      end

      def run_before(&block) = @run_befores << block
      def run_after(&block)  = @run_afters  << block

      def method_missing(name, *_args, &_block)
        loc = caller_locations(1, 1).first
        raise UnknownKeyError,
              "Unknown backend key '#{name}' at #{loc.absolute_path}:#{loc.lineno}"
      end

      def respond_to_missing?(_name, _include_private = false) = false

      def build
        Backend.new(
          type:        @type,
          repo:        @repo,
          password:    @password,
          retention:   @retention,
          run_befores: @run_befores,
          run_afters:  @run_afters
        )
      end
    end

    # ── ProfileDSL ─────────────────────────────────────────────────────────
    # Evaluated inside `profile :name do ... end` blocks.
    class ProfileDSL
      def initialize(name)
        @name          = name.to_sym
        @sources       = []
        @exclude_files = []
        @tags          = []
        @host          = false
        @backends      = []
      end

      # Accepts a string path OR a block:
      #   source "~/Documents"
      #   source { path = "/Volumes/photos"; skip! "not mounted" unless File.directory?(path); path }
      # The block is stored as a Proc and NOT evaluated in Phase 2.
      def source(path = nil, &block)
        @sources << (block || path)
      end

      def exclude_file(path) = @exclude_files << path
      def tags(arr)          = @tags = arr
      def host(val = true)   = @host = val

      def backend(type, &block)
        dsl = BackendDSL.new(type)
        dsl.instance_eval(&block)
        @backends << dsl.build
      end

      def method_missing(name, *_args, &_block)
        loc = caller_locations(1, 1).first
        raise UnknownKeyError,
              "Unknown profile key '#{name}' at #{loc.absolute_path}:#{loc.lineno}"
      end

      def respond_to_missing?(_name, _include_private = false) = false

      def build
        Profile.new(
          name:          @name,
          sources:       @sources,
          exclude_files: @exclude_files,
          tags:          @tags,
          host:          @host,
          backends:      @backends
        )
      end
    end

    # ── ConfigContext ──────────────────────────────────────────────────────
    # Top-level instance_eval target for KnoxTrain.configure blocks.
    class ConfigContext
      attr_reader :profiles, :groups

      def initialize
        @profiles = {}
        @groups   = {}
        @global   = nil
      end

      def profile(name, &block)
        key = name.to_sym
        if @profiles.key?(key)
          raise UnknownKeyError, "Profile '#{key}' declared more than once"
        end
        dsl = ProfileDSL.new(key)
        dsl.instance_eval(&block)
        @profiles[key] = dsl.build
      end

      # DSL setter (with block) and reader (without block).
      def global(&block)
        if block
          dsl = GlobalDSL.new
          dsl.instance_eval(&block)
          @global = dsl.build
        else
          @global
        end
      end

      # Creates a data-only SshServer object. Operational methods (wake/shutdown)
      # are added in Phase 4. The returned object is typically assigned to a local
      # variable in the configure block and closed over by run_before/run_after blocks.
      def ssh_server(**opts)
        KnoxTrain::SshServer.new(**opts)
      end

      def group(name, profile_names)
        @groups[name.to_sym] = profile_names.map(&:to_sym)
      end

      # Runs after the configure block completes. Validates all profiles with
      # dry-schema. Raises ValidationError with all failure messages if any fail.
      def validate!
        require "knox_train/schema"
        errors = []

        @profiles.each do |name, profile|
          # Profile-level: sources and backends just need to be non-empty arrays
          profile_result = KnoxTrain::Schema::ProfileSchema.call(
            name:          profile.name,
            sources:       profile.sources,
            exclude_files: profile.exclude_files || [],
            tags:          profile.tags || [],
            host:          profile.host,
            backends:      profile.backends
          )
          errors << "Profile '#{name}': #{profile_result.errors.to_h}" unless profile_result.success?

          # Backend-level: strip proc fields (password, hooks) before schema call
          profile.backends.each do |backend|
            backend_data = { type: backend.type, repo: backend.repo }
            backend_data[:retention] = backend.retention if backend.retention
            backend_result = KnoxTrain::Schema::BackendSchema.call(backend_data)
            unless backend_result.success?
              errors << "Profile '#{name}', backend '#{backend.type}': #{backend_result.errors.to_h}"
            end
          end
        end

        raise ValidationError, errors.join("\n") unless errors.empty?
      end

      def method_missing(name, *_args, &_block)
        loc = caller_locations(1, 1).first
        raise UnknownKeyError,
              "Unknown DSL keyword '#{name}' at #{loc.absolute_path}:#{loc.lineno}"
      end

      def respond_to_missing?(_name, _include_private = false) = false
    end

  end
end
