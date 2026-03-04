require "shellwords"
require "socket"
require "tty-logger"
require "tty-which"

module KnoxTrain
  module Restic
    class Runner
      # Resolved at require time. Falls back to bare "restic" (PATH lookup at runtime).
      RESTIC_BIN       = TTY::Which.which("restic") || "restic"
      # True on Linux with ionice installed; false on macOS (not available).
      # Commands#exec raises if ionice: true is passed but ionice is not on PATH,
      # so we gate on availability here rather than at each call site.
      IONICE_AVAILABLE = !TTY::Which.which("ionice").nil?
      private_constant :RESTIC_BIN, :IONICE_AVAILABLE

      def initialize(profile, backend, prune: false, commands: Commands.new)
        @profile  = profile
        @backend  = backend
        @prune    = prune
        @commands = commands
      end

      # Runs the full backup sequence for one (profile, backend) pair.
      # Raises DSL::SkipProfile if a source block calls skip! — caller handles it.
      # Raises TTY::Command::ExitError if restic exits non-zero.
      # run_after hooks always run (ensure) so NAS lifecycle cleanup is unconditional.
      def run
        sources = resolve_sources   # may raise SkipProfile before hooks start
        begin
          run_hooks(@backend.run_befores)
          with_env(build_env) do
            @commands.exec(backup_cmd(sources), nice: true, ionice: IONICE_AVAILABLE)
            if @prune && @backend.retention
              @commands.exec(forget_cmd, nice: true, ionice: IONICE_AVAILABLE)
            end
          end
        ensure
          run_hooks(@backend.run_afters)
        end
      end

      private

      def resolve_sources
        @profile.sources.map do |src|
          path = src.is_a?(Proc) ? src.call : src
          File.expand_path(path.to_s)
        end
      end

      # Sets env vars for the duration of the block, then restores originals.
      def with_env(env)
        saved = env.keys.each_with_object({}) { |k, h| h[k] = ENV[k] }
        env.each { |k, v| ENV[k] = v }
        yield
      ensure
        saved.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
      end

      # Resolves the password proc and all env_credential procs into a hash.
      def build_env
        env = {}
        env["RESTIC_PASSWORD"] = @backend.password.call if @backend.password
        @backend.env_credentials.each { |var, proc| env[var] = proc.call }
        env
      end

      def backup_cmd(sources)
        args = [RESTIC_BIN, "-r", @backend.repo, "backup", *sources,
                "--host", hostname, "--exclude-caches", "--one-file-system"]
        args += @profile.tags.flat_map { |t| ["--tag", t] } if @profile.tags&.any?
        if @profile.exclude_files&.any?
          args += @profile.exclude_files.flat_map { |f| ["--exclude-file", File.expand_path(f)] }
        end
        Shellwords.shelljoin(args)
      end

      def forget_cmd
        ret  = @backend.retention
        args = [RESTIC_BIN, "-r", @backend.repo, "forget",
                "--host", hostname, "--prune"]
        args += @profile.tags.flat_map { |t| ["--tag", t] } if @profile.tags&.any?
        args += ["--keep-daily",   ret[:daily].to_s]   if ret[:daily]
        args += ["--keep-weekly",  ret[:weekly].to_s]  if ret[:weekly]
        args += ["--keep-monthly", ret[:monthly].to_s] if ret[:monthly]
        args += ["--keep-yearly",  ret[:yearly].to_s]  if ret[:yearly]
        Shellwords.shelljoin(args)
      end

      def run_hooks(hooks)
        hooks.each(&:call)
      end

      def hostname
        @hostname ||= Socket.gethostname
      end

      def log
        @log ||= TTY::Logger.new
      end
    end
  end
end
