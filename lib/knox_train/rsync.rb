require "knox_train/shell"

module KnoxTrain

  RSYNC_PATH = which?("rsync") || raise("Unable to find rsync on on system $PATH")
  NICE_PATH = which?("nice")
  IONICE_PATH = which?("ionice")

  module Rsync

    # equivalent to rsync -azp --delete --append --partial
    def sync src:, dest:, **opts
      batch = Batch.new(opts)
      batch.add src, dest
      batch.sync!
    end

    def batch opts={}
      Batch.new(opts)
    end

    class Batch
      DEFAULT_OPTS = {
          archive: true,
          compress: true,
          quiet: true,
          partial: true,
          append: true
      }

      def initialize opts = {}
        @opts = DEFAULT_OPTS.merge! opts
        @reqs = []
      end

      def opt key, value=true
        @opts[key] = value
      end

      def opts options={}
        @opts.merge! options
      end

      def add source, dest, opts={}
        unless source && dest
          raise "Unable to add src: #{source}, dest: #{dest}"
        end
        @reqs << {src: source, dest: dest, opts: opts}
      end

      def add_all sources, dest, opts={}
        source ||= []
        sources.each {|s| add s, dest, opts }
      end

      def << pair
        if pair[:src] && pair[:dest]
          @reqs << pair
        end
      end

      def sync!
        @reqs.each do |r|
          cmd = r[:opts] ? make_cmd(r[:opts]) : make_cmd
          cmd = "#{cmd} #{r[:src]} #{r[:dest]}"
          unless system(cmd) 
            raise("command '#{cmd}' exited with error!")
          end
          if block_given?
            yield(r[:src], r[:dest])
          end
        end
      end

      private

      def make_cmd overrides={}
        rsync_opts = @opts.merge overrides
        cmd = []
        if rsync_opts[:nice]
          if NICE_PATH.nil?
            raise(":nice specified but nice cannot be found on path")
          end
          cmd << "#{NICE_PATH} -n 19"
        end
        if rsync_opts[:ionice]
          if IONICE_PATH.nil?
            raise(":ionice specified but ionice cannot be found on path")
          end
          cmd << "#{IONICE_PATH} -c2 -n7"
        end
        cmd << RSYNC_PATH
        if rsync_opts[:archive]
          cmd << "-a"
        end
        if rsync_opts[:compress]
          cmd << "-z"
        end
        if rsync_opts[:verbose]
          rsync_opts[:quiet] = false
          cmd << "-v"
        end
        if rsync_opts[:quiet]
          cmd << "-q"
        end
        if rsync_opts[:progress]
          cmd << "--progress"
        end
        if rsync_opts[:partial]
          cmd << "--partial"
        end
        if rsync_opts[:append]
          cmd << "--append"
        end
        if rsync_opts[:delete]
          cmd << "--delete"
        end
        if rsync_opts[:bwlimit]
          limit = @opts[:bwlimit].to_i
          cmd << "--bwlimit #{limit}"
        end
        cmd.join(' ')
      end
    end
  end
end