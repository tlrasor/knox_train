require "thor"
require "knox_train/version"
require "knox_train/config_loader"
require "knox_train/dsl"
require "knox_train/profile"
require "knox_train/schema"
require "knox_train/ssh_server"
require "knox_train/restic/runner"
require "knox_train/restic/status"
require "time"
require "tty-table"

module KnoxTrain
  class CLI < Thor
    def self.exit_on_failure? = true

    class_option :config, aliases: "-c", type: :string,
                          desc: "Path to config file (default: ./knox_train.rb)"

    desc "version", "Print knox version"
    def version
      puts "knox #{KnoxTrain::VERSION}"
    end

    desc "backup", "Run restic backups"
    option :profile, aliases: "-p", type: :string,  desc: "Profile name"
    option :backend, aliases: "-b", type: :string,  desc: "Backend (sftp, b2, s3)"
    option :all,                    type: :boolean, desc: "Run all profiles"
    option :prune,                  type: :boolean, desc: "Apply retention policy after backup"
    def backup
      path = options[:config] || KnoxTrain::ConfigLoader.find
      unless path
        say "No config file found. Use -c PATH to specify.", :red
        exit 1
      end
      KnoxTrain::ConfigLoader.load(path)
      reg = KnoxTrain.registry

      profiles = if options[:all]
                   reg.profiles.values
                 elsif options[:profile]
                   p = reg.profiles[options[:profile].to_sym]
                   unless p
                     say "Profile '#{options[:profile]}' not found.", :red
                     exit 1
                   end
                   [p]
                 else
                   say "Specify --profile NAME or --all", :red
                   exit 1
                 end

      backend_filter = options[:backend]&.to_sym
      prune          = options[:prune] || false
      had_error      = false

      profiles.each do |profile|
        backends = profile.backends
        backends = backends.select { |b| b.type == backend_filter } if backend_filter
        backends.each do |backend|
          KnoxTrain::Restic::Runner.new(profile, backend, prune: prune).run
        rescue KnoxTrain::DSL::SkipProfile => e
          say "Skipping #{profile.name}: #{e.message}", :yellow
        rescue TTY::Command::ExitError => e
          say "✗ #{profile.name}/#{backend.type}: #{e.message}", :red
          had_error = true
        end
      end

      exit 1 if had_error
    rescue KnoxTrain::DSL::UnknownKeyError, KnoxTrain::DSL::ValidationError,
           KnoxTrain::ConfigLoader::Error => e
      say "✗ #{e.message}", :red
      exit 1
    end

    desc "status", "Show snapshot status"
    option :backend, aliases: "-b", type: :string,  desc: "Backend (sftp, b2, s3)"
    option :verbose, aliases: "-v", type: :boolean, desc: "Full restic output"
    def status
      path = options[:config] || KnoxTrain::ConfigLoader.find
      unless path
        say "No config file found. Use -c PATH to specify.", :red
        exit 1
      end
      KnoxTrain::ConfigLoader.load(path)
      reg = KnoxTrain.registry

      backend_filter = options[:backend]&.to_sym
      verbose        = options[:verbose] || false
      rows           = []

      reg.profiles.values.each do |profile|
        backends = profile.backends
        backends = backends.select { |b| b.type == backend_filter } if backend_filter
        backends.each do |backend|
          checker = KnoxTrain::Restic::Status.new(profile, backend)
          if verbose
            print_status_verbose(profile, backend, checker)
          else
            rows << checker.fetch
          end
        rescue TTY::Command::ExitError => e
          say "✗ #{profile.name}/#{backend.type}: #{e.message}", :red
        end
      end

      print_status_table(rows) unless verbose
    rescue KnoxTrain::DSL::UnknownKeyError, KnoxTrain::DSL::ValidationError,
           KnoxTrain::ConfigLoader::Error => e
      say "✗ #{e.message}", :red
      exit 1
    end

    desc "schedule", "Install launchd backup schedule"
    option :all,  type: :boolean, desc: "Schedule all profiles"
    option :time, aliases: "-t", type: :string, desc: "Daily backup time (HH:MM, e.g. 02:00)"
    def schedule
      unless options[:all]
        say "Specify --all (per-profile scheduling not yet supported)", :red
        exit 1
      end
      unless options[:time] =~ /\A([01]?\d|2[0-3]):\d{2}\z/
        say "Specify --time HH:MM, hour 0-23 (e.g. --time 02:00)", :red
        exit 1
      end
      path = options[:config] || KnoxTrain::ConfigLoader.find
      unless path
        say "No config file found. Use -c PATH to specify.", :red
        exit 1
      end
      hour, minute = options[:time].split(":").map(&:to_i)
      agent = KnoxTrain::Scheduler::Launchd.new(
        config_path: File.expand_path(path),
        hour:        hour,
        minute:      minute
      )
      agent.install
      say "✓ Scheduled: #{agent.plist_path}", :green
      say "  Runs daily at #{options[:time]} — label: #{KnoxTrain::Scheduler::Launchd::LABEL}"
    rescue KnoxTrain::ConfigLoader::Error => e
      say "✗ #{e.message}", :red
      exit 1
    end

    desc "unschedule", "Remove launchd backup schedule"
    option :all, type: :boolean, desc: "Unschedule all profiles"
    def unschedule
      unless options[:all]
        say "Specify --all (per-profile scheduling not yet supported)", :red
        exit 1
      end
      agent = KnoxTrain::Scheduler::Launchd.new
      if File.exist?(agent.plist_path)
        agent.uninstall
        say "✓ Unscheduled: #{agent.plist_path}", :green
      else
        say "Not scheduled (#{agent.plist_path} not found)", :yellow
      end
    end

    desc "validate", "Validate config file (no I/O, no restic)"
    def validate
      path = options[:config] || KnoxTrain::ConfigLoader.find
      unless path
        say "No config file found. Use -c PATH to specify.", :red
        exit 1
      end
      KnoxTrain::ConfigLoader.load(path)
      reg = KnoxTrain.registry
      say "Config: #{path}"
      say "Profiles: #{reg.profiles.keys.join(', ')}"
      say "Groups:   #{reg.groups.keys.join(', ')}" unless reg.groups.empty?
      say "✓ Config valid", :green
    rescue KnoxTrain::DSL::UnknownKeyError, KnoxTrain::DSL::ValidationError,
           KnoxTrain::ConfigLoader::Error => e
      say "✗ #{e.message}", :red
      exit 1
    end

    desc "show PROFILE", "Dump resolved config for a profile"
    def show(profile_name)
      path = options[:config] || KnoxTrain::ConfigLoader.find
      unless path
        say "No config file found. Use -c PATH to specify.", :red
        exit 1
      end
      KnoxTrain::ConfigLoader.load(path)
      profile = KnoxTrain.registry.profiles[profile_name.to_sym]
      unless profile
        say "Profile '#{profile_name}' not found.", :red
        exit 1
      end
      print_profile(profile)
    rescue KnoxTrain::DSL::UnknownKeyError, KnoxTrain::DSL::ValidationError,
           KnoxTrain::ConfigLoader::Error => e
      say "✗ #{e.message}", :red
      exit 1
    end

    private

    def print_status_table(rows)
      return say("No status data.", :yellow) if rows.empty?

      header = ["Profile", "Backend", "Snaps", "Latest", "Files", "Restore", "Stored", "Ratio"]
      data   = rows.map { |r| status_row(r) }
      table  = TTY::Table.new(header: header, rows: data)
      puts table.render(:unicode,
                        alignment: [:left, :left, :right, :left, :right, :right, :right, :right])
    end

    def print_status_verbose(profile, backend, checker)
      data = checker.fetch_verbose
      sep  = "=" * 60
      say sep
      say "  #{profile.name}  (#{backend.type})"
      say sep
      say "\n  -- Snapshots --"
      say data[:snapshots]
      say "\n  -- Stats (restore size) --"
      say data[:stats]
      say "\n  -- Stats (raw / dedup) --"
      say data[:raw]
    end

    def status_row(r)
      ratio = r.stored_bytes > 0 ? "%.2fx" % (r.restore_bytes.to_f / r.stored_bytes) : "—"
      [
        r.profile_name, r.backend_type,
        r.snapshot_count,
        r.latest_time ? fmt_time(r.latest_time) : "never",
        fmt_number(r.file_count),
        fmt_bytes(r.restore_bytes),
        fmt_bytes(r.stored_bytes),
        ratio
      ]
    end

    def fmt_time(iso_str)
      Time.parse(iso_str).localtime.strftime("%Y-%m-%d %H:%M")
    rescue ArgumentError
      iso_str
    end

    def fmt_number(n)
      n.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\1,').reverse
    end

    # Mirrors the Python fmt_bytes: return inside loop so the unit is set correctly.
    # 1024 bytes → "1.0 KiB" (not "1.0 B"), 1073741824 bytes → "1.0 GiB", etc.
    def fmt_bytes(bytes)
      return "—" if bytes.nil? || bytes.zero?
      f = bytes.to_f
      %w[B KiB MiB GiB TiB].each do |unit|
        return "%.1f %s" % [f, unit] if f < 1024
        f /= 1024
      end
      "%.1f PiB" % f
    end

    def print_profile(profile)
      puts "Profile: #{profile.name}"
      puts "  sources:"
      profile.sources.each { |s| puts "    - #{s.is_a?(Proc) ? '[block]' : s}" }
      puts "  exclude_files: #{profile.exclude_files&.join(', ').then { |v| v&.empty? ? '(none)' : v } || '(none)'}"
      puts "  tags: #{profile.tags&.join(', ') || '(none)'}"
      puts "  host: #{profile.host}"
      puts "  backends:"
      profile.backends.each do |b|
        puts "    #{b.type}:"
        puts "      repo:     #{b.repo}"
        puts "      password: #{b.password ? '[block]' : '(not set)'}"
        if b.retention
          kv = b.retention.map { |k, v| "#{k}=#{v}" }.join(" ")
          puts "      retention: #{kv}"
        end
        hooks = []
        hooks << "run_before: [#{b.run_befores.length} block(s)]" if b.run_befores&.any?
        hooks << "run_after: [#{b.run_afters.length} block(s)]"   if b.run_afters&.any?
        puts "      hooks: #{hooks.join(', ')}" unless hooks.empty?
      end
    end
  end
end
