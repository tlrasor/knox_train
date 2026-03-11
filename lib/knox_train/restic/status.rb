# frozen_string_literal: true

require 'json'
require 'shellwords'
require 'tty-which'

module KnoxTrain
  module Restic
    class Status
      RESTIC_BIN = TTY::Which.which('restic') || 'restic'
      private_constant :RESTIC_BIN

      SnapshotData = Struct.new(
        :profile_name, :backend_type,
        :snapshot_count, :latest_time,
        :file_count, :restore_bytes, :stored_bytes
      )

      def initialize(profile, backend, commands: Commands.new(printer: :null))
        @profile  = profile
        @backend  = backend
        @commands = commands
      end

      # Fetches JSON data from restic. Returns SnapshotData.
      # Raises TTY::Command::ExitError if restic exits non-zero.
      # run_before/run_after hooks are invoked (e.g. NAS wake/shutdown for SFTP backends).
      def fetch
        run_hooks(@backend.run_befores)
        begin
          with_env(build_env) do
            snapshots = parse_json(@commands.exec(snapshots_cmd).out, [])
            stats     = parse_json(@commands.exec(stats_cmd).out, {})
            raw       = parse_json(@commands.exec(raw_stats_cmd).out, {})

            SnapshotData.new(
              profile_name: @profile.name,
              backend_type: @backend.type,
              snapshot_count: snapshots.length,
              latest_time: snapshots.any? ? snapshots.map { |s| s['time'] }.max : nil,
              file_count: stats['total_file_count'] || 0,
              restore_bytes: stats['total_size'] || 0,
              stored_bytes: raw['total_size'] || 0
            )
          end
        ensure
          run_hooks(@backend.run_afters)
        end
      end

      # Returns raw output strings for --verbose mode (no --json flag).
      # Raises TTY::Command::ExitError if restic exits non-zero.
      # run_before/run_after hooks are invoked (e.g. NAS wake/shutdown for SFTP backends).
      def fetch_verbose
        run_hooks(@backend.run_befores)
        begin
          with_env(build_env) do
            {
              snapshots: @commands.exec(snapshots_cmd(json: false)).out,
              stats: @commands.exec(stats_cmd(json: false)).out,
              raw: @commands.exec(raw_stats_cmd(json: false)).out
            }
          end
        ensure
          run_hooks(@backend.run_afters)
        end
      end

      private

      def with_env(env)
        saved = env.keys.to_h { |k| [k, ENV.fetch(k, nil)] }
        env.each { |k, v| ENV[k] = v }
        yield
      ensure
        saved.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
      end

      def build_env
        env = {}
        env['RESTIC_PASSWORD'] = @backend.password.call if @backend.password
        @backend.env_credentials.each { |var, proc| env[var] = proc.call }
        env
      end

      def snapshots_cmd(json: true)
        args = [RESTIC_BIN, '-r', @backend.repo, 'snapshots']
        args += @profile.tags.flat_map { |t| ['--tag', t] } if @profile.tags&.any?
        args << '--json' if json
        Shellwords.shelljoin(args)
      end

      def stats_cmd(json: true)
        args = [RESTIC_BIN, '-r', @backend.repo, 'stats']
        args += @profile.tags.flat_map { |t| ['--tag', t] } if @profile.tags&.any?
        args << '--json' if json
        Shellwords.shelljoin(args)
      end

      def raw_stats_cmd(json: true)
        args = [RESTIC_BIN, '-r', @backend.repo, 'stats', '--mode', 'raw-data']
        args += @profile.tags.flat_map { |t| ['--tag', t] } if @profile.tags&.any?
        args << '--json' if json
        Shellwords.shelljoin(args)
      end

      def run_hooks(hooks)
        hooks.each(&:call)
      end

      def parse_json(str, default)
        JSON.parse(str)
      rescue JSON::ParserError
        default
      end
    end
  end
end
