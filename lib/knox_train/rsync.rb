# frozen_string_literal: true

require 'tty-which'
module KnoxTrain
  RSYNC_PATH = TTY::Which.which('rsync')
  NICE_PATH = TTY::Which.which('nice')
  IONICE_PATH = TTY::Which.which('ionice')

  module Rsync
    # equivalent to rsync -azp --delete --append --partial
    def rsync!(src:, dest:, **opts)
      batch = Batch.new(opts)
      batch.add src, dest
      batch.sync!
    end

    def rsync(opts = {})
      Batch.new(opts)
    end

    class Batch
      DEFAULT_OPTS = {
        archive: true,
        compress: true,
        quiet: true,
        partial: true,
        append: true
      }.freeze

      def initialize(opts = {})
        @opts = DEFAULT_OPTS.merge! opts
        @reqs = []
      end

      def opt(key, value = true)
        @opts[key] = value
      end

      def opts(options = {})
        @opts.merge! options
      end

      def add(source, dest, opts = {})
        raise "Unable to add src: #{source}, dest: #{dest}" unless source && dest

        @reqs << { src: source, dest: dest, opts: opts }
        self
      end

      def add_all(sources, dest, opts = {})
        sources.each { |s| add s, dest, opts }
        self
      end

      def <<(pair)
        @reqs << pair if pair[:src] && pair[:dest]
        self
      end

      def sync!
        @reqs.each do |r|
          cmd = r[:opts] ? make_cmd(r[:opts]) : make_cmd
          cmd = "#{cmd} #{r[:src]} #{r[:dest]}"
          raise("command '#{cmd}' exited with error!") unless system(cmd)

          yield(r[:src], r[:dest]) if block_given?
        end
      end

      private

      def make_cmd(overrides = {})
        rsync_opts = @opts.merge overrides
        cmd = []
        if rsync_opts[:nice]
          raise(':nice specified but nice cannot be found on path') if NICE_PATH.nil?

          cmd << "#{NICE_PATH} -n 19"
        end
        if rsync_opts[:ionice]
          raise(':ionice specified but ionice cannot be found on path') if IONICE_PATH.nil?

          cmd << "#{IONICE_PATH} -c2 -n7"
        end
        cmd << RSYNC_PATH
        cmd << '-a' if rsync_opts[:archive]
        cmd << '-z' if rsync_opts[:compress]
        if rsync_opts[:verbose]
          rsync_opts[:quiet] = false
          cmd << '-v'
        end
        cmd << '-q' if rsync_opts[:quiet]
        cmd << '--progress' if rsync_opts[:progress]
        cmd << '--partial' if rsync_opts[:partial]
        cmd << '--append' if rsync_opts[:append]
        cmd << '--delete' if rsync_opts[:delete]
        if rsync_opts[:bwlimit]
          limit = @opts[:bwlimit].to_i
          cmd << "--bwlimit #{limit}"
        end
        cmd.join(' ')
      end
    end
  end
end
